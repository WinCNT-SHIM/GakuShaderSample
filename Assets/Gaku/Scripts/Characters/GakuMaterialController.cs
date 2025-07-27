using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Serialization;

namespace Gaku
{
    [DisallowMultipleComponent]
    [ExecuteAlways]
    [DefaultExecutionOrder(100)]
    public class GakuMaterialController : MonoBehaviour
    {
        private enum TransformDirection
        {
            X, Y, Z,
            NegativeX, NegativeY, NegativeZ,
        }
        
        [SerializeField] private Transform pelvis;
        [SerializeField] private Transform headFace;
        public Transform HeadFace => headFace;
        
        [SerializeField] private TransformDirection faceForwardDirection = TransformDirection.NegativeX;
        [SerializeField] private TransformDirection faceUpDirection = TransformDirection.Y;
        [SerializeField] private TransformDirection faceRightDirection = TransformDirection.Z;
        [SerializeField] [Range(0f, 0.5f)] private float headOffset = 0.2f;
        public float HeadOffset => headOffset;
        
        [SerializeField][ColorUsage(true, false)] private Color shadeMultiplyColor = Color.white;
        [SerializeField][ColorUsage(true, true)] private Color eyeHightlightColor = Color.white;
        // 최소, 최대 윤곽선 두께 (카메라에 가까울 때 / 멀리 있을 때)
        [SerializeField][Range(0f, 10f)] private float outlineWidthMin = 0.2f;
        [SerializeField][Range(0f, 10f)] private float outlineWidthMax = 1.0f;
        // 거리 보간 계수 설정 (거리 기반으로 0→1 보간될 때 쓰이는 값)
        [SerializeField][Range(0f, 10f)] private float outlineFadeScale = 0.02f;
        [SerializeField][Range(0f, 10f)] private float outlineFadeStrength = 1.0f;
        
        private List<Renderer> gakuRenderers = new();
        private MaterialPropertyBlock materialPropertyBlock;
        private readonly List<Material> tempMaterialList = new();
        private bool? lastFrameShouldEditMaterial;
        private GakuMaterialController gakuMaterialController;
        
        private Vector3 faceForwardDirectionWs;
        private Vector3 faceUpDirectionWs;
        private Vector3 faceRightDirectionWs;
        private Vector3 facePositionWs;
#region Shader Properties
        private static readonly int HeadDirectionSid = Shader.PropertyToID("_HeadDirection");
        private static readonly int HeadUpDirectionSid = Shader.PropertyToID("_HeadUpDirection");
        private static readonly int ShadeMultiplyColorSid = Shader.PropertyToID("_ShadeMultiplyColor");
        private static readonly int EyeHightlightColorSid = Shader.PropertyToID("_EyeHightlightColor");
        private static readonly int OutlineParamSid = Shader.PropertyToID("_OutlineParam");
#endregion
        
        private void OnEnable()
        {
            AddCharacterListToRendererFeature();
            gakuMaterialController = GetCharacterMaterialController();
        }
        
        private void OnDisable() => RemoveCharacterListToRendererFeature();
        
        private void OnDestroy()
        {
            if (!Application.isPlaying) return;
            foreach (var material in gakuRenderers.SelectMany(r => r.materials))
                Destroy(material);
        }
        
        public Vector3 GetPelvisPosition() => pelvis ? pelvis.position : transform.position + Vector3.up * 0.75f;

        private void LateUpdate()
        {
            var anyRendererIsNull = false;
            for (var i = 0; i < gakuRenderers.Count; i++)
            {
                if (gakuRenderers[i]) continue;
                anyRendererIsNull = true;
                break;
            }
            var shouldFindRenderers = gakuRenderers.Count == 0 || anyRendererIsNull;
            if (shouldFindRenderers) FindGakuRenderers();

            if (headFace)
            {
                faceForwardDirectionWs = GetFaceDirectionWorldSpace(faceForwardDirection);
                faceUpDirectionWs = GetFaceDirectionWorldSpace(faceUpDirection);
                faceRightDirectionWs = GetFaceDirectionWorldSpace(faceRightDirection);
                facePositionWs = headFace.position + faceUpDirectionWs * headOffset;
            }
            
            var shouldEditMaterial = Application.isPlaying;
            if (shouldEditMaterial)
            {
                foreach (var charaRenderer in gakuRenderers)
                {
                    if (!charaRenderer) return;
                    if (lastFrameShouldEditMaterial is false) charaRenderer.SetPropertyBlock(null);
                    charaRenderer.GetMaterials(tempMaterialList);
                    foreach (var material in tempMaterialList)
                        UpdateMaterial(material);
                }
            }
            else
            {
                materialPropertyBlock ??= new MaterialPropertyBlock();
                foreach (var charaRenderer in gakuRenderers) {
                    if (!charaRenderer) return;
                    if (charaRenderer.HasPropertyBlock()) charaRenderer.GetPropertyBlock(materialPropertyBlock);
                    UpdateMaterialPropertyBlock(materialPropertyBlock);
                    charaRenderer.SetPropertyBlock(materialPropertyBlock);
                }
            }
            lastFrameShouldEditMaterial = shouldEditMaterial;
        }
        
        private void AddCharacterListToRendererFeature()
        {
            var renderFeature = GakuRendererFeature.Instance;
            if (!renderFeature) return;
            renderFeature.AddCharacterToList(this);
        }
        
        private GakuMaterialController GetCharacterMaterialController()
        {
            if (!transform.parent) return null;
            var controller = transform.parent.GetComponentsInChildren<GakuMaterialController>().FirstOrDefault();
            return controller;
        }
        
        private void RemoveCharacterListToRendererFeature()
        {
            var renderFeature = GakuRendererFeature.Instance;
            if (!renderFeature) return;
            renderFeature.RemoveCharacterFromList(this);
        }
        
        private void UpdateMaterial(Material material)
        {
            material.SetColor(ShadeMultiplyColorSid, shadeMultiplyColor); 
            material.SetColor(EyeHightlightColorSid, eyeHightlightColor); 
            material.SetVector(OutlineParamSid, new Vector4(outlineWidthMin, outlineWidthMax, outlineFadeScale, outlineFadeStrength));
            
            if (!headFace) return;
            material.SetVector(HeadDirectionSid, faceForwardDirectionWs);
            material.SetVector(HeadUpDirectionSid, faceUpDirectionWs);
        }

        private void UpdateMaterialPropertyBlock(MaterialPropertyBlock mpb)
        {
            mpb.SetColor(ShadeMultiplyColorSid, shadeMultiplyColor); 
            mpb.SetColor(EyeHightlightColorSid, eyeHightlightColor);
            mpb.SetVector(OutlineParamSid, new Vector4(outlineWidthMin, outlineWidthMax, outlineFadeScale, outlineFadeStrength));
            
            if (!headFace) return;
            mpb.SetVector(HeadDirectionSid, faceForwardDirectionWs);
            mpb.SetVector(HeadUpDirectionSid, faceUpDirectionWs);
        }
        
        private Vector3 GetFaceDirectionWorldSpace(TransformDirection direction)
        {
            var right = headFace.right;
            var up = headFace.up;
            var forward = headFace.forward;
            return direction switch
            {
                TransformDirection.X => right,
                TransformDirection.Y => up,
                TransformDirection.Z => forward,
                TransformDirection.NegativeX => -right,
                TransformDirection.NegativeY => -up,
                TransformDirection.NegativeZ => -forward,
                _ => throw new NotImplementedException()
            };
        }
        
        private void FindGakuRenderers()
        {
            GetComponentsInChildren(true, gakuRenderers);
            gakuRenderers = gakuRenderers.FindAll(charaRenderer =>
            {
                return charaRenderer.sharedMaterials
                    .Where(mat => mat)
                    .Where(mat => mat.shader)
                    .Any(mat => mat.shader.name.Contains("Gaku/Character/Default"));
            });
        }
        
        private void FindBones()
        {
            var children = GetComponentsInChildren<Transform>();
            if (!headFace)
                headFace = children.FirstOrDefault(t =>
                    t.gameObject.name.Equals("Head_Face", StringComparison.OrdinalIgnoreCase));
        }
    }
}
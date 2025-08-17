using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

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
        
        [Header("얼굴 Transform Gizmo")]
        [SerializeField] private bool isDrawGizmo = true;
        [Header("얼굴 Transform 방향")]
        [SerializeField] private TransformDirection faceRightDirection   = TransformDirection.X;
        [SerializeField] private TransformDirection faceUpDirection      = TransformDirection.Y;
        [SerializeField] private TransformDirection faceForwardDirection = TransformDirection.Z;
        [SerializeField] [Range(0f, 0.5f)] private float headOffset = 0.0f;
        public float HeadOffset => headOffset;
        
        [SerializeField][ColorUsage(true, false)] private Color shadeMultiplyColor = Color.white;
        [SerializeField][ColorUsage(true, true)] private Color eyeHighlightColor = Color.white;
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
        private Matrix4x4 headXAxisReflectionMatrix = Matrix4x4.identity;
#region Shader Properties
        private static readonly int HeadDirectionSid = Shader.PropertyToID("_HeadDirection");
        private static readonly int HeadUpDirectionSid = Shader.PropertyToID("_HeadUpDirection");
        private static readonly int ShadeMultiplyColorSid = Shader.PropertyToID("_ShadeMultiplyColor");
        private static readonly int EyeHighlightColorSid = Shader.PropertyToID("_EyeHighlightColor");
        private static readonly int OutlineParamSid = Shader.PropertyToID("_OutlineParam");
        private static readonly int HeadXAxisReflectionMatrixSid = Shader.PropertyToID("_HeadXAxisReflectionMatrix");
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
                faceRightDirectionWs = GetFaceDirectionWorldSpace(faceRightDirection);
                faceForwardDirectionWs = GetFaceDirectionWorldSpace(faceForwardDirection);
                faceUpDirectionWs = GetFaceDirectionWorldSpace(faceUpDirection);
                facePositionWs = headFace.position + faceUpDirectionWs * headOffset;
                
                // 얼굴의 X의 반전 행렬(Reflection Matrix), 즉 Y축 대칭 행렬을 구한다
                headXAxisReflectionMatrix = Matrix4x4.identity;
                headXAxisReflectionMatrix.SetColumn(0, -faceRightDirectionWs);
                headXAxisReflectionMatrix.SetColumn(1, faceUpDirectionWs);
                headXAxisReflectionMatrix.SetColumn(2, faceForwardDirectionWs);
                headXAxisReflectionMatrix.SetColumn(3, new Vector4(0, 0, 0, 1));
            }
            
            var shouldEditMaterial = Application.isPlaying;
            if (shouldEditMaterial)
            {
                foreach (var charaRenderer in gakuRenderers)
                {
                    if (!charaRenderer) continue;
                    if (lastFrameShouldEditMaterial is false)
                        charaRenderer.SetPropertyBlock(null);
                    
                    charaRenderer.GetMaterials(tempMaterialList);
                    foreach (var material in tempMaterialList)
                        UpdateMaterial(material);
                }
            }
            else
            {
                materialPropertyBlock ??= new MaterialPropertyBlock();
                foreach (var charaRenderer in gakuRenderers)
                {
                    if (!charaRenderer) continue;
                    if (charaRenderer.HasPropertyBlock())
                        charaRenderer.GetPropertyBlock(materialPropertyBlock);
                    
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
            material.SetColor(EyeHighlightColorSid, eyeHighlightColor); 
            material.SetVector(OutlineParamSid, new Vector4(outlineWidthMin, outlineWidthMax, outlineFadeScale, outlineFadeStrength));
            
            if (!headFace) return;
            material.SetVector(HeadDirectionSid, faceForwardDirectionWs);
            material.SetVector(HeadUpDirectionSid, faceUpDirectionWs);
            material.SetMatrix(HeadXAxisReflectionMatrixSid, headXAxisReflectionMatrix);
        }

        private void UpdateMaterialPropertyBlock(MaterialPropertyBlock mpb)
        {
            mpb.SetColor(ShadeMultiplyColorSid, shadeMultiplyColor); 
            mpb.SetColor(EyeHighlightColorSid, eyeHighlightColor);
            mpb.SetVector(OutlineParamSid, new Vector4(outlineWidthMin, outlineWidthMax, outlineFadeScale, outlineFadeStrength));
            
            if (!headFace) return;
            mpb.SetVector(HeadDirectionSid, faceForwardDirectionWs);
            mpb.SetVector(HeadUpDirectionSid, faceUpDirectionWs);
            mpb.SetMatrix(HeadXAxisReflectionMatrixSid, headXAxisReflectionMatrix);
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
        
        private void OnDrawGizmos()
        {
            if (!isDrawGizmo || !headFace) return;
            
            var position = facePositionWs;
            DrawArrow(position, faceForwardDirectionWs, new Color(0, 0, 1, 1f));
            DrawArrow(position, faceUpDirectionWs, new Color(0, 1, 0, 1f));
            DrawArrow(position, faceRightDirectionWs, new Color(1, 0, 0, 1f));
        }
        
        // https://forum.unity.com/threads/debug-drawarrow.85980/
        private static void DrawArrow(Vector3 pos, Vector3 direction, Color color, float arrowHeadLength = 0.05f, float arrowHeadAngle = 15f)
        {
            if (direction.magnitude == 0) return;
            
            direction *= 0.3f;
            Gizmos.color = color;
            Gizmos.DrawRay(pos, direction);
            
            var right = Quaternion.LookRotation(direction) * Quaternion.Euler(0, 180 + arrowHeadAngle, 0) * new Vector3(0, 0, 1);
            var left  = Quaternion.LookRotation(direction) * Quaternion.Euler(0, 180 - arrowHeadAngle, 0) * new Vector3(0, 0, 1);
            var up    = Quaternion.LookRotation(direction) * Quaternion.Euler(+arrowHeadAngle, 180, 0) * new Vector3(0, 0, 1);
            var down  = Quaternion.LookRotation(direction) * Quaternion.Euler(-arrowHeadAngle, 180, 0) * new Vector3(0, 0, 1);
            
            Gizmos.DrawRay(pos + direction, right * arrowHeadLength);
            Gizmos.DrawRay(pos + direction, left * arrowHeadLength);
            Gizmos.DrawRay(pos + direction, up * arrowHeadLength);
            Gizmos.DrawRay(pos + direction, down * arrowHeadLength);
        }
    }
}
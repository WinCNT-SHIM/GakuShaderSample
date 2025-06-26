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
        [SerializeField] private Transform pelvisBoneTransform;
        [SerializeField] private Transform headBoneTransform;
        [SerializeField] private Transform faceBoneTransform;
        
        private List<Renderer> gakuRenderers = new();
        private MaterialPropertyBlock materialPropertyBlock;
        private readonly List<Material> tempMaterialList = new();
        private GakuMaterialController gakuMaterialController;
        
#region Shader Properties
        private static readonly int OutlineParamSid = Shader.PropertyToID("_OutlineParam");
        private static readonly int HeadDirectionSid = Shader.PropertyToID("_HeadDirection");
        private static readonly int HeadUpDirectionSid = Shader.PropertyToID("_HeadUpDirection");
#endregion
        
        private void OnEnable()
        {
            AddCharacterListToRendererFeature();
            gakuMaterialController = GetCharacterMaterialController();
        }
        
        private void OnDisable() => RemoveCharacterListToRendererFeature();
        
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

            if (headBoneTransform)
            {
                // TODO
                
                
            }
            
            foreach (var charaRenderer in gakuRenderers)
            {
                if (!charaRenderer) return;
                charaRenderer.GetMaterials(tempMaterialList);
                foreach (var material in tempMaterialList)
                    UpdateMaterial(material);
            }
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
            if (!Application.isPlaying) return;
            foreach (var material in gakuRenderers.SelectMany(r => r.materials))
                Destroy(material);
        }
        
        private void UpdateMaterial(Material material)
        {
            
        }
        
        private void FindBones()
        {
            var children = GetComponentsInChildren<Transform>();
            if (!headBoneTransform)
                headBoneTransform = children.FirstOrDefault(t =>
                    t.gameObject.name.Equals("Head", StringComparison.OrdinalIgnoreCase));
        }
        
        private void FindGakuRenderers()
        {
            GetComponentsInChildren(true, gakuRenderers);
            gakuRenderers = gakuRenderers.FindAll(charaRenderer =>
            {
                return charaRenderer.sharedMaterials
                    .Where(mat => mat)
                    .Where(mat => mat.shader)
                    .Any(mat => mat.shader.name.Contains("Gaku/Character"));
            });
        }
    }
}
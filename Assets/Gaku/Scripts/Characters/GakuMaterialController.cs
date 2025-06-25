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
        private Transform pelvisBoneTransform;
        private Transform headBoneTransform;
        
        private List<Renderer> gakuRenderers = new();
        private MaterialPropertyBlock materialPropertyBlock;
        
        private GakuMaterialController gakuMaterialController;
        
#region Shader Properties
        private static readonly int OutlineParamSid = Shader.PropertyToID("_OutlineParam");
#endregion
        
        private void OnEnable()
        {
            AddCharacterListToRendererFeature();
            gakuMaterialController = GetCharacterMaterialController();
        }
        
        private void OnDisable() => RemoveCharacterListToRendererFeature();
        
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
            if (!headBoneTransform) headBoneTransform = children.FirstOrDefault(_ => _.gameObject.name.Equals("Head", StringComparison.OrdinalIgnoreCase));
        }

    }
}
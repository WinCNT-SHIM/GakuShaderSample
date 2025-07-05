using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Gaku
{
    public class GakuRendererFeature : ScriptableRendererFeature
    {
        public static GakuRendererFeature Instance { get; private set; }
        
        // 렌더 패스
        private GakuSetParametersPass gakuSetParametersPass;
        private GakuSelfShadowPass gakuSelfShadowPass;
        
        public List<GakuMaterialController> charaMaterialList { get; set; }
        public GakuSelfShadowPass.SelfShadowSettings selfShadowSettings = new();
        
        public GakuRendererFeature()
        {
            Instance = this;
        }
        
        public override void Create()
        {
            // 파라미터 세팅 패스
            gakuSetParametersPass = new GakuSetParametersPass
            {
                renderPassEvent = RenderPassEvent.BeforeRendering
            };
            // 셀프 쉐도우 패스
            gakuSelfShadowPass = new GakuSelfShadowPass(selfShadowSettings)
            {
                renderPassEvent = RenderPassEvent.AfterRenderingPrePasses
            };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(gakuSetParametersPass);
            renderer.EnqueuePass(gakuSelfShadowPass);
        }

        public void AddCharacterToList(GakuMaterialController gakuMaterialController)
        {
            if (charaMaterialList.Contains(gakuMaterialController)) return;
            charaMaterialList.Add(gakuMaterialController);
            // TODO: SetStencil
        }
        
        public void RemoveCharacterFromList(GakuMaterialController materialController)
        {
            if (!charaMaterialList.Contains(materialController)) return;
            charaMaterialList.Remove(materialController);
            // TODO: SetStencil
        }
        
        protected override void Dispose(bool disposing)
        {
            gakuSetParametersPass.Dispose();
            base.Dispose(disposing);
        }
    }
}
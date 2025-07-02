using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Gaku
{
    public class GakuRendererFeature : ScriptableRendererFeature
    {
        public static GakuRendererFeature Instance { get; private set; }
        
        // 렌더 패스(현재는 셰이더 글로벌 변수 세팅용)
        private GakuSetParametersPass gakuSetParametersPass;
        
        public List<GakuMaterialController> charaMaterialList { get; set; }
        
        public GakuRendererFeature()
        {
            Instance = this;
        }
        
        public override void Create()
        {
            gakuSetParametersPass = new GakuSetParametersPass {
                renderPassEvent = RenderPassEvent.BeforeRendering
            };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(gakuSetParametersPass);
        }

        public void AddCharacterToList(GakuMaterialController gakuMaterialController)
        {
            if (charaMaterialList.Contains(gakuMaterialController)) return;
            charaMaterialList.Add(gakuMaterialController);
            // SetStencil
        }
    }
}
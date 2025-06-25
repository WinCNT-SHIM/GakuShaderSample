using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Gaku
{
    public class GakuRendererFeature : ScriptableRendererFeature
    {
        public static GakuRendererFeature Instance { get; private set; }
        
        // 렌더 패스(현재는 셰이더 글로벌 변수 세팅용)
        private GakuRenderPass _gakuRenderPass;
        
        public GakuRendererFeature()
        {
            Instance = this;
        }
        
        public override void Create()
        {
            _gakuRenderPass = new GakuRenderPass {
                renderPassEvent = RenderPassEvent.BeforeRendering
            };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(_gakuRenderPass);
        }

        public void AddCharacterToList(GakuMaterialController gakuMaterialController)
        {
            throw new System.NotImplementedException();
        }
    }
}
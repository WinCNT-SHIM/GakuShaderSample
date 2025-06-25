using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Gaku
{
    public class GakuRenderPass : ScriptableRenderPass
    {
        private GakuVolume gakuVolume;
        private Tonemapping tonemapping;
        
        public GakuRenderPass()
        {
            profilingSampler = new ProfilingSampler(nameof(GakuRenderPass));
            var srpInput = ScriptableRenderPassInput.None;
            srpInput |= ScriptableRenderPassInput.Depth;
            srpInput |= ScriptableRenderPassInput.Color;
            ConfigureInput(srpInput);
        }
        
        private static readonly int SkinSaturation = Shader.PropertyToID("_SkinSaturation");
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, profilingSampler))
            {
                var camera = renderingData.cameraData.camera;
                SetShaderParams(renderingData, cmd, camera);
                
                if (gakuVolume.active)
                    SetGlobalShaderParams(cmd, camera);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        
        private void SetShaderParams(RenderingData renderingData, CommandBuffer cmd, Camera camera)
        {
            
        }
        
        private void SetGlobalShaderParams(CommandBuffer cmd, Camera camera)
        {
            cmd.SetGlobalFloat(SkinSaturation, gakuVolume._SkinSaturation.value);
            
        }
    }
}
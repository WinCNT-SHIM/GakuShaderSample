using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Gaku
{
    public class GakuSetParametersPass : ScriptableRenderPass
    {
        private GakuVolume gakuVolume;
        private Tonemapping tonemapping;

        public GakuSetParametersPass()
        {
            profilingSampler = new ProfilingSampler(nameof(GakuSetParametersPass));
            var srpInput = ScriptableRenderPassInput.None;
            srpInput |= ScriptableRenderPassInput.Depth;
            srpInput |= ScriptableRenderPassInput.Color;
            ConfigureInput(srpInput);
        }

        private static readonly int GlobalLightingOverrideColorSid =
            Shader.PropertyToID("_GlobalLightingOverrideColor");

        private static readonly int GlobalLightingOverrideRatioSid =
            Shader.PropertyToID("_GlobalLightingOverrideRatio");

        private static readonly int GlobalLightingOverrideDirectionEnabledSid =
            Shader.PropertyToID("_GlobalLightingOverrideDirectionEnabled");

        private static readonly int GlobalLightingOverrideDirectionSid =
            Shader.PropertyToID("_GlobalLightingOverrideDirection");

        private static readonly int EnableACESCounterSid = Shader.PropertyToID("_EnableACESCounter");

        private static readonly int GlobalMainLightDirVSSid = Shader.PropertyToID("_GlobalMainLightDirVS");
        private static readonly int SkinSaturationSid = Shader.PropertyToID("_SkinSaturation");

        private Vector3 lightOriginDir = new(0, 0, -1);
        private Texture cachedReflectionProbe;

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var volumeStack = VolumeManager.instance.stack;
            gakuVolume = volumeStack.GetComponent<GakuVolume>();
            tonemapping = volumeStack.GetComponent<Tonemapping>();
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, profilingSampler))
            {
                var camera = renderingData.cameraData.camera;
                SetGlobalShaderParams(renderingData, cmd, camera);

                if (gakuVolume.active)
                {
                    SetGlobalVolumeParams(cmd, camera);
                    SetSceneAmbientLighting();
                }
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void SetGlobalShaderParams(RenderingData renderingData, CommandBuffer cmd, Camera camera)
        {
            cmd.SetGlobalFloat(EnableACESCounterSid,
                renderingData.postProcessingEnabled && tonemapping && tonemapping.mode.value == TonemappingMode.ACES
                    ? 1
                    : 0);
            var mainLightIndex = renderingData.lightData.mainLightIndex;
            if (mainLightIndex >= 0)
            {
                var mainLight = renderingData.lightData.visibleLights[mainLightIndex];
                var mainLightDirWS = mainLight.light.transform.forward;
                var mainLightDirVS = camera.worldToCameraMatrix.MultiplyVector(mainLightDirWS);
                cmd.SetGlobalVector(GlobalMainLightDirVSSid, -mainLightDirVS);
            }
        }

        private void SetGlobalVolumeParams(CommandBuffer cmd, Camera camera)
        {
            cmd.SetGlobalFloat(SkinSaturationSid, gakuVolume._SkinSaturation.value);

            cmd.SetGlobalColor(GlobalLightingOverrideColorSid,
                gakuVolume._GlobalLightingOverrideColor.value);
            cmd.SetGlobalFloat(GlobalLightingOverrideRatioSid,
                gakuVolume._GlobalLightingOverrideRatio.value);
            if (gakuVolume._GlobalLightingOverrideDirection.overrideState)
            {
                cmd.SetGlobalFloat(GlobalLightingOverrideDirectionEnabledSid, 1f);
                cmd.SetGlobalVector(GlobalLightingOverrideDirectionSid,
                    Quaternion.Euler(gakuVolume._GlobalLightingOverrideDirection.value) * lightOriginDir);
            }
            else
            {
                cmd.SetGlobalFloat(GlobalLightingOverrideDirectionEnabledSid, 0f);
            }
        }

        private void SetSceneAmbientLighting()
        {
            if (gakuVolume._skyboxMaterial.value)
            {
                RenderSettings.ambientMode = AmbientMode.Skybox;
                RenderSettings.skybox = gakuVolume._skyboxMaterial.value;
                RenderSettings.ambientIntensity = gakuVolume._skyboxIntensity.value;
            }

            if (cachedReflectionProbe != gakuVolume._reflectionProbe.value)
            {
                if (gakuVolume._reflectionProbe.value)
                {
                    RenderSettings.defaultReflectionMode = DefaultReflectionMode.Custom;
                    RenderSettings.customReflectionTexture = gakuVolume._reflectionProbe.value;
                    cachedReflectionProbe = gakuVolume._reflectionProbe.value;
                }
                else
                {
                    RenderSettings.defaultReflectionMode = DefaultReflectionMode.Skybox;
                    cachedReflectionProbe = null;
                }
            }

            if (gakuVolume.SH2.overrideState)
                RenderSettings.ambientProbe = gakuVolume.SH2.value;
        }

        public void Dispose()
        {
            cachedReflectionProbe = null;
        }
    }
}
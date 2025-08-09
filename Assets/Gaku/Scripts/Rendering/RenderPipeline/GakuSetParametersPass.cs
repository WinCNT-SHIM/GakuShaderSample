using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
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

        private static Vector3 lightOriginDir = new(0, 0, -1);
        private Texture cachedReflectionProbe;

        private class PassData
        {
            public GakuSetParametersContext gakuSetParametersContext;
        }

        // 카메라/볼륨 등을 묶는 읽기 전용 구조체
        readonly struct GakuSetParametersContext
        {
            public readonly UniversalLightData LightData;
            public readonly Camera Camera;
            public readonly bool PostProcessEnabled;
            public readonly GakuVolume GakuVolume;
            public readonly Tonemapping Tonemapping;

            public GakuSetParametersContext(UniversalLightData lightData, Camera camera, bool postProcessEnabled, GakuVolume gakuVolume, Tonemapping tonemapping)
            {
                this.LightData = lightData;
                this.Camera = camera;
                this.PostProcessEnabled = postProcessEnabled;
                this.GakuVolume = gakuVolume;
                this.Tonemapping = tonemapping;
            }
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var lightData = frameData.Get<UniversalLightData>();
            var cameraData = frameData.Get<UniversalCameraData>();
            var camera = cameraData.camera;
            var postProcessingEnabled = cameraData.postProcessEnabled;

            var volumeStack = VolumeManager.instance.stack;
            var customVolume = volumeStack.GetComponent<GakuVolume>();
            var customTonemapping = volumeStack.GetComponent<Tonemapping>();

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(nameof(GakuSetParametersPass), out var passData))
            {
                // 전역 셰이더 상태만 바꾸는 패스라면 컬링 방지 & 글로벌 상태 변경 가능 표시
                // 리소스를 선언하지 않고 부수 효과만 일으키는 패스는 기본적으로 컬링될 수 있으므로 필요
                builder.AllowPassCulling(false);
                builder.AllowGlobalStateModification(true);
                // 필요한 데이터 설정
                passData.gakuSetParametersContext = new GakuSetParametersContext(lightData , camera, postProcessingEnabled, customVolume, customTonemapping);
                // 실행할 패스 등록
                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
            }
        }
        
        private void ExecutePass(PassData passData, RasterGraphContext graphContext)
        {
            SetGlobalShaderParams(graphContext, in passData.gakuSetParametersContext);
            if (gakuVolume.active)
            {
                SetGlobalVolumeParams(graphContext, in passData.gakuSetParametersContext);
                // SetSceneAmbientLighting();
            }
        }

        private static void SetGlobalVolumeParams(RasterGraphContext context, in GakuSetParametersContext passData)
        {
            var cmd = context.cmd;
            var gakuVolume = passData.GakuVolume;
            
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

        private static void SetGlobalShaderParams(RasterGraphContext context, in GakuSetParametersContext passData)
        {
            var cmd = context.cmd;
            var tonemapping = passData.Tonemapping;
            
            cmd.SetGlobalFloat(EnableACESCounterSid,
                passData.PostProcessEnabled && tonemapping && tonemapping.mode.value == TonemappingMode.ACES
                    ? 1
                    : 0);
            var mainLightIndex = passData.LightData.mainLightIndex;
            if (mainLightIndex >= 0)
            {
                var mainLight = passData.LightData.visibleLights[mainLightIndex];
                var mainLightDirWS = mainLight.light.transform.forward;
                var mainLightDirVS = passData.Camera.worldToCameraMatrix.MultiplyVector(mainLightDirWS);
                cmd.SetGlobalVector(GlobalMainLightDirVSSid, -mainLightDirVS);
            }
        }

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
                    // SetSceneAmbientLighting();
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
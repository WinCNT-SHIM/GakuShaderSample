using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace Gaku
{
    /// <summary>
    /// 셀프 쉐도우용 렌더 패스
    /// </summary>
    public class GakuSelfShadowPass : ScriptableRenderPass
    {
        public enum ShadowMapSize
        {
            Low = 512,
            Middle = 1024,
            High = 2048,
            VeryHigh = 4096,
        };

        [Serializable]
        public class SelfShadowSettings
        {
            public bool enableSelfShadowPass = true;
            public bool useMainLightForSelfShadowDir = false;

            [Range(0f, 45f)] public float shadowAngle = 15f;
            [Range(0.1f, 2f)] public float boundSize = 1f;
            public ShadowMapSize shadowMapSize = ShadowMapSize.VeryHigh;
            [Range(1f, 100f)] public float shadowRange = 10;
            [Range(0.01f, 10f)] public float depthBias = 1;
            public bool useNdotLFix = true;
        }

        /// <summary>
        /// RenderGraph에 필요한 데이터 보관용
        /// </summary>
        private class PassData
        {
            public GakuSelfShadowContext GakuSelfShadowContext;
            public TextureHandle ShadowMap;
            public RendererListHandle RendererList;
        }

        private readonly struct GakuSelfShadowContext
        {
            public readonly SelfShadowSettings Settings;
            public readonly Matrix4x4 ViewMatrix;
            public readonly Matrix4x4 ProjectionMatrix;
            public readonly Matrix4x4 WorldToClipMatrix;
            public readonly Vector4 ShadowParam;
            public readonly Vector4 LightDirection;
            public readonly Camera Camera;
            public readonly int MainLightIndex;
            public readonly UniversalLightData LightData;
            public readonly int VisibleCharacterCount;

            public GakuSelfShadowContext(
                SelfShadowSettings settings,
                Matrix4x4 viewMatrix,
                Matrix4x4 projMatrix,
                Matrix4x4 worldToClipMatrix,
                Vector4 shadowParam, Vector4 lightDirection,
                Camera camera, int mainLightIndex, UniversalLightData lightData,
                int visibleCharacterCount)
            {
                Settings = settings;
                ViewMatrix = viewMatrix;
                ProjectionMatrix = projMatrix;
                WorldToClipMatrix = worldToClipMatrix;
                ShadowParam = shadowParam;
                LightDirection = lightDirection;
                Camera = camera;
                MainLightIndex = mainLightIndex;
                LightData = lightData;
                VisibleCharacterCount = visibleCharacterCount;
            }
        }

        private static readonly int GakuSelfShadowMapRTSid = Shader.PropertyToID(GakuSelfShadowMapRT);
        private static readonly int GakuSelfShadowRangeSid = Shader.PropertyToID("_GakuSelfShadowRange");
        private static readonly int GakuSelfShadowWorldToClipSid = Shader.PropertyToID("_GakuSelfShadowWorldToClip");
        private static readonly int GakuSelfShadowParamSid = Shader.PropertyToID("_GakuSelfShadowParam");
        private static readonly int GakuGlobalSelfShadowDepthBiasSid = Shader.PropertyToID("_GakuGlobalSelfShadowDepthBias");
        private static readonly int GakuSelfShadowLightDirectionSid = Shader.PropertyToID("_GakuSelfShadowLightDirection");
        private static readonly int GakuSelfShadowUseNdotLFixSid = Shader.PropertyToID("_GakuSelfShadowUseNdotLFix");

        private readonly SelfShadowSettings settings;
        private const string GakuEnableSelfShadowKeyword = "_ENABLE_GAKU_SELF_SHADOW";
        private const string GakuSelfShadowMapRT = "_GakuSelfShadowMapRT";
        private static readonly ShaderTagId GakuSelfShadowCasterShaderTagId = new("GakuSelfShadowCaster");

        private Plane[] cameraPlanes = new Plane[6];
        private static readonly Vector3 charaBoundSize = new(0.75f, 1.5f, 0.5f);

        // 생성자
        public GakuSelfShadowPass(SelfShadowSettings settings)
        {
            profilingSampler = new ProfilingSampler(nameof(GakuSelfShadowPass));
            this.settings = settings;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (!settings.enableSelfShadowPass)
            {
                using var builder = renderGraph.AddRasterRenderPass<PassData>("Disable Self Shadow Keyword", out _);
                builder.SetRenderFunc((PassData _, RasterGraphContext ctx) => CoreUtils.SetKeyword(ctx.cmd, GakuEnableSelfShadowKeyword, false));
                return;
            }

            var cameraData = frameData.Get<UniversalCameraData>();
            var lightData = frameData.Get<UniversalLightData>();
            var renderingData = frameData.Get<UniversalRenderingData>(); // cullResults 접근용

            // 쉐도우 맵 렌더링에 필요한 모든 정보를 미리 계산
            var gakuSelfShadowContext = PrepareSelfShadowContext(cameraData.camera, lightData);
            // 컬링 결과 대상 캐릭터가 없으면 스킵
            if (gakuSelfShadowContext.VisibleCharacterCount == 0)
            {
                using var builder = renderGraph.AddRasterRenderPass<PassData>("Disable Self Shadow Keyword", out _);
                builder.SetRenderFunc((PassData _, RasterGraphContext ctx) => CoreUtils.SetKeyword(ctx.cmd, GakuEnableSelfShadowKeyword, false));
                return;
            }

            // 타겟 텍스처(쉐도우 맵 텍스처)를 RenderGraph에 등록
            var shadowMapSize = (int)settings.shadowMapSize;
            var desc = new TextureDesc(shadowMapSize, shadowMapSize)
            {
                name = "_GakuSelfShadowMapRT",
                colorFormat = GraphicsFormat.None,
                depthBufferBits = DepthBits.Depth16,
                filterMode = FilterMode.Bilinear, // Soft/PCF 등을 위해 설정해둠
                wrapMode  = TextureWrapMode.Clamp,
                clearBuffer = true,
                isShadowMap = true  // 비교 샘플링 가능하도록 ShadowMap으로 선언(중요!)
            };
            var shadowMapTexture = renderGraph.CreateTexture(desc);

            // RendererList 생성 (카메라 컬 결과 사용, 셀프 섀도우 패스만)
            var rendererListDesc = new RendererListDesc(GakuSelfShadowCasterShaderTagId, renderingData.cullResults, cameraData.camera)
            {
                sortingCriteria = SortingCriteria.CommonOpaque,
                renderQueueRange = RenderQueueRange.opaque
            };
            var rendererList = renderGraph.CreateRendererList(rendererListDesc);

            // 그리기 패스
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(nameof(GakuSelfShadowPass), out var passData, profilingSampler))
            {
                passData.GakuSelfShadowContext = gakuSelfShadowContext;
                passData.ShadowMap = shadowMapTexture;
                passData.RendererList = rendererList;

                // passData.ShadowMap 대신 직접 핸들 사용
                builder.SetRenderAttachmentDepth(shadowMapTexture, AccessFlags.Write);

                builder.UseRendererList(rendererList);
                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
            }

            // 전역 변수 세팅 패스
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Setup Self Shadow Globals", out var passData, profilingSampler))
            {
                passData.GakuSelfShadowContext = gakuSelfShadowContext;
                passData.ShadowMap = shadowMapTexture;
                builder.UseTexture(shadowMapTexture);
                builder.AllowPassCulling(false);
                builder.AllowGlobalStateModification(true);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    var cmd = context.cmd;
                    var c = data.GakuSelfShadowContext;

                    cmd.SetGlobalTexture(GakuSelfShadowMapRTSid, data.ShadowMap);
                    cmd.SetGlobalFloat(GakuSelfShadowRangeSid, c.Settings.shadowRange);
                    cmd.SetGlobalMatrix(GakuSelfShadowWorldToClipSid, c.WorldToClipMatrix);
                    cmd.SetGlobalVector(GakuSelfShadowParamSid, c.ShadowParam);
                    cmd.SetGlobalFloat(GakuGlobalSelfShadowDepthBiasSid, c.Settings.depthBias * 0.005f);
                    cmd.SetGlobalVector(GakuSelfShadowLightDirectionSid, c.LightDirection);
                    cmd.SetGlobalFloat(GakuSelfShadowUseNdotLFixSid, c.Settings.useNdotLFix ? 1 : 0);

                    CoreUtils.SetKeyword(cmd, GakuEnableSelfShadowKeyword, true);
                });
            }
        }

        private GakuSelfShadowContext PrepareSelfShadowContext(Camera camera, UniversalLightData lightData)
        {
            var isMainLightExist = lightData.mainLightIndex != -1;

            // Self Shadow용 뷰 행렬
            Matrix4x4 shadowCameraViewMatrix;
            if (isMainLightExist && settings.useMainLightForSelfShadowDir)
            {
                // URP의 메인 라이트의 쉐도우 맵의 라이트 방향과 동일하게 해서 쉐도우 맵 생성
                var shadowLight = lightData.visibleLights[lightData.mainLightIndex];
                var mainLight = shadowLight.light;
                shadowCameraViewMatrix = mainLight.transform.worldToLocalMatrix;
                shadowCameraViewMatrix = Matrix4x4.Rotate(Quaternion.Euler(0, 180, 0)) * shadowCameraViewMatrix;
            }
            else
            {
                // 카메라의 회전만을 고려하거나 메인 라이트가 없을 경우
                shadowCameraViewMatrix = Matrix4x4.Rotate(Quaternion.Euler(new Vector3(settings.shadowAngle, 0, 0))) * camera.worldToCameraMatrix;
            }

            var minX = Mathf.Infinity;
            var maxX = Mathf.NegativeInfinity;
            var minY = Mathf.Infinity;
            var maxY = Mathf.NegativeInfinity;
            var minZ = Mathf.Infinity;
            var maxZ = Mathf.NegativeInfinity;

            // 대상 캐릭터 리스트 취득
            var allCharacters = GakuRendererFeature.Instance.charaMaterialList;
            // 카메라 절두체를 생성
            GeometryUtility.CalculateFrustumPlanes(camera, cameraPlanes);

            var visibleCharacterCount = 0;
            foreach (var character in allCharacters)
            {
                if (character == null || !character.isActiveAndEnabled) continue;

                // 캐릭터의 골반을 중심 위치로 가정
                var centerPosWs = character.GetPelvisPosition();
                // 캐릭터의 중심 위치를 셀프 쉐도우의 뷰 공간으로 변환
                var centerPosShadowCamVs = (Matrix4x4.Scale(new Vector3(1, 1, -1)) * shadowCameraViewMatrix).MultiplyPoint(centerPosWs);
                // 카메라와 거리가 먼 경우는 무시
                if (centerPosShadowCamVs.z - settings.boundSize > settings.shadowRange) continue;
                // 원래의 카메라의 절두체에서 컬링되는 경우도 무시
                var charaBounds = new Bounds(character.GetPelvisPosition(), charaBoundSize * settings.boundSize);
                if (!GeometryUtility.TestPlanesAABB(cameraPlanes, charaBounds)) continue;

                minX = Mathf.Min(minX, centerPosShadowCamVs.x - settings.boundSize);
                maxX = Mathf.Max(maxX, centerPosShadowCamVs.x + settings.boundSize);
                minY = Mathf.Min(minY, centerPosShadowCamVs.y - settings.boundSize);
                maxY = Mathf.Max(maxY, centerPosShadowCamVs.y + settings.boundSize);
                minZ = Mathf.Min(minZ, centerPosShadowCamVs.z - settings.boundSize);
                maxZ = Mathf.Max(maxZ, centerPosShadowCamVs.z + settings.boundSize);

                visibleCharacterCount++;
            }

            // 대상 캐릭이 없으면 Return
            if (visibleCharacterCount == 0)
                return new GakuSelfShadowContext(settings, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.zero, Vector4.zero, Vector4.zero, null, -1, new UniversalLightData(), visibleCharacterCount);

            // 직교 투영 행렬 생성
            var projectionMatrix = Matrix4x4.Ortho(minX, maxX, minY, maxY, minZ, maxZ);
            // 그래픽 API에 맞게 조정된 투영 행렬 획득
            var gpuProjectionMatrix = GL.GetGPUProjectionMatrix(projectionMatrix, true);
            var gpuWorldToClip = gpuProjectionMatrix * shadowCameraViewMatrix;
            // 글로벌 변수에 설정할 값
            var shadowMapSize = (int)settings.shadowMapSize;
            var shadowParam = new Vector4(1f / shadowMapSize, 1f / shadowMapSize, shadowMapSize, shadowMapSize);
            var lightDirection = shadowCameraViewMatrix.inverse.MultiplyVector(Vector3.forward);
            
            //////////////////////////////////////////////////
            // :TODO 쉐도우 품질 설정에 의한 셀프 쉐도우 품질 변경은 나중에!
            //////////////////////////////////////////////////

            return new GakuSelfShadowContext(settings, shadowCameraViewMatrix, projectionMatrix, gpuWorldToClip, shadowParam, lightDirection, camera, lightData.mainLightIndex, lightData, visibleCharacterCount);
        }

        private static void ExecutePass(PassData passData, RasterGraphContext context)
        {
            var cmd = context.cmd;
            var gakuSelfShadowContext = passData.GakuSelfShadowContext;

            // 셀프 섀도우용 뷰/프로젝션으로 교체
            cmd.SetViewProjectionMatrices(gakuSelfShadowContext.ViewMatrix, gakuSelfShadowContext.ProjectionMatrix);

            // RenderGraph에서 ClearBuffer를 하지만 플랫폼별 문제 회피용으로 한 번 더 보수적으로 클리어
            cmd.ClearRenderTarget(true, true, Color.black);

            // RendererList 그리기
            cmd.DrawRendererList(passData.RendererList);

            // 원상 복귀 (다음 패스 영향 방지)
            if (gakuSelfShadowContext.Camera)
                cmd.SetViewProjectionMatrices(gakuSelfShadowContext.Camera.worldToCameraMatrix, gakuSelfShadowContext.Camera.projectionMatrix);
        }

    }
}

using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

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
            [FormerlySerializedAs("useMainLightSelfShadowDir")] [FormerlySerializedAs("useMainLightAsSelfShadowDir")] [FormerlySerializedAs("useMainLightAsCastShadowDirection")] public bool useMainLightForSelfShadowDir = false;
            [Range(0f, 45f)] public float shadowAngle = 15f;
            [Range(0.1f, 2f)] public float boundSize = 1f;
            public ShadowMapSize shadowMapSize = ShadowMapSize.VeryHigh;
            [Range(1f, 100f)] public float shadowRange = 10;
            [Range(0.01f, 10f)] public float depthBias = 1;
            public bool useNdotLFix = true;
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
        private Plane[] cullingPlanes = new Plane[6];
        private readonly RTHandle shadowMapRTHandle;
        private static readonly Vector3 charaBoundSize = new(0.75f, 1.5f, 0.5f);

        // 생성자
        public GakuSelfShadowPass(SelfShadowSettings settings)
        {
            profilingSampler = new ProfilingSampler(nameof(GakuSelfShadowPass));
            this.settings = settings;
            shadowMapRTHandle = RTHandles.Alloc(GakuSelfShadowMapRT, GakuSelfShadowMapRT);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var shadowMapSize = settings.shadowMapSize;

            //////////////////////////////////////////////////
            // :TODO 쉐도우 품질 설정에 의한 셀프 쉐도우 품질 변경은 나중에!
            //////////////////////////////////////////////////

            var renderTextureDescriptor = new RenderTextureDescriptor(
                (int)shadowMapSize, (int)shadowMapSize
                , RenderTextureFormat.Shadowmap, 16);

            cmd.GetTemporaryRT(Shader.PropertyToID(shadowMapRTHandle.name), renderTextureDescriptor,
                FilterMode.Bilinear);
            cmd.SetGlobalTexture(GakuSelfShadowMapRTSid, shadowMapRTHandle);

            ConfigureTarget(shadowMapRTHandle);
            ConfigureClear(ClearFlag.Depth, Color.black);
        }

        // 할당된 리소스 정리
        public override void OnCameraCleanup(CommandBuffer cmd) => cmd.ReleaseTemporaryRT(Shader.PropertyToID(shadowMapRTHandle.name));
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            RenderSelfShadowmapRT(context, renderingData);
        }
        
        /// <summary>
        /// 캐릭터의 셀프 쉐도우용 렌더 텍스터를 만든다
        /// 1. 뷰 행렬, 투영 행렬 만들기
        /// 2. 캐릭터용 스크립트를 가진 오브젝틀르 대상으로 해서 바운드를 생성해서 붙임
        /// 3. 부착한 바운드를 기준으로 컬링
        /// 4. 렌더링
        /// 5. 원상 복귀도 잊지 말기!
        /// </summary>
        /// <param name="context"></param>
        /// <param name="renderingData"></param>
        private void RenderSelfShadowmapRT(ScriptableRenderContext context, RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            using (var profilingScope = new ProfilingScope(cmd, profilingSampler))
            {
                if (settings.enableSelfShadowPass)
                {
                    var camera = renderingData.cameraData.camera;
                    var mainLightIndex = renderingData.lightData.mainLightIndex;
                    var isMainLightExist = mainLightIndex != -1;

                    // Self Shadow용 뷰 행렬
                    Matrix4x4 shadowCameraViewMatrix;
                    if (isMainLightExist && settings.useMainLightForSelfShadowDir)
                    {
                        // URP의 메인 라이트의 쉐도우 맵의 라이트 방향과 동일하게 해서 쉐도우 맵 생성
                        var shadowLight = renderingData.lightData.visibleLights[mainLightIndex];
                        var mainLight = shadowLight.light;
                        shadowCameraViewMatrix = mainLight.transform.worldToLocalMatrix;
                        shadowCameraViewMatrix = Matrix4x4.Rotate(Quaternion.Euler(0, 180, 0))
                                                 * shadowCameraViewMatrix;
                    }
                    else
                    { 
                        // 카메라의 회전만을 고려하거나 메인 라이트가 없을 경우
                        shadowCameraViewMatrix = Matrix4x4.Rotate(Quaternion.Euler(new Vector3(settings.shadowAngle, 0, 0)))
                                                 * camera.worldToCameraMatrix;
                    }

                    var minX = Mathf.Infinity;
                    var maxX = Mathf.NegativeInfinity;
                    var minY = Mathf.Infinity;
                    var maxY = Mathf.NegativeInfinity;
                    var minZ = Mathf.Infinity;
                    var maxZ = Mathf.NegativeInfinity;

                    // 대상 캐릭터 리스트 취득
                    var allCharacters = GakuRendererFeature.Instance.charaMaterialList;
                    var visibleCharacterCount = 0;
                    // 카메라 절두체를 생성
                    GeometryUtility.CalculateFrustumPlanes(camera, cameraPlanes);
                    
                    foreach (var character in allCharacters)
                    {
                        if (character == null) continue;
                        if (!character.isActiveAndEnabled) continue;

                        // 캐릭터의 골반을 중심 위치로 가정
                        var centerPosWS = character.GetPelvisPosition();
                        // 캐릭터의 중심 위치를 셀프 쉐도우의 뷰 공간으로 변환
                        var centerPosShadowCamVS = (Matrix4x4.Scale(new Vector3(1, 1, -1)) * shadowCameraViewMatrix).MultiplyPoint(centerPosWS);

                        // 카메라와 거리가 먼 경우는 무시
                        if (centerPosShadowCamVS.z - settings.boundSize > settings.shadowRange) continue;
                        // 원래의 카메라의 절두체에서 컬링되는 경우도 무시
                        var charaBounds = new Bounds(character.GetPelvisPosition(), charaBoundSize * settings.boundSize);
                        if (!GeometryUtility.TestPlanesAABB(cameraPlanes, charaBounds)) continue;

                        minX = Mathf.Min(minX, centerPosShadowCamVS.x - settings.boundSize);
                        maxX = Mathf.Max(maxX, centerPosShadowCamVS.x + settings.boundSize);
                        minY = Mathf.Min(minY, centerPosShadowCamVS.y - settings.boundSize);
                        maxY = Mathf.Max(maxY, centerPosShadowCamVS.y + settings.boundSize);
                        minZ = Mathf.Min(minZ, centerPosShadowCamVS.z - settings.boundSize);
                        maxZ = Mathf.Max(maxZ, centerPosShadowCamVS.z + settings.boundSize);

                        visibleCharacterCount++;
                    }

                    // 대상 캐릭이 없으면 Return
                    if (visibleCharacterCount == 0)
                    {
                        CoreUtils.SetKeyword(cmd, GakuEnableSelfShadowKeyword, false);
                        profilingScope.Dispose(); // 프로파일링을 빨리 끝냄
                        context.ExecuteCommandBuffer(cmd);
                        CommandBufferPool.Release(cmd);
                        return;
                    }

                    // 직교 투영 행렬 생성
                    var projectionMatrix = Matrix4x4.Ortho(minX, maxX, minY, maxY, minZ, maxZ);

                    // 컬링
                    camera.TryGetCullingParameters(out var cullingParameters);
                    cullingParameters.cullingMatrix = projectionMatrix * shadowCameraViewMatrix;
                    GeometryUtility.CalculateFrustumPlanes(cullingParameters.cullingMatrix, cullingPlanes);
                    for (var i = 0; i < cullingPlanes.Length; i++)
                        cullingParameters.SetCullingPlane(i, cullingPlanes[i]);
                    var cullResults = context.Cull(ref cullingParameters);

                    // 뷰 행렬, 투영 행렬을 덮어쓰기
                    cmd.SetViewProjectionMatrices(shadowCameraViewMatrix, projectionMatrix);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    // SelfShadow 패스를 가진 쉐이더를 렌더링
                    var drawSetting = CreateDrawingSettings(GakuSelfShadowCasterShaderTagId, ref renderingData, SortingCriteria.CommonOpaque);
                    var filterSetting = new FilteringSettings(RenderQueueRange.opaque);
                    context.DrawRenderers(cullResults, ref drawSetting, ref filterSetting);

                    // 뷰 행렬, 투영 행렬을 원래대로 되돌리기
                    cmd.SetViewProjectionMatrices(renderingData.cameraData.camera.worldToCameraMatrix, renderingData.cameraData.camera.projectionMatrix);

                    // 글로벌 텍스처에 세팅
                    cmd.SetGlobalTexture(Shader.PropertyToID(shadowMapRTHandle.name), new RenderTargetIdentifier(Shader.PropertyToID(shadowMapRTHandle.name)));
                    // 글로벌 변수에 값 설정
                    cmd.SetGlobalFloat(GakuSelfShadowRangeSid, settings.shadowRange);
                    // 실행 예약
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    // 그래픽 API에 맞게 조정된 투영 행렬 획득
                    var gpuProjectionMatrix = GL.GetGPUProjectionMatrix(projectionMatrix, true);
                    var gpuWorldToClip = gpuProjectionMatrix * shadowCameraViewMatrix;

                    // 글로벌 변수에 값 설정
                    cmd.SetGlobalMatrix(GakuSelfShadowWorldToClipSid, gpuWorldToClip);
                    var shadowMapSize = (int)settings.shadowMapSize;
                    cmd.SetGlobalVector(GakuSelfShadowParamSid, new Vector4(1f / shadowMapSize, 1f / shadowMapSize, shadowMapSize, shadowMapSize));
                    cmd.SetGlobalFloat(GakuGlobalSelfShadowDepthBiasSid, settings.depthBias * 0.005f);
                    cmd.SetGlobalVector(GakuSelfShadowLightDirectionSid, shadowCameraViewMatrix.inverse.MultiplyVector(Vector3.forward));
                    cmd.SetGlobalFloat(GakuSelfShadowUseNdotLFixSid, settings.useNdotLFix ? 1 : 0);
                }
                CoreUtils.SetKeyword(cmd, GakuEnableSelfShadowKeyword, settings.enableSelfShadowPass);
            }
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }
}
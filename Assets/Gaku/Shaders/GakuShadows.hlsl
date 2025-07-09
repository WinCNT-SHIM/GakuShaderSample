#pragma once

float GetSelfShadow(float3 positionWS, float3 normalWS)
{
    float attenuation = 1;

    float4 positionSelfShadowCS = mul(_GakuSelfShadowWorldToClip, float4(positionWS.xyz, 1));
    float3 positionSelfShadowNDC = positionSelfShadowCS.xyz;

    float2 shadowMapUV_XY = positionSelfShadowNDC.xy * 0.5 + 0.5;

    // NDC의 Z를 보정하는 값을 만들기
    float ndcZCompareValue = positionSelfShadowNDC.z;
    ndcZCompareValue = UNITY_NEAR_CLIP_VALUE < 0 ? ndcZCompareValue * 0.5 + 0.5 : ndcZCompareValue;
    ndcZCompareValue += _GakuGlobalSelfShadowDepthBias * UNITY_NEAR_CLIP_VALUE;

    #if UNITY_UV_STARTS_AT_TOP
    shadowMapUV_XY.y = 1 - shadowMapUV_XY.y;
    #endif
    float4 selfShadowCoord = float4(shadowMapUV_XY, ndcZCompareValue, 0);

    // 셀프 쉐도우 맵을 샘플링
    #if _SHADOWS_SOFT
    ShadowSamplingData shadowSamplingData = (ShadowSamplingData)0;
    shadowSamplingData.shadowmapSize = _GakuSelfShadowParam;
    shadowSamplingData.shadowOffset0 = float4(-_GakuSelfShadowParam.x, -_GakuSelfShadowParam.y, _GakuSelfShadowParam.x, -_GakuSelfShadowParam.y);
    shadowSamplingData.shadowOffset1 = float4(-_GakuSelfShadowParam.x, _GakuSelfShadowParam.y, _GakuSelfShadowParam.x, _GakuSelfShadowParam.y);

    // Shadows.hlsl의 SampleShadowmapFilteredLowQuality
    float4 attenuation4;
    attenuation4.x = float(SAMPLE_TEXTURE2D_SHADOW(_GakuSelfShadowMapRT, sampler_GakuSelfShadowMapRT, selfShadowCoord.xyz + float3(shadowSamplingData.shadowOffset0.xy, 0)));
    attenuation4.y = float(SAMPLE_TEXTURE2D_SHADOW(_GakuSelfShadowMapRT, sampler_GakuSelfShadowMapRT, selfShadowCoord.xyz + float3(shadowSamplingData.shadowOffset0.zw, 0)));
    attenuation4.z = float(SAMPLE_TEXTURE2D_SHADOW(_GakuSelfShadowMapRT, sampler_GakuSelfShadowMapRT, selfShadowCoord.xyz + float3(shadowSamplingData.shadowOffset1.xy, 0)));
    attenuation4.w = float(SAMPLE_TEXTURE2D_SHADOW(_GakuSelfShadowMapRT, sampler_GakuSelfShadowMapRT, selfShadowCoord.xyz + float3(shadowSamplingData.shadowOffset1.zw, 0)));
    attenuation = dot(attenuation4, float(0.25));
    #else
    attenuation = float(SAMPLE_TEXTURE2D_SHADOW(_GakuSelfShadowMapRT, sampler_GakuSelfShadowMapRT, selfShadowCoord.xyz));
    #endif

    // 카툰 렌더링에서 좀 더 그림자 경계를 깔끔하게 출력하기 위한 Magic Number~
    attenuation = smoothstep(0.15, 0.3, attenuation);
    
    // 내적으로 인한 보정
    attenuation *= _GakuSelfShadowUseNdotLFix ? smoothstep(0.1, 0.2, saturate(dot(normalWS, _GakuSelfShadowLightDirection))) : 1;
    
    return saturate(attenuation);
}
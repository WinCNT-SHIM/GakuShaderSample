#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct GakuInputData
{
    float3  positionWS;
    float4  positionCS;
    float3  normalWS;
    half3   viewDirectionWS;
    float4  shadowCoord;
    half    fogCoord;
    half3   vertexLighting;
    half3   bakedGI;
    float2  normalizedScreenSpaceUV;
    half4   shadowMask;
    half3x3 tangentToWorld;
};

CBUFFER_START(UnityPerMaterial)
float4 _BaseColor;
float4 _DefValue;
float _EnableLayerMap;
float _RenderMode;
float _BumpScale;
float _AnisotropicScale;
float4 _RampAddColor;
float4 _RimColor;
float _VertexColor;
float4 _OutlineColor;
float _EnableEmission;
float _RefractThickness;
float _DefDebugMask;
float4 _SpecularThreshold;
float4 _FadeParam;
float _ShaderType;
float _ClipValue;
float _Cull;
float _SrcBlend;
float _DstBlend;
float _SrcAlphaBlend;
float _DstAlphaBlend;
float _ColorMask;
float _ColorMask1;
float _ZWrite;
float _StencilRef;
float _StencilReadMask;
float _StencilWriteMask;
float _StencilComp;
float _StencilPass;
float _ActorIndex;
float _LayerWeight;
float _SkinSaturation;
float4 _HeadDirection;
float4 _HeadUpDirection;
float4 _MultiplyColor;
float4 _MultiplyOutlineColor;
float _UseLastFramePositions;
float4x4 _HeadXAxisReflectionMatrix;
float4 _BaseMap_ST;
float4 _MatCapParam;
float4 _MatCapMainLight;
float4 _MatCapLightColor;
float4 _ShadeMultiplyColor;
float4 _ShadeAdditiveColor;
float4 _EyeHighlightColor;
float4 _VLSpecColor;
float4 _VLEyeSpecColor;
float4 _MatCapRimColor;
float4 _MatCapRimLight;
float4 _GlobalLightParameter;
float4 _ReflectionSphereMap_HDR;
float4 _OutlineParam;
CBUFFER_END

TEXTURE2D(_BaseMap);                 SAMPLER(sampler_BaseMap);
TEXTURE2D(_ShadeMap);                SAMPLER(sampler_ShadeMap);
TEXTURE2D(_RampMap);                 SAMPLER(sampler_RampMap);
TEXTURE2D(_HighlightMap);            SAMPLER(sampler_HighlightMap);
TEXTURE2D(_DefMap);                  SAMPLER(sampler_DefMap);
TEXTURE2D(_LayerMap);                SAMPLER(sampler_LayerMap);
TEXTURE2D(_BumpMap);                 SAMPLER(sampler_BumpMap);
TEXTURE2D(_AnisotropicMap);          SAMPLER(sampler_AnisotropicMap);
TEXTURE2D(_RampAddMap);              SAMPLER(sampler_RampAddMap);
TEXTURE2D(_EmissionMap);             SAMPLER(sampler_EmissionMap);
TEXTURE2D(_ReflectionSphereMap);     SAMPLER(sampler_ReflectionSphereMap);
TEXTURECUBE(_VLSpecCube);            SAMPLER(sampler_VLSpecCube);

//////////////////////////////////////////////////
/// 셀프 쉐도우용
//////////////////////////////////////////////////
// 글로벌 텍스처
TEXTURE2D(_GakuSelfShadowMapRT);    SAMPLER_CMP(sampler_GakuSelfShadowMapRT);
// 글로벌 변수
float _GakuSelfShadowRange;
float4x4 _GakuSelfShadowWorldToClip;
float4 _GakuSelfShadowParam;
float _GakuGlobalSelfShadowDepthBias;
half3 _GakuSelfShadowLightDirection;
half _GakuSelfShadowUseNdotLFix;
// float _SelfShadowMappingPosOffset;
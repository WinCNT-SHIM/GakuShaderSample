#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes
{
    float4 Position             : POSITION; 
    float3 Normal               : NORMAL;
    float4 Tangent              : TANGENT;   
    float2 UV0                  : TEXCOORD0;
    float2 UV1                  : TEXCOORD1;
    float4 Color                : COLOR;  
    float3 PrePosition          : TEXCOORD4;
};

struct Varyings
{
    float4 PositionCS           : SV_POSITION;
    float4 UV                   : TEXCOORD0;
    float3 PositionWS           : TEXCOORD1;
    float4 Color1               : COLOR; 
    float4 Color2               : TEXCOORD2;
    float3 NormalWS             : TEXCOORD3;
    float3 NormalHeadReflect    : TEXCOORD4;
    float4 ShadowCoord          : TEXCOORD6;
    float4 PositionCSNoJitter   : TEXCOORD7;
    float4 PrePosionCS          : TEXCOORD8;
};

struct GakuVertexColor
{
    float4 OutlineColor;
    float OutlineWidth;
    float OutlineOffset;
    float RampAddID;
    float RimMask;
};

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
/// 버텍스 컬러 디코드 함수
//////////////////////////////////////////////////
void Decode8BitTo4Bit(float4 color, out float4 highNibble, out float4 lowNibble)
{
    // 0~255 정수로 변환 (반올림)
    uint4 c = (uint4)(color * 255.0f + 0.5f);

    // 상위 4비트: 16으로 나눔 == 우측 시프트 4
    uint4 High = c >> 4;
    // 하위 4비트: 0xF(1111) 마스크
    uint4 Low  = c & 0xF;

    // 0~15 → 0~1 정규화
    const float norm = 1.0f / 15.0f;
    highNibble = (float4) High * norm;
    lowNibble = (float4) Low  * norm;
}

GakuVertexColor DecodeVertexColor(float4 VertexColor)
{
    GakuVertexColor OutColor;
    float4 LowBit, HighBit;
    Decode8BitTo4Bit(VertexColor, HighBit, LowBit);
    OutColor.OutlineColor = float4(HighBit.x, LowBit.x, HighBit.y, LowBit.w);
    OutColor.OutlineWidth = LowBit.z;
    OutColor.OutlineOffset = HighBit.z;
    OutColor.RampAddID = LowBit.y;
    OutColor.RimMask = HighBit.w;
    return OutColor;
}

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
float4 _OutlineParam;
// float _SelfShadowMappingPosOffset;
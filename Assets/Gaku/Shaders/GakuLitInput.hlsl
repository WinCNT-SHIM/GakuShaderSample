#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

Texture2D _BaseMap;                 SAMPLER(sampler_BaseMap);
Texture2D _ShadeMap;                SAMPLER(sampler_ShadeMap);
Texture2D _RampMap;                 SAMPLER(sampler_RampMap);
Texture2D _HighlightMap;            SAMPLER(sampler_HighlightMap);
Texture2D _DefMap;                  SAMPLER(sampler_DefMap);
Texture2D _LayerMap;                SAMPLER(sampler_LayerMap);
Texture2D _BumpMap;                 SAMPLER(sampler_BumpMap);
Texture2D _AnisotropicMap;          SAMPLER(sampler_AnisotropicMap);
Texture2D _RampAddMap;              SAMPLER(sampler_RampAddMap);
Texture2D _EmissionMap;             SAMPLER(sampler_EmissionMap);
Texture2D _ReflectionSphereMap;     SAMPLER(sampler_ReflectionSphereMap);
TextureCube _VLSpecCube;            SAMPLER(sampler_VLSpecCube);
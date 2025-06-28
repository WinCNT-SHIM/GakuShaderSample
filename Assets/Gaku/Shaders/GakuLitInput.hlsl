#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseMap_TexelSize;
float4 _DetailAlbedoMap_ST;
half4 _BaseColor;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _Parallax;
half _OcclusionStrength;
half _ClearCoatMask;
half _ClearCoatSmoothness;
half _DetailAlbedoMapScale;
half _DetailNormalMapScale;
half _Surface;
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
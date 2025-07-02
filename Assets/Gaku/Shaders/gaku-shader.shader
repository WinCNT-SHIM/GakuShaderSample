Shader "Gaku/Character/Default"
{
    Properties
    {
		_BaseMap ("Base (RGB)", 2D) = "white" { }
		[HDR] _BaseColor ("Base Color", Color) = (1,1,1,1)
		[Toggle(_ALPHAPREMULTIPLY_ON)] _AlphaPremultiply ("Alpha Premultiply", Float) = 0
		_ShadeMap ("Shade (RGB)", 2D) = "white" { }
		_RampMap ("Ramp (RGB) Ramp (A)", 2D) = "white" { }
		_HighlightMap ("Highlight (RGB)", 2D) = "black" { }
		[Toggle(_DEFMAP_OFF)]_DisableDefMap ("Disable DefMap", Float) = 0
		_DefMap ("Def", 2D) = "white" { }
		_DefValue ("DefValue", Vector) = (0.5,0,1,0)
		[Toggle(_LAYERMAP_ON)]_EnableLayerMap ("Use LayerMap", Float) = 0
		_LayerMap ("Layer (RGB)", 2D) = "white" { }
		_RenderMode ("Optional Rendering Mode", Float) = 0
		_BumpScale ("Scale", Float) = 1
		_BumpMap ("Normal", 2D) = "bump" { }
		_AnisotropicMap ("Anisotropic Tangent(RG) AnisoMask(B)", 2D) = "black" { }
		_AnisotropicScale ("Anisotropic Scale", Range(-0.95, 0.95)) = 1
		[Toggle(_RAMPADD_ON)]_EnableRampAddMap ("Use RampAddMap", Float) = 0
		_RampAddMap ("RampAdd (RGB)", 2D) = "white" { }
		[HDR] _RampAddColor ("RampAdd Color", Color) = (1,1,1,1)
		[HDR] _RimColor ("Rim Color", Color) = (0,0,0,0)
		[Toggle] _VertexColor ("Use VertexColor", Float) = 0
		_OutlineColor ("Outline Color", Color) = (0,0,0,0)
		[Toggle(_EMISSION)] _EnableEmission ("Enable Emission", Float) = 0
		_EmissionMap ("EmissionMap", 2D) = "black" { }
		[HDR] _EmissionColor ("Emission Color", Color) = (0,0,0,0)
		_RefractThickness ("Refract Thickness", Float) = 0
		_DefDebugMask ("Def Debug", Float) = 15
		_SpecularThreshold ("Specular Threshold", Vector) = (0.6,0.05,0,0)
		[KeywordEnum(REFLECTION_TEXTURE, EYE_REFLECTION_TEXTURE)]_USE("ReflectionSwitch", Float) = 0
		[Toggle(_USE_REFLECTION_SPHERE)]_EnableReflectionSphereMap ("Use ReflectionSphereMap", Float) = 0
		_ReflectionSphereMap ("Reflection Sphere", 2D) = "black" { }
		_FadeParam ("Fade x=XOffset y=XScale z=YOffset w=YScale", Vector) = (0.75,2,0.4,4)
		_ShaderType ("Shader Type", Float) = 0
		[Toggle(_ALPHATEST_ON)] _AlphaTest("AlphaTest", Float) = 0.0
		_ClipValue ("Clip Value", Range(0.0, 1.0)) = 0.33
		[Enum(UnityEngine.Rendering.CullMode)]_Cull ("__cull", Float) = 2
		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("__src", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("__dst", Float) = 0
		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlendAlpha ("__srcAlpha", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlendAlpha ("__dstAlpha", Float) = 0
		_ColorMask ("__colormask", Float) = 15
		_ColorMask1 ("__colormask1", Float) = 15
		_ZWrite ("__zw", Float) = 1
		[Toggle(_ENALBEHAIRCOVER_ON)] _EnalbeHairCover("EnalbeHairCover", Float) = 0.0
		_StencilRef ("__stencilRef", Float) = 64
		_StencilReadMask ("__stencilRead", Float) = 108
		_StencilWriteMask ("__stencilWrite", Float) = 108
		[Enum(UnityEngine.Rendering.CompareFunction)]_StencilComp ("__stencilComp", Float) = 8
		[Enum(UnityEngine.Rendering.StencilOp)]_StencilPass ("__stencilPass", Float) = 2
		[PerRendererData] _ActorIndex ("Actor Index", Float) = 15
		// [PerRendererData] _LayerWeight ("Layer Weight", Float) = 0
		_LayerWeight ("Layer Weight", Float) = 0
		[PerRendererData]_HeadDirection ("Direction", Vector) = (0,0,1,1)
		[PerRendererData]_HeadUpDirection ("Up Direction", Vector) = (0,1,0,1)
		[PerRendererData] _MultiplyColor ("Multiply Color", Color) = (1,1,1,1)
		[PerRendererData] _MultiplyOutlineColor ("Outline Multiply Color", Color) = (1,1,1,1)
		[PerRendererData] _UseLastFramePositions ("Use Last Frame Positions", Float) = 0
    	
		[HideInInspector] _MatCapMainLight ("MatCap Main Light", Vector) = (0, 0.7071, 0.7071, 0)
		[HideInInspector] _ShadeMultiplyColor ("Shade Multiply Color", Color) = (0,0,0,0)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        LOD 300
    	
        Pass
        {
        	Name "GakuForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            // -------------------------------------
            // Render State Commands
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite[_ZWrite]
            Cull[_Cull]
            // AlphaToMask[_AlphaToMask]
            
			Stencil
			{
				Ref [_StencilRef]
				ReadMask [_StencilReadMask]
				WriteMask [_StencilWriteMask]
				Comp [_StencilComp]
				Pass [_StencilPass]
			}
            
            HLSLPROGRAM
            // -------------------------------------
            // Shader Stages
            #pragma vertex GakuLitPassVertex
            #pragma fragment GakuLitPassFragment
			
            // -------------------------------------
            // Material Keywords
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            
			#include_with_pragmas "GakuLitInput.hlsl"
			#include_with_pragmas "GakuLitForwardPass.hlsl"
            
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}

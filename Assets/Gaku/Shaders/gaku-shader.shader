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
		[Toggle(_RAMPADD_ON)] _EnableRampAddMap ("Use RampAddMap", Float) = 0
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
		[KeywordEnum(REFLECTION_TEXTURE, EYE_REFLECTION_TEXTURE)] _USE("ReflectionSwitch", Float) = 0
		[Toggle(_USE_REFLECTION_SPHERE)] _EnableReflectionSphereMap ("Use ReflectionSphereMap", Float) = 0
		_ReflectionSphereMap ("Reflection Sphere", 2D) = "black" { }
		_FadeParam ("Fade x=XOffset y=XScale z=YOffset w=YScale", Vector) = (0.75,2,0.4,4)
		_ShaderType ("Shader Type", Float) = 0
		[Toggle(_ALPHATEST_ON)] _AlphaTest("AlphaTest", Float) = 0.0
		_ClipValue ("Clip Value", Range(0.0, 1.0)) = 0.33
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("__cull", Float) = 2
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("__src", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("__dst", Float) = 0
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendAlpha ("__srcAlpha", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha ("__dstAlpha", Float) = 0
		_ColorMask ("__colormask", Float) = 15
		_ColorMask1 ("__colormask1", Float) = 15
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZWrite ("__zw", Float) = 1
		[Toggle(_ENALBEHAIRCOVER_ON)] _EnalbeHairCover("EnalbeHairCover", Float) = 0.0
		_StencilRef ("__stencilRef", Float) = 64
		_StencilReadMask ("__stencilRead", Float) = 108
		_StencilWriteMask ("__stencilWrite", Float) = 108
		[Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("__stencilComp", Float) = 8
		[Enum(UnityEngine.Rendering.StencilOp)] _StencilPass ("__stencilPass", Float) = 2
		[PerRendererData] _ActorIndex ("Actor Index", Float) = 15
		// [PerRendererData] _LayerWeight ("Layer Weight", Float) = 0
		_LayerWeight ("Layer Weight", Float) = 0
		[PerRendererData] _HeadDirection ("Direction", Vector) = (0,0,1,1)
		[PerRendererData] _HeadUpDirection ("Up Direction", Vector) = (0,1,0,1)
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
            Blend [_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite [_ZWrite]
            Cull [_Cull]
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
            #pragma shader_feature_local _ALPHATEST_ON
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            // #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            // #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            // #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            // #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            // #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            // #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            // #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            // #pragma multi_compile_fragment _ _LIGHT_COOKIES
            // #pragma multi_compile _ _LIGHT_LAYERS
            // #pragma multi_compile _ _CLUSTER_LIGHT_LOOP

            // -------------------------------------
            // Gaku keywords
            #pragma shader_feature_local _ _RAMPADD_ON
            #pragma shader_feature_local _ _DEFMAP_OFF
			#pragma shader_feature_local _ _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local _ _USE_REFLECTION_TEXTURE _USE_EYE_REFLECTION_TEXTURE
			#pragma shader_feature_local _ _USE_REFLECTION_SPHERE
            
			#include "GakuLitInput.hlsl"
			#include "GakuLitForwardPass.hlsl"
            
            ENDHLSL
        }
        // Outline
		Pass
		{
			Name "Outline"
			Tags
			{
				"LightMode"="UniversalForwardOutline"
			}
			Cull Front
			ZWrite [_ZWrite]
			Blend One Zero, One Zero
			
			HLSLPROGRAM
            // -------------------------------------
            // Shader Stages
            #pragma vertex GakuOutlineVertex
            #pragma fragment GakuOutlineFragment
            
			#include "GakuLitInput.hlsl"

            Varyings GakuOutlineVertex(Attributes input)
            {
            	Varyings output = (Varyings)0;

            	UNITY_SETUP_INSTANCE_ID(input);
            	UNITY_TRANSFER_INSTANCE_ID(input, output);
            	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

            	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.Position.xyz);
            	// 탄젠트에 부드러운 노멀 값이 담겨있음
				float3 SmoothNormalWS = TransformObjectToWorldNormal(input.Tangent);
            	// 버텍스 컬러에 아웃라인에 관한 정보가 담겨있음
            	GakuVertexColor VertexColor = DecodeVertexColor(input.Color);
            	output.Color1 = VertexColor.OutlineColor;
            	output.Color2 = float4(
			        VertexColor.OutlineWidth,
			        VertexColor.OutlineOffset,
			        VertexColor.RampAddID,
			        VertexColor.RimMask
			    );
            	
				float CameraDistance = length(_WorldSpaceCameraPos - vertexInput.positionWS);
				float OutLineWidth = min(CameraDistance * _OutlineParam.z * _OutlineParam.w, 1.0f);
				OutLineWidth = lerp(_OutlineParam.x, _OutlineParam.y, OutLineWidth);
				OutLineWidth *= 0.01f * VertexColor.OutlineWidth;

				float3 OffsetVector = OutLineWidth * SmoothNormalWS;
				float3 OffsetedPositionWS = vertexInput.positionWS + OffsetVector;
				float4 OffsetedPositionCS = TransformWorldToHClip(OffsetedPositionWS);
            	// Z‑파이팅(깊이 충돌)을 피하기 위한 0.000066667
				OffsetedPositionCS.z -= VertexColor.OutlineOffset * 6.66666747e-05;
				output.PositionCS = OffsetedPositionCS;
            	
            	return output;
            }

            half4 GakuOutlineFragment(Varyings input, bool IsFront : SV_IsFrontFace) : SV_Target0
			{
				float3 OutlineColor = input.Color1.xyz * _MultiplyOutlineColor.xyz;
				float OutlineAlpha = _MultiplyColor.a;

				// _ShaderType가 1인 경우는 아웃라인을 만들지 않음
				if (_ShaderType == 1) discard;
				
				return float4(OutlineColor, OutlineAlpha);
			}
			ENDHLSL
		}
        // Shadow Caster
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
        // Self Shadow
        Pass
        {
            Name "GakuSelfShadowCaster"
            Tags
            {
                "LightMode" = "GakuSelfShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include_with_pragmas "GakuLitInput.hlsl"

            float3 _LightDirection;

            struct VertexInput
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 positionCS : SV_POSITION;
            };


            VertexOutput vert(VertexInput input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                VertexOutput o;
                //ShadowCasterPass.hlslより
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float4 positionCS = TransformWorldToHClip(positionWS);

                #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                o.positionCS = positionCS;

                return o;
            }

            void frag(VertexOutput input)
            {
                half2 screenPos = input.positionCS.xy / _ScaledScreenParams.xy;
                // TODO: 디더링은 나중에
                // float cutoff = lerp(0.5, Unity_Dither(screenPos), _DitherFade);
                // clip(1 - _DitherFade - cutoff);
            }
            ENDHLSL
        }
    }
}

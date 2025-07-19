#pragma once

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "GakuShadows.hlsl"

void InitializeInputData(Varyings input, half3 normalTS, out GakuInputData inputData)
{
    
}

BRDFData InitializeGakuBRDFData(float3 BaseColor, float Smoothness, float Metallic, float Specular, bool IsEye)
{
    float OutAlpha = 1.0f;
    BRDFData brdfData;
    InitializeBRDFData(BaseColor, Metallic, Specular, Smoothness, OutAlpha, brdfData);
    brdfData.grazingTerm = IsEye ? saturate(Smoothness + kDielectricSpec.x) : brdfData.grazingTerm;
    brdfData.diffuse = IsEye ? BaseColor * kDielectricSpec.a : brdfData.diffuse;
    brdfData.specular = IsEye ? BaseColor : brdfData.specular;
    return brdfData;
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////
Varyings GakuLitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.Position.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.Normal, input.Tangent);
    output.UV.xy = TRANSFORM_TEX(input.UV0, _BaseMap);
    output.UV.zw = input.UV1.xy;

    output.NormalWS = normalInput.normalWS;
    output.PositionWS = vertexInput.positionWS;
    output.ShadowCoord = GetShadowCoord(vertexInput);

    GakuVertexColor VertexColor = DecodeVertexColor(input.Color);
    output.Color1 = VertexColor.OutlineColor;
    output.Color2 = float4(
        VertexColor.OutlineWidth,
        VertexColor.OutlineOffset,
        VertexColor.RampAddID,
        VertexColor.RimMask
    );
    
    output.PositionCS = vertexInput.positionCS;
    
    return output;
}

// void GakuLitPassFragment(
//     Varyings input
//     , bool IsFront : SV_IsFrontFace
//     , out half4 outColor : SV_Target0
// )
half4 GakuLitPassFragment(
    Varyings input
    , bool IsFront : SV_IsFrontFace
) : SV_Target0
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    // SurfaceData surfaceData;
    // InitializeStandardLitSurfaceData(input.uv, surfaceData);
    
    GakuVertexColor VertexColor;
    VertexColor.OutlineColor = input.Color1;
    VertexColor.OutlineWidth = input.Color2.x;
    VertexColor.OutlineOffset = input.Color2.y;
    VertexColor.RampAddID = input.Color2.z;
    VertexColor.RimMask = input.Color2.w;

    bool IsFace = _ShaderType == 9;
    bool IsHair = _ShaderType == 8;
    bool IsEye = _ShaderType == 4;
    bool IsEyeHightLight = _ShaderType == 5;
    bool IsEyeBrow = _ShaderType == 6;
    
    float3 NormalWS = normalize(input.NormalWS);
    NormalWS = IsFront ? NormalWS : -NormalWS;
    
    half3 ViewDirection = GetWorldSpaceNormalizeViewDir(input.PositionWS);
    
    Light mainLight = GetMainLight();
    float NoL = dot(NormalWS, mainLight.direction);
    // float MatCapNoL = dot(NormalMatS, _MatCapMainLight);
    // bool DisableMatCap = _MatCapMainLight.w > 0.5f;
    // NoL = DisableMatCap ? NoL : MatCapNoL;
    
    // float Shadow = MainLightRealtimeShadow(input.ShadowCoord);
    float Shadow = GetSelfShadow(input.PositionWS, NormalWS);
    float ShadowFadeOut = dot(-ViewDirection, -ViewDirection);
    ShadowFadeOut = saturate(ShadowFadeOut * _MainLightShadowParams.z + _MainLightShadowParams.w);
    ShadowFadeOut *= ShadowFadeOut;
    // Shadow = lerp(Shadow, 1, ShadowFadeOut);
    Shadow = lerp(1.0f, Shadow, _MainLightShadowParams.x);
    Shadow = saturate(Shadow * ((4.0f * Shadow - 6) * Shadow + 3.0f));
    
    half4 BaseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.UV.xy);
    half4 ShadeMap = SAMPLE_TEXTURE2D(_ShadeMap, sampler_ShadeMap, input.UV.xy);
    
    half4 DefMap = _DefValue;
    #if !defined(_DEFMAP_OFF)
    DefMap = SAMPLE_TEXTURE2D(_DefMap, sampler_DefMap, input.UV.xy).xyzw;
    #endif
    float DefDiffuse = DefMap.x;
    float DefMetallic = DefMap.z;
    float DefSmoothness = DefMap.y;
    float DefSpecular = DefMap.w;
    
    float3 CameraUp = unity_MatrixV[1].xyz;
    float3 ViewSide = normalize(cross(ViewDirection, CameraUp));
    float3 ViewUp = normalize(cross(ViewSide, ViewDirection));
    float3x3 WorldToMatcap = float3x3(ViewSide, ViewUp, ViewDirection);
    float3 NormalMatS = mul(WorldToMatcap, float4(NormalWS, 0.0f));
    
    float DiffuseOffset = DefDiffuse * 2.0f - 1.0f;
    float Smoothness = min(DefSmoothness, 1);
    float Metallic = DefMetallic;
    
    float SpecularIntensity = min(DefSpecular, Shadow);
    
    if (IsHair)
    {
        // 머리 장신구인지는 UV의 값을 보고 판단
        float IsHairProp = saturate(input.UV.x - 0.75f) * saturate(input.UV.y - 0.75f);
        IsHairProp = IsHairProp != 0;
        
        // float HairSpecular = Pow4(saturate(dot(NormalWorM, ViewDirWorM)));
        float HairSpecular = Pow4(saturate(dot(NormalWS, ViewDirection)));
        HairSpecular = smoothstep(_SpecularThreshold.x - _SpecularThreshold.y, _SpecularThreshold.x + _SpecularThreshold.y, HairSpecular);
        HairSpecular *= SpecularIntensity;
        HairSpecular = IsHairProp ? 0 : HairSpecular;
		
        float3 HighlightMap = SAMPLE_TEXTURE2D(_HighlightMap, sampler_HighlightMap, input.UV.xy).xyz;
        BaseMap.xyz = lerp(BaseMap.xyz, HighlightMap.xyz, HairSpecular);
        
        float HairFadeX = dot(_HeadDirection, ViewDirection);
        HairFadeX = _FadeParam.x - HairFadeX;
        HairFadeX = saturate(HairFadeX * _FadeParam.y);
        
        float HairFadeZ = dot(_HeadUpDirection, ViewDirection);
        HairFadeZ = abs(HairFadeZ) - _FadeParam.z;
        HairFadeZ = saturate(HairFadeZ * _FadeParam.w);
	
        BaseMap.a = lerp(1, max(HairFadeX, HairFadeZ), BaseMap.a);
        SpecularIntensity *= IsHairProp ? 1 : 0;
    }
    
    float4 RampAddMap = 0;
    float3 RampAddColor = 0;
    
    #if defined(_RAMPADD_ON)
    float2 RampAddMapUV = float2(saturate(DiffuseOffset + NormalMatS.z), VertexColor.RampAddID);
    RampAddMap = SAMPLE_TEXTURE2D(_RampAddMap, sampler_RampAddMap, RampAddMapUV);
    RampAddColor = RampAddMap.xyz * _RampAddColor.xyz;
    
    float3 DiffuseRampAddColor = lerp(RampAddColor, 0, RampAddMap.a);
    BaseMap.xyz += DiffuseRampAddColor;
    ShadeMap.xyz += DiffuseRampAddColor;
    #endif
    
    float BaseLighting = NoL * 0.5f + 0.5f;
    // BaseLighting = saturate(BaseLighting + (DiffuseOffset - _MatCapParam.x) * 0.5f);
    BaseLighting = saturate(BaseLighting + (DiffuseOffset - 0.025) * 0.5f);
    BaseLighting = min(BaseLighting, Shadow);
    
    float2 RampMapUV = float2(BaseLighting, 0);
    half4 RampMap = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, RampMapUV);
    
    const float ShadowIntensity = 0.55; // _MatCapParam.z? _MatCapParam (0,0,0.5490196,0)
    float3 RampedLighting = lerp(BaseMap.xyz, ShadeMap.xyz * _ShadeMultiplyColor, RampMap.w * ShadowIntensity);
    float3 SkinRampedLighting =	lerp(RampMap, RampMap.xyz * _ShadeMultiplyColor, RampMap.w);
    SkinRampedLighting = lerp(1, SkinRampedLighting, ShadowIntensity);
    SkinRampedLighting = BaseMap * SkinRampedLighting;
    RampedLighting = lerp(RampedLighting, SkinRampedLighting, ShadeMap.w);
    RampedLighting *= _BaseColor;
    
	BRDFData brdfData = InitializeGakuBRDFData(RampedLighting, Smoothness, Metallic, SpecularIntensity, IsEye);
    
    float3 IndirectSpecular = 0;
    float3 ReflectVector = reflect(-ViewDirection, NormalWS);
    
    #if defined(_USE_EYE_REFLECTION_TEXTURE)
    float ReflectionTextureMip = PerceptualRoughnessToMipmapLevel(brdfData.perceptualRoughness);
    float3 VLSpecCube = SAMPLE_TEXTURECUBE_LOD(_VLSpecCube, sampler_VLSpecCube, ReflectVector, ReflectionTextureMip);
    VLSpecCube *= _VLEyeSpecColor;
    IndirectSpecular = VLSpecCube;
    #endif

    float3 MatCapReflection = 0.0f;
    #if defined(_USE_REFLECTION_SPHERE)
    float2 ReflectionSphereMapUV = NormalMatS.xy * 0.5 + 0.5;
    float4 ReflectionSphereMap = SAMPLE_TEXTURE2D(_ReflectionSphereMap, sampler_ReflectionSphereMap, ReflectionSphereMapUV);
    
    float ReflectionSphereIntensity = lerp(1, ReflectionSphereMap.a, _ReflectionSphereMap_HDR.w);
    ReflectionSphereIntensity = max(ReflectionSphereIntensity, 0);
    ReflectionSphereIntensity = pow(ReflectionSphereIntensity, _ReflectionSphereMap_HDR.y);
    ReflectionSphereIntensity *= _ReflectionSphereMap_HDR.x;
    
    ReflectionSphereMap.xyz = ReflectionSphereMap.xyz * ReflectionSphereIntensity;
    MatCapReflection = ReflectionSphereMap.xyz;
    #endif

    half NdotV = saturate(dot(NormalWS, ViewDirection));
    float FresnelTerm = Pow4(1 - saturate(NdotV));
    float3 SpecularColor =  EnvironmentBRDFSpecular(brdfData, FresnelTerm);
    float3 SpecularTerm = DirectBRDFSpecular(brdfData, NormalWS, _MatCapMainLight, ViewDirection);
    float3 Specular = SpecularColor * IndirectSpecular;
    Specular += SpecularTerm * SpecularColor;
    Specular += MatCapReflection;
    Specular *= SpecularIntensity;
	Specular = lerp(Specular, Specular * RampAddColor, RampAddMap.w);

    float3 SH = SampleSH(NormalWS);
    float3 SkyLight = max(SH, 0);
    
    half4 color = half4(1,1,1,1);
    color.rgb = brdfData.diffuse;
    color.rgb += Specular;
    color.rgb += SkyLight;

    float alpha = BaseMap.a * _MultiplyColor.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _ClipValue);
    #endif
    #ifdef _ALPHAPREMULTIPLY_ON
    color *= alpha;
    #endif
    
    return color;
    
    // outColor.rgb = brdfData.diffuse;
    // outColor.rgb += Specular;
    // outColor.rgb += SkyLight;
    // outColor.rgb += RampMap.w * _ShadeAdditiveColor;
    
    // OutLighting += RimLightColor;
}
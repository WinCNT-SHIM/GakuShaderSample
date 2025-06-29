#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

BRDFData G_InitialBRDFData(float3 BaseColor, float Smoothness, float Metallic, float Specular, bool IsEye)
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
    
    output.PositionCS = vertexInput.positionCS;
    
    return output;
}

void GakuLitPassFragment(
    Varyings input
    , bool IsFront : SV_IsFrontFace
    , out half4 outColor : SV_Target0
)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    // SurfaceData surfaceData;
    // InitializeStandardLitSurfaceData(input.uv, surfaceData);
    
    half4 color = half4(1,1,1,1);
    
    float3 NormalWS = normalize(input.NormalWS);
    NormalWS = IsFront ? NormalWS : NormalWS * -1.0f;
    
    half3 ViewDirection = GetWorldSpaceNormalizeViewDir(input.PositionWS);
    float Shadow = MainLightRealtimeShadow(input.ShadowCoord);
    
    Light mainLight = GetMainLight();
    float NoL = dot(NormalWS, mainLight.direction);
    // float MatCapNoL = dot(NormalMatS, _MatCapMainLight);
    // bool DisableMatCap = _MatCapMainLight.w > 0.5f;
    // NoL = DisableMatCap ? NoL : MatCapNoL;
    float BaseLighting = NoL * 0.5f + 0.5f;
    
    half4 BaseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.UV.xy);
    half4 ShadeMap = SAMPLE_TEXTURE2D(_ShadeMap, sampler_ShadeMap, input.UV.xy);
    half4 DefMap = SAMPLE_TEXTURE2D(_DefMap, sampler_DefMap, input.UV.xy).xyzw;
    float2 RampMapUV = float2(BaseLighting, 0);
    half4 RampMap = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, RampMapUV);
    
    float DefDiffuse = DefMap.x;
    float DefMetallic = DefMap.z;
    float DefSmoothness = DefMap.y;
    float DefSpecular = DefMap.w;

    float DiffuseOffset = DefDiffuse * 2.0f - 1.0f;
    float Smoothness = min(DefSmoothness, 1);
    float Metallic = DefMetallic;
	
    float SpecularIntensity = min(DefSpecular, Shadow);
    
    const float ShadowIntensity = 1; // _MatCapParam.z?
    float3 RampedLighting = lerp(BaseMap.xyz, ShadeMap.xyz * _ShadeMultiplyColor, RampMap.w * ShadowIntensity);
    float3 SkinRampedLighting =	lerp(RampMap, RampMap.xyz * _ShadeMultiplyColor, RampMap.w);
    SkinRampedLighting = lerp(1, SkinRampedLighting, ShadowIntensity);
    SkinRampedLighting = BaseMap * SkinRampedLighting;
    RampedLighting = lerp(RampedLighting, SkinRampedLighting, ShadeMap.w);
    
    float SkinSaturation = _SkinSaturation - 1;
    SkinSaturation = SkinSaturation * ShadeMap.w + 1.0f;
    RampedLighting = lerp(Luminance(RampedLighting), RampedLighting, SkinSaturation);
    RampedLighting *= _BaseColor;
    
	BRDFData brdfData = G_InitialBRDFData(RampedLighting, Smoothness, Metallic, SpecularIntensity, false);
    
    float3 IndirectSpecular = 0;
    float3 ReflectVector = reflect(-ViewDirection, NormalWS);

    half NdotV = saturate(dot(NormalWS, ViewDirection));
    float FresnelTerm = Pow4(1 - saturate(NdotV));
    float3 SpecularColor =  EnvironmentBRDFSpecular(brdfData, FresnelTerm);
    float3 SpecularTerm = DirectBRDFSpecular(brdfData, NormalWS, _MatCapMainLight, ViewDirection);
    float3 Specular = SpecularColor * IndirectSpecular;
    Specular += SpecularTerm * SpecularColor;
    // Specular += MatCapReflection;
    Specular *= SpecularIntensity;
	// Specular = lerp(Specular, Specular * RampAddColor, RampAddMap.w);
    
    outColor.rgb = brdfData.diffuse;
	outColor.rgb += Specular;
    
    // outColor = color;
}
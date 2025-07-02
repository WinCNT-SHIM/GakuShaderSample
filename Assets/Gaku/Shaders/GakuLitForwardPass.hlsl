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

struct GakuVertexColor
{
    float4 OutLineColor;
    float OutLineWidth;
    float OutLineOffset;
    float RampAddID;
    float RimMask;
};

void Decode4BitFrom8Bit(float4 C, out float4 A, out float4 B)
{
    const float k = 1.0f / 15.0f;
    float4 HighBit = floor(C * 15.9375f + 0.03125f);
    float4 LowBit = C * 255.0f - HighBit * 16.0f;
    A = HighBit * k;
    B = LowBit * k;
}

GakuVertexColor DecodeVertexColor(float4 VertexColor)
{
    GakuVertexColor OutColor;
    float4 LowBit, HighBit;
    Decode4BitFrom8Bit(VertexColor, HighBit, LowBit);
    OutColor.OutLineColor = float4(HighBit.x, LowBit.x, HighBit.y, LowBit.w);
    OutColor.OutLineWidth = LowBit.z;
    OutColor.OutLineOffset = HighBit.z;
    OutColor.RampAddID = LowBit.y;
    OutColor.RimMask = HighBit.w;
    return OutColor;
}

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

    GakuVertexColor VertexColor = DecodeVertexColor(input.Color);
    output.Color1 = VertexColor.OutLineColor;
    output.Color2 = float4(
        VertexColor.OutLineWidth,
        VertexColor.OutLineOffset,
        VertexColor.RampAddID,
        VertexColor.RimMask
    );
    
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
    
    GakuVertexColor VertexColor;
    VertexColor.OutLineColor = input.Color1;
    VertexColor.OutLineWidth = input.Color2.x;
    VertexColor.OutLineOffset = input.Color2.y;
    VertexColor.RampAddID = input.Color2.z;
    VertexColor.RimMask = input.Color2.w;
    
    float3 NormalWS = normalize(input.NormalWS);
    NormalWS = IsFront ? NormalWS : NormalWS * -1.0f;
    
    half3 ViewDirection = GetWorldSpaceNormalizeViewDir(input.PositionWS);
    
    Light mainLight = GetMainLight();
    float NoL = dot(NormalWS, mainLight.direction);
    // float MatCapNoL = dot(NormalMatS, _MatCapMainLight);
    // bool DisableMatCap = _MatCapMainLight.w > 0.5f;
    // NoL = DisableMatCap ? NoL : MatCapNoL;
    
    float Shadow = MainLightRealtimeShadow(input.ShadowCoord);
    
    float ShadowFadeOut = dot(-ViewDirection, -ViewDirection);
    ShadowFadeOut = saturate(ShadowFadeOut * _MainLightShadowParams.z + _MainLightShadowParams.w);
    ShadowFadeOut *= ShadowFadeOut;
    Shadow = lerp(Shadow, 1, ShadowFadeOut);
    Shadow = lerp(1.0f, Shadow, _MainLightShadowParams.x);
    Shadow = saturate(Shadow * ((4.0f * Shadow - 6) * Shadow + 3.0f));
    
    half4 BaseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.UV.xy);
    half4 ShadeMap = SAMPLE_TEXTURE2D(_ShadeMap, sampler_ShadeMap, input.UV.xy);
    half4 DefMap = SAMPLE_TEXTURE2D(_DefMap, sampler_DefMap, input.UV.xy).xyzw;
    
    float DefDiffuse = DefMap.x;
    float DefMetallic = DefMap.z;
    float DefSmoothness = DefMap.y;
    float DefSpecular = DefMap.w;

    float DiffuseOffset = DefDiffuse * 2.0f - 1.0f;
    float Smoothness = min(DefSmoothness, 1);
    float Metallic = DefMetallic;
    
    float3 CameraUp = unity_MatrixV[1].xyz;
    float3 ViewSide = normalize(cross(ViewDirection, CameraUp));
    float3 ViewUp = normalize(cross(ViewSide, ViewDirection));
    float3x3 WorldToMatcap = float3x3(ViewSide, ViewUp, ViewDirection);
    float3 NormalMatS = mul(WorldToMatcap, float4(NormalWS, 0.0f));
    
    float4 RampAddMap = 0;
    float3 RampAddColor = 0;
    // #ifdef _RAMPADD_ON
    float2 RampAddMapUV = float2(saturate(DiffuseOffset + NormalMatS.z), VertexColor.RampAddID);
    RampAddMap = SAMPLE_TEXTURE2D(_RampAddMap, sampler_RampAddMap, RampAddMapUV);
    RampAddColor = RampAddMap.xyz * _RampAddColor.xyz;
    
    float3 DiffuseRampAddColor = lerp(RampAddColor, 0, RampAddMap.a);
    BaseMap.xyz += DiffuseRampAddColor;
    ShadeMap.xyz += DiffuseRampAddColor;
    // #endif
    
    float BaseLighting = NoL * 0.5f + 0.5f;
    // BaseLighting = saturate(BaseLighting + (DiffuseOffset - _MatCapParam.x) * 0.5f);
    BaseLighting = saturate(BaseLighting + (DiffuseOffset - 0.025) * 0.5f);
    BaseLighting = min(BaseLighting, Shadow);
    
    float2 RampMapUV = float2(BaseLighting, 0);
    half4 RampMap = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, RampMapUV);
    
    float SpecularIntensity = min(DefSpecular, Shadow);
    const float ShadowIntensity = 0.55; // _MatCapParam.z? _MatCapParam (0,0,0.5490196,0)
    float3 RampedLighting = lerp(BaseMap.xyz, ShadeMap.xyz * _ShadeMultiplyColor, RampMap.w * ShadowIntensity);
    float3 SkinRampedLighting =	lerp(RampMap, RampMap.xyz * _ShadeMultiplyColor, RampMap.w);
    SkinRampedLighting = lerp(1, SkinRampedLighting, ShadowIntensity);
    SkinRampedLighting = BaseMap * SkinRampedLighting;
    RampedLighting = lerp(RampedLighting, SkinRampedLighting, ShadeMap.w);
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

    float3 SH = SampleSH(NormalWS);
    float3 SkyLight = max(SH, 0);
    
    outColor.rgb = brdfData.diffuse;
    outColor.rgb += Specular;
    // outColor.rgb += SkyLight;
    // outColor.rgb += RampMap.w * _ShadeAdditiveColor;
    
    // OutLighting += RimLightColor;
}
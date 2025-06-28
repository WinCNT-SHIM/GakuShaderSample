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
    
    float TextureBias = _GlobalMipBias.x - 1;
    float4 BaseMap = SAMPLE_TEXTURE2D_BIAS(_BaseMap, sampler_BaseMap, input.UV.xy, TextureBias);
    color = BaseMap;

    Light mainLight = GetMainLight();
    float NoL = dot(NormalWS, mainLight.direction);
    // float MatCapNoL = dot(NormalMatS, _MatCapMainLight);
    // bool DisableMatCap = _MatCapMainLight.w > 0.5f;
    // NoL = DisableMatCap ? NoL : MatCapNoL;
	float BaseLighting = NoL * 0.5f + 0.5f;

    color = color * BaseLighting;
    
    outColor = color;
}
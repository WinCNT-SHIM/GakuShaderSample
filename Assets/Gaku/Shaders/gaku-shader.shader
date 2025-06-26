Shader "Gaku/Character/Default"
{
    Properties
    {
		_BaseMap ("Base (RGB)", 2D) = "white" { }
    }
    SubShader
    {
        Pass
        {
            Tags { "RenderType"="Opaque" }
            LOD 100
            
            HLSLPROGRAM
			// make fog work
			#pragma multi_compile_fog
            
            // #pragma vertex vert
            // #pragma fragment frag
            
            ENDHLSL
        }
    }
}

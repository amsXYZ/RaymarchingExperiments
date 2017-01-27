Shader "Hidden/RTArrayDebug"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			UNITY_DECLARE_TEX2DARRAY(_MainTex);
			uniform int _Slice;

			fixed4 frag (v2f_img i) : SV_Target
			{
				return Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_MainTex, float3(i.uv, _Slice)));
			}
			ENDCG
		}
	}
}

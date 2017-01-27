Shader "Custom/BooleanTerrain" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		Cull Back
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows addshadow

		// Sample camera or light booleans volumes
		#pragma multi_compile CAMERA_BOOLEANS LIGHT_BOOLEANS

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		struct Input {
			float2 uv_MainTex;
			float4 screenPos;
			float3 worldPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		UNITY_DECLARE_TEX2DARRAY(_frontFaces);
		UNITY_DECLARE_TEX2DARRAY(_backFaces);
		UNITY_DECLARE_TEX2DARRAY(_frontFacesLight);
		UNITY_DECLARE_TEX2DARRAY(_backFacesLight);

		float PixelDepth(float z)
		{
			return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Clipping
			//float3 rayDir = IN.worldPos - _WorldSpaceCameraPos;
			//float3 camForward = -UNITY_MATRIX_V[2].xyz;

			float z = - mul(UNITY_MATRIX_V, float4(IN.worldPos, 1)).z;

			/*float4 clipPos = mul(UNITY_MATRIX_VP, float4(IN.worldPos, 1));
			float2 uvs = (clipPos.xy / clipPos.w) * 0.5 + 0.5;
			uvs.y = 1 - uvs.y;*/

			float depth = Linear01Depth(PixelDepth(z));
			//float depth = Linear01Depth(PixelDepth(length(rayDir) * dot(normalize(rayDir), camForward)));
			float depthFront, depthBack, maskFront, maskBack;
			UNITY_UNROLL
			for (uint i = 0; i < 4; i++)
			{
				#ifdef CAMERA_BOOLEANS
					depthFront = Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_frontFaces, float3(IN.screenPos.xy / IN.screenPos.w, i)));
					depthBack = Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_backFaces, float3(IN.screenPos.xy / IN.screenPos.w, i)));
				#endif 
				#ifdef LIGHT_BOOLEANS
					depthFront = Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_frontFacesLight, float3(IN.screenPos.xy / IN.screenPos.w, i)));
					depthBack = Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_backFacesLight, float3(IN.screenPos.xy / IN.screenPos.w, i)));
				#endif
				maskFront = depthFront - depth;
				maskBack = depth - depthBack;
				clip(max(maskFront, maskBack));
			}

			// Albedo comes from a texture tinted by color
			fixed4 c = _Color;
			o.Albedo = c.rgb;

			o.Albedo = float3(IN.screenPos.xy / IN.screenPos.w, 0);

			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}

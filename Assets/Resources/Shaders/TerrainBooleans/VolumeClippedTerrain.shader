Shader "Custom/VolumeClippedTerrain" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[HideInInspector]_CameraForward ("Forward", Vector) = (0, 0, 1)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		Cull Off
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float4 screenPos;
			float3 viewDir;
			float3 worldPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		UNITY_DECLARE_TEX2DARRAY(_frontFaces);
		UNITY_DECLARE_TEX2DARRAY(_backFaces);

		float PixelDepth(float z)
		{
			return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Clipping
			float3 rayDir = IN.worldPos - _WorldSpaceCameraPos;
			float3 camForward = -UNITY_MATRIX_V[2].xyz;

			float depth = Linear01Depth(PixelDepth(length(rayDir) * dot(normalize(rayDir), camForward)));
			float depthFront, depthBack, maskFront, maskBack;
			UNITY_UNROLL
			for (uint i = 0; i < 4; i++)
			{
				depthFront = Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_frontFaces, float3(IN.screenPos.xy / IN.screenPos.w, i)));
				depthBack = Linear01Depth(UNITY_SAMPLE_TEX2DARRAY(_backFaces, float3(IN.screenPos.xy / IN.screenPos.w, i)));
				maskFront = depthFront - depth;
				maskBack = depth - depthBack;
				clip(max(maskFront, maskBack));
			}

			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;

			//o.Albedo = camForward;

			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}

Shader "Custom/SurfTest" {
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
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float4 screenPos;
			float3 worldPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		uniform sampler2D _DepthFront_0;
		uniform sampler2D _DepthBack_0;
		uniform sampler2D _DepthFront_1;
		uniform sampler2D _DepthBack_1;
		uniform sampler2D _DepthFront_2;
		uniform sampler2D _DepthBack_2;
		uniform sampler2D _DepthFront_3;
		uniform sampler2D _DepthBack_3;

		uniform float3 _CameraForward;

		float PixelDepth(float z)
		{
			return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Clipping
			float3 rayDir = IN.worldPos - _WorldSpaceCameraPos;

			float depth = Linear01Depth(PixelDepth(length(rayDir) * dot(normalize(rayDir), _CameraForward)));

			// 0
			float depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_0, IN.screenPos.xy / IN.screenPos.w));
			float depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_0, IN.screenPos.xy / IN.screenPos.w));
			float maskFront = depthFront - depth;
			float maskBack = depth - depthBack;
			clip(max(maskFront, maskBack));

			// 1
			depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_1, IN.screenPos.xy / IN.screenPos.w));
			depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_1, IN.screenPos.xy / IN.screenPos.w));
			maskFront = depthFront - depth;
			maskBack = depth - depthBack;
			clip(max(maskFront, maskBack));

			// 2
			depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_2, IN.screenPos.xy / IN.screenPos.w));
			depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_2, IN.screenPos.xy / IN.screenPos.w));
			maskFront = depthFront - depth;
			maskBack = depth - depthBack;
			clip(max(maskFront, maskBack));

			// 3
			depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_3, IN.screenPos.xy / IN.screenPos.w));
			depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_3, IN.screenPos.xy / IN.screenPos.w));
			maskFront = depthFront - depth;
			maskBack = depth - depthBack;
			clip(max(maskFront, maskBack));

			/*float depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront, IN.screenPos.xy / IN.screenPos.w));
			float depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack, IN.screenPos.xy / IN.screenPos.w));

			float maskFront = depthFront - depth;
			float maskBack = depth - depthBack;

			clip(max(maskFront, maskBack));*/

			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Albedo = _CameraForward;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}

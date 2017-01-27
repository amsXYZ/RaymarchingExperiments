Shader "Instanced/BooleanWalls" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_Precision ("Wall Precision", Range(0.001, 0.999)) = 0.9
		_DepthError("Depth Error", Range(0.0, 0.1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		Cull Front
		
		CGPROGRAM
		#pragma surface surf Standard vertex:vert fullforwardshadows addshadow
		#pragma target 3.0
		#pragma multi_compile_instancing

		// Sample camera or light booleans volumes
		#pragma multi_compile CAMERA_BOOLEANS LIGHT_BOOLEANS

		// Config maxcount. See manual page.
		// #pragma instancing_options

		// Terrain boolean uniforms
		#define GRID_RESOLUTION 4097

		// Structs
		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
			float4 screenPos;
		};

		// General uniforms (instance dependant)
		UNITY_INSTANCING_CBUFFER_START(Props)
			UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
			UNITY_DEFINE_INSTANCED_PROP(half, _Glossiness)
			UNITY_DEFINE_INSTANCED_PROP(half, _Metallic)
		UNITY_INSTANCING_CBUFFER_END
		
		uniform sampler2D _MainTex;
		uniform sampler2D _Heightmap;
		uniform float4 _Heightmap_TexelSize;
		uniform float3 _TerrainPosition;
		uniform float3 _TerrainSize;

		uniform float _Precision;
		uniform float _DepthError;

		UNITY_DECLARE_TEX2DARRAY(_frontFaces);
		UNITY_DECLARE_TEX2DARRAY(_backFaces);
		UNITY_DECLARE_TEX2DARRAY(_frontFacesLight);
		UNITY_DECLARE_TEX2DARRAY(_backFacesLight);

		// Functions
		float Terrain(float3 pos) {
			float2 gridUnits = _Heightmap_TexelSize.xy * _Heightmap_TexelSize.zw / GRID_RESOLUTION;

			float2 uv0 = floor((pos.xz - _TerrainPosition.xz) / _TerrainSize.xz * GRID_RESOLUTION) * gridUnits;
			float2 uv1 = uv0 + float2(gridUnits.x, 0);
			float2 uv2 = uv0 + float2(0, gridUnits.y);
			float2 uv3 = uv0 + gridUnits;

			float2 t = fmod((pos.xz - _TerrainPosition.xz) / _TerrainSize.xz * GRID_RESOLUTION, 1);

			// Bilinear interpolation
			/*float h0 = lerp(tex2D(_Heightmap, uv0).x, tex2D(_Heightmap, uv1).x, t.x);
			float h1 = lerp(tex2D(_Heightmap, uv2).x, tex2D(_Heightmap, uv3).x, t.x);

			return pos.y - (lerp(h0, h1, t.y) * _TerrainSize.y + _TerrainPosition.y);*/

			float h0, h1, h2;
			float totalArea = sqrt(0.25);
			float a0, a1, a2;

			// Barycentric interpolation
			UNITY_BRANCH
			if (t.x >= t.y) {
				h0 = tex2D(_Heightmap, uv0).x;
				h1 = tex2D(_Heightmap, uv1).x;
				h2 = tex2D(_Heightmap, uv3).x;

				a0 = ((1 - t.x) / 2) / totalArea;
				a2 = (t.y / 2) / totalArea;
				a1 = 1 - a0 - a2;
			}
			else {
				h0 = tex2D(_Heightmap, uv0).x;
				h1 = tex2D(_Heightmap, uv2).x;
				h2 = tex2D(_Heightmap, uv3).x;

				a0 = ((1 - t.y) / 2) / totalArea;
				a2 = (t.x / 2) / totalArea;
				a1 = 1 - a0 - a2;
			}

			float h = a0 * h0 + a1 * h1 + a2 * h2;

			return pos.y - (h * _TerrainSize.y + _TerrainPosition.y);
		}

		// Dist to Depth
		float PixelDepth(float z)
		{
			return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
		}

		void vert(inout appdata_full v) { v.normal = -v.normal; }

		void surf (Input IN, inout SurfaceOutputStandard o) {

			// Clipping
			float distToTerrain = Terrain(IN.worldPos) + _Precision;
			clip(1 - distToTerrain);

			float z = -mul(UNITY_MATRIX_V, float4(IN.worldPos, 1)).z;

			float depth = Linear01Depth(PixelDepth(z));
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
				maskBack = (depth - depthBack) + 0.000001; // Depth Bias
				clip(max(maskFront, maskBack));
			}

			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * UNITY_ACCESS_INSTANCED_PROP(_Color);
			o.Albedo = c.rgb;

			// Metallic and smoothness come from slider variables
			o.Metallic = UNITY_ACCESS_INSTANCED_PROP(_Metallic);
			o.Smoothness = UNITY_ACCESS_INSTANCED_PROP(_Glossiness);
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}

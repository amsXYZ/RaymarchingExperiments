Shader "Instanced/RaymarchedWalls" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		Cull Front
		ZWrite On
		ZTest LEqual
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		// And generate the shadow pass with instancing support
		#pragma surface surf Standard fullforwardshadows addshadow

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		// Enable instancing for this shader
		#pragma multi_compile_instancing

		// Config maxcount. See manual page.
		// #pragma instancing_options

		#include "Raymarching.cginc"

		// Defines
		// Per-pass to allow better debugging.
		#define GRID_RESOLUTION 4096

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
		};

		half _Glossiness;
		half _Metallic;

		// Declare instanced properties inside a cbuffer.
		// Each instanced property is an array of by default 500(D3D)/128(GL) elements. Since D3D and GL imposes a certain limitation
		// of 64KB and 16KB respectively on the size of a cubffer, the default array size thus allows two matrix arrays in one cbuffer.
		// Use maxcount option on #pragma instancing_options directive to specify array size other than default (divided by 4 when used
		// for GL).
		UNITY_INSTANCING_CBUFFER_START(Props)
			UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)	// Make _Color an instanced property (i.e. an array)
		UNITY_INSTANCING_CBUFFER_END

		uniform sampler2D _Heightmap;
		uniform float4 _Heightmap_TexelSize;
		uniform float3 _TerrainPosition;
		uniform float3 _TerrainSize;

		uniform float4 _BooleanScales;
		uniform float4x4 _BooleanModelMatrices[4];

		
		float Terrain(float3 pos) {
			float2 gridUnits = _Heightmap_TexelSize.xy * _Heightmap_TexelSize.zw / GRID_RESOLUTION;

			float2 uv0 = floor((pos.xz - _TerrainPosition.xz) / _TerrainSize.xz * GRID_RESOLUTION) * gridUnits;
			float2 uv1 = uv0 + float2(gridUnits.x, 0);
			float2 uv2 = uv0 + float2(0, gridUnits.y);
			float2 uv3 = uv0 + gridUnits;

			float2 t = fmod((pos.xz - _TerrainPosition.xz) / _TerrainSize.xz * GRID_RESOLUTION, 1);

			// Bilinear interpolation
			float h0 = lerp(tex2D(_Heightmap, uv0).x, tex2D(_Heightmap, uv1).x, t.x);
			float h1 = lerp(tex2D(_Heightmap, uv2).x, tex2D(_Heightmap, uv3).x, t.x);

			return pos.y - (lerp(h0, h1, t.y) * _TerrainSize.y + _TerrainPosition.y);
		}
		float Map(float3 pos) {
			float terrainDist = Terrain(pos);

			float booleanDist0 = sdBox(mul(_BooleanModelMatrices[0], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.x;
			float booleanDist1 = sdBox(mul(_BooleanModelMatrices[1], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.y;
			float booleanDist2 = sdBox(mul(_BooleanModelMatrices[2], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.z;
			float booleanDist3 = sdBox(mul(_BooleanModelMatrices[3], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.w;

			float dist = opS(booleanDist0, terrainDist);
			dist = opS(booleanDist1, dist);
			dist = opS(booleanDist2, dist);
			dist = opS(booleanDist3, dist);

			return dist;
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			float distToTerrain = Map(IN.worldPos) + 0.999;
			clip(1 - distToTerrain);

			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * UNITY_ACCESS_INSTANCED_PROP(_Color);
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}

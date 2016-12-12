Shader "Hidden/TerrainBoolean"
{
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		// Deferred
		Pass
		{
			Name "BV_DEFERRED"
			Tags{ "Lightmode" = "Deferred" }

			// Shader inner working
			// - Raymarch the volume inside the rasterized mesh.
			// - Reach the surface of the aux mesh.
			// - Raymarch terrain as usual.

			Fog{ Mode Off }
			Lighting Off
			Blend Off
			Cull Front
			ZWrite On
			ZTest LEqual

			Stencil
			{
				Ref 128
				Pass Replace
			}

			CGPROGRAM
			#include "MeshAssistedRaymarching.cginc"

			#pragma vertex vert_MAR
			#pragma fragment frag
			#pragma multi_compile_instancing

			// Defines
			// Per-pass to allow better debugging.
			#define MAX_STEPS 32
			#define MAX_STEPS_TERRAIN 128
			#define MAX_STEPS_TERRAIN_HIGH 512
			#define MAX_GRID_RESOLUTION 513

			// Uniforms
			uniform float _Scale;
			uniform float _Color;
			uniform sampler2D _Heightmap;
			uniform float4 _Heightmap_TexelSize;
			uniform float _TerrainWidth;
			uniform float _TerrainHeight;
			uniform float _HeightSlider;
			uniform sampler2D _CameraDepthTexture;

			// Functions
			inline const float Terrain(float3 pos) {
				float2 uv0 = floor(pos.xz / 1000 * MAX_GRID_RESOLUTION) / MAX_GRID_RESOLUTION;
				float2 uv1 = uv0 + float2((1 - PRECISION) / MAX_GRID_RESOLUTION, 0);
				float2 uv2 = uv0 + float2(0, (1 - PRECISION) / MAX_GRID_RESOLUTION);
				float2 uv3 = uv0 + float2((1 - PRECISION) / MAX_GRID_RESOLUTION, (1 - PRECISION) / MAX_GRID_RESOLUTION);

				float tx = fmod(pos.x / 1000 * MAX_GRID_RESOLUTION, 1);
				float tz = fmod(pos.z / 1000 * MAX_GRID_RESOLUTION, 1);

				float h0 = lerp(tex2D(_Heightmap, uv0).x, tex2D(_Heightmap, uv1).x, tx);
				float h1 = lerp(tex2D(_Heightmap, uv2).x, tex2D(_Heightmap, uv3).x, tx);

				return pos.y - lerp(h0, h1, tz) * 208;
			}
			inline const float Map(float3 pos) {
				float terrainDist = Terrain(pos);
				// Sphere
				float booleanDist = sdSphere(mul(unity_WorldToObject, float4(pos, 1)), 0.5) * _Scale;
				// Cylinder
				//float booleanDist = sdCylinder(mul(unity_WorldToObject, float4(pos, 1)), float3(0, 0, 0.5)) * _Scale;

				return opS(booleanDist, terrainDist);
			}
			
			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection) {
				RayHit hit;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;

				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS_TERRAIN_HIGH; i++) {
					half3 p = rayOrigin + rayDirection * distanceFromOrigin;

					half dist = Map(p);

					UNITY_BRANCH
					if (dist < PRECISION * distanceFromOrigin) {
						hit.id = 0;
						break;
					}
					UNITY_BRANCH
					if (distanceFromOrigin > maxDist || p.x > 1000 || p.z > 1000 || p.x < 0 || p.z < 0) {
						hit.id = -1; //Skybox
						break;
					}

					distanceFromOrigin += 0.35 * dist;
					hit.dist = distanceFromOrigin;
				}

				return hit;
			}
			
			// TODO: Cast ray to sphere first and then raymarch terrain + boolean.
			/*
			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection) {
				RayHit hit;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;

				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS; i++) {
					half3 p = rayOrigin + rayDirection * distanceFromOrigin;

					half dist = Map(p);

					UNITY_BRANCH
					if (dist < PRECISION) {
						hit.dist = distanceFromOrigin;
						CastRayTerrain(p, rayDirection, hit);
						break;
					}
					UNITY_BRANCH
					if (dist > maxDist) {
						hit.dist = distanceFromOrigin;
						hit.id = -1; //Skybox
						break;
					}

					distanceFromOrigin += dist;
					hit.dist = distanceFromOrigin;
				}

				return hit;
			}*/

			inline const float3 CalcNormal(float3 pos)
			{
				float3 eps = float3(PRECISION, 0.0, 0.0);
				float3 norm = float3(
					Map(pos + eps.xyy) - Map(pos - eps.xyy),
					Map(pos + eps.yxy) - Map(pos - eps.yxy),
					Map(pos + eps.yyx) - Map(pos - eps.yyx));
				return normalize(norm);
			}

			inline const void frag(v2f_MAR i, out half4 outDiffuse        : SV_Target0,
							out half4 outSpecSmoothness : SV_Target1,
							out half4 outNormal : SV_Target2,
							out half4 outEmission : SV_Target3,
							out float outDepth : SV_Depth)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				RayHit rayHit = CastRay(_WorldSpaceCameraPos, i.rayDir);
				float dist = rayHit.dist;
				float id = rayHit.id;

				UNITY_BRANCH
				if (id < 0) {
					outDiffuse = 0;
					outSpecSmoothness = 0;
					outNormal = 0;
					outEmission = 0;

					outDepth = 0;
				}
				else {
					float3 pos = _WorldSpaceCameraPos + i.rayDir * dist;

					//outDiffuse = _Color;
					//outDiffuse = 0.78; // White
					UNITY_BRANCH
					if(fmod(pos.x / 1000 * MAX_GRID_RESOLUTION, 1) < 0.05 || fmod(pos.z / 1000 * MAX_GRID_RESOLUTION, 1) < 0.05) outDiffuse = float4(0.12, 0.36, 0.78, 1) + 0.2;
					else outDiffuse = float4(0.12, 0.36, 0.78, 1);
					outSpecSmoothness = 0.22;
					outNormal = float4(CalcNormal(pos) * 0.5 + 0.5, 1);
					outEmission = 1 - float4(unity_AmbientSky.rgb, 1);

					// TODO: Clip foreground pixels
					outDepth = PixelDepth(dist);
				}
			}

			ENDCG
		}

		// Clear GBuffer
		Pass
		{
			Name "BV_GCLEAR"
			Tags{ "Lightmode" = "Deferred" }

			Fog{ Mode Off }
			Lighting Off
			Blend Off
			Cull Front
			ZWrite On
			ZTest Always

			Stencil
			{
				Ref 128
				Pass Replace
			}

			CGPROGRAM
			#include "MeshAssistedRaymarching.cginc"

			#pragma vertex vert_MAR
			#pragma fragment frag
			#pragma multi_compile_instancing

			#define MAX_STEPS 32
			
			uniform float _Scale;

			inline const float Map(float3 pos) {
				return sdSphere(mul(unity_WorldToObject, float4(pos,1)), 0.5) * _Scale;
			}
			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection) {
			RayHit hit;

			float minDist = _ProjectionParams.y;
			float maxDist = _ProjectionParams.z;
			float distanceFromOrigin = minDist;

			UNITY_LOOP
			for (int i = 0; i < MAX_STEPS; i++) {
				half3 p = rayOrigin + rayDirection * distanceFromOrigin;

				half dist = Map(p);

				UNITY_BRANCH
				if (dist < PRECISION) {
					hit.dist = distanceFromOrigin;
					hit.id = 0;
					break;
				}
				UNITY_BRANCH
				if (dist > maxDist) {
					hit.dist = distanceFromOrigin;
					hit.id = -1; //Skybox
					break;
				}

				distanceFromOrigin += dist;
				hit.dist = distanceFromOrigin;
			}

			return hit;
		}

			inline const void frag(v2f_MAR i, out half4 outDiffuse        : SV_Target0,
							out half4 outSpecSmoothness : SV_Target1,
							out half4 outNormal : SV_Target2,
							out half4 outEmission : SV_Target3,
							out float outDepth : SV_Depth)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				float dist = CastRay(_WorldSpaceCameraPos, i.rayDir).dist;

				outDiffuse = 0;
				outSpecSmoothness = 0;
				outNormal = 0;
				outEmission = 0;

				//outDepth = PixelDepth(dist);
				outDepth = 0;
			}

			ENDCG
		}
	}
	Fallback Off
}
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
			#define MAX_STEPS_TERRAIN 128
			#define TERRAIN_STEP_PRECISION 0.35
			#define GRID_RESOLUTION 256

			// Uniforms
			uniform float _Scale;
			uniform float _Color;
			uniform sampler2D _Heightmap;
			uniform float4 _Heightmap_TexelSize;
			uniform float3 _TerrainPosition;
			uniform float3 _TerrainSize;

			// Functions
			inline const float Terrain(float3 pos) {
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
			inline const float Map(float3 pos, bool shell) {
				UNITY_BRANCH
				if(shell) return sdSphere(mul(unity_WorldToObject, float4(pos, 1)), 0.5) * _Scale;
				else {
					float terrainDist = Terrain(pos);
					float booleanDist = sdSphere(mul(unity_WorldToObject, float4(pos, 1)), 0.5) * _Scale;

					return opS(booleanDist, terrainDist);
				}
			}
			
			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection) {
				RayHit hit;
				bool shell = true;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;

				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS_TERRAIN; i++) {
					half3 p = rayOrigin + rayDirection * distanceFromOrigin;

					// TODO: Clear the parts of the boolean op we don't want to see (foreground//background objects)
					half dist = Map(p, shell); 
					//half dist = Map(p, false);

					UNITY_BRANCH
					if (dist < PRECISION * distanceFromOrigin) {
						UNITY_BRANCH
						if (shell) shell = false; // Once you've reached the shell boolean, continue marching the terrain
						else {
							hit.id = 0;
							break;
						}
					}
					UNITY_BRANCH
					if (distanceFromOrigin > maxDist || p.x > 1000 || p.z > 1000 || p.x < 0 || p.z < 0) {
						hit.id = -1; //Skybox
						break;
					}

					UNITY_BRANCH
					if(shell) distanceFromOrigin += dist;
					else distanceFromOrigin += TERRAIN_STEP_PRECISION * dist;

					hit.dist = distanceFromOrigin;
				}
				return hit;
			}

			// TODO: CalcNormalSmooth
			inline const float3 CalcNormal(float3 pos)
			{
				float3 eps = float3(PRECISION, 0.0, 0.0);
				float3 norm = float3(
					Map(pos + eps.xyy, false) - Map(pos - eps.xyy, false),
					Map(pos + eps.yxy, false) - Map(pos - eps.yxy, false),
					Map(pos + eps.yyx, false) - Map(pos - eps.yyx, false));
				return normalize(norm);
			}

			inline const void frag(v2f_MAR i, out half4 outDiffuse        : SV_Target0,
							out half4 outSpecSmoothness : SV_Target1,
							out half4 outNormal : SV_Target2,
							out half4 outEmission : SV_Target3,
							out float outDepth : SV_Depth)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				float3 rayDir = normalize(i.worldPos - _WorldSpaceCameraPos);

				RayHit rayHit = CastRay(_WorldSpaceCameraPos, rayDir);
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
					float3 pos = _WorldSpaceCameraPos + rayDir * dist;

					//outDiffuse = _Color;
					//outDiffuse = 0.78; // White
					UNITY_BRANCH
					if( fmod((pos.x - _TerrainPosition.x) / _TerrainSize.x * GRID_RESOLUTION, 1) < 0.05 
					|| fmod((pos.z - _TerrainPosition.z) / _TerrainSize.z * GRID_RESOLUTION, 1) < 0.05
					|| fmod((pos.z - _TerrainPosition.z) / _TerrainSize.z * GRID_RESOLUTION, 1) - fmod((pos.x - _TerrainPosition.x) / _TerrainSize.x * GRID_RESOLUTION, 1) < 0.05 
						&& fmod((pos.x - _TerrainPosition.x) / _TerrainSize.x * GRID_RESOLUTION, 1) - fmod((pos.z - _TerrainPosition.z) / _TerrainSize.z * GRID_RESOLUTION, 1) < 0.05)
						outDiffuse = float4(0.12, 0.36, 0.78, 1) + 0.2;
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

				float3 rayDir = normalize(i.worldPos - _WorldSpaceCameraPos);

				float dist = CastRay(_WorldSpaceCameraPos, rayDir).dist;

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
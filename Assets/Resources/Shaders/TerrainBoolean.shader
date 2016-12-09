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
			// - Raymarch terrain as Usual.

			Fog{ Mode Off }
			Lighting Off
			Blend Off
			Cull Back
			ZWrite On
			//ZTest GEqual // Substractive
			ZTest LEqual // Standard

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

			// Raymarching max step count.
			// Defined per-shader to allow better debugging.
			#define MAX_STEPS 32
			#define MAX_STEPS_TERRAIN 128

			// Uniforms
			float _Scale;
			float _Color;
			sampler2D _Heightmap;
			float _TerrainWidth;
			float _TerrainHeight;

			// Functions
			inline const float Map(float3 pos) {
				return sdSphere(mul(unity_WorldToObject, float4(pos,1)), 0.5) * _Scale;
			}
			inline const float MapTerrain(float3 pos) {
				float terrain = pos.y - tex2D(_Heightmap, pos.xz / _TerrainWidth) * _TerrainHeight;
				float boolean = sdSphere(mul(unity_WorldToObject, float4(pos, 1)), 0.5) * _Scale;

				return opS(terrain, boolean);
			}

			// TODO: Try raymarching just normal terrain first and writting all the values to the GBuffer, and then do this.

			inline const void CastRayTerrain(float3 rayOrigin, float3 rayDirection, out RayHit ray) {
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = 0;

				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS; i++) {
					half3 p = rayOrigin + rayDirection * distanceFromOrigin;

					half dist = MapTerrain(p);

					UNITY_BRANCH
					if (dist < PRECISION) {
						ray.dist += distanceFromOrigin;
						ray.id = 0;
						break;
					}
					UNITY_BRANCH
					if (dist > maxDist) {
						ray.dist += distanceFromOrigin;
						ray.id = -1; //Skybox
						break;
					}

					distanceFromOrigin += dist;
					ray.dist += distanceFromOrigin;
				}
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
			}
			

			inline const float3 CalcNormal(float3 pos)
			{
				float3 eps = float3(PRECISION, 0.0, 0.0);
				float3 norm = float3(
					Map(pos + eps.xyy) - Map(pos - eps.xyy),
					Map(pos + eps.yxy) - Map(pos - eps.yxy),
					Map(pos + eps.yyx) - Map(pos - eps.yyx));
				return normalize(norm);
			}
			inline const float3 CalcNormalTerrain(float3 pos)
			{
				float3 eps = float3(PRECISION, 0.0, 0.0);
				float3 norm = float3(
					MapTerrain(pos + eps.xyy) - MapTerrain(pos - eps.xyy),
					MapTerrain(pos + eps.yxy) - MapTerrain(pos - eps.yxy),
					MapTerrain(pos + eps.yyx) - MapTerrain(pos - eps.yyx));
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
					//outDiffuse = _Color;
					outDiffuse = 0.78;
					outSpecSmoothness = 0.22;
					outNormal = float4(CalcNormalTerrain(_WorldSpaceCameraPos + i.rayDir * dist) * 0.5 + 0.5, 1);
					outEmission = 1 - float4(unity_AmbientSky.rgb, 1);

					outDepth = PixelDepth(dist);
				}
			}

			ENDCG
		}
	}
	Fallback Off
}
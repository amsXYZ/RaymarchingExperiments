Shader "Hidden/BooleanVolume"
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
			// - Go through the volume until you find the back face.
			// - Write the back face depth, albedo and more using ZTest GEqual.

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

			// Uniforms
			float _Scale;
			float _Color;

			// Functions
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

				// Output the distance to the backface of the sphere (Radius = 0.5, Diameter = 1)
				// The problem with this is that you cannot create see trhough booleans.
				// Maybe to do a per-object raymarching aproach would be a better solution?
				// TODO: Modify this diameter based on the scale of the sphere.
				// Hack: Only true if it goes through the center
				//return distanceFromOrigin + 1;
				
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

			inline const void frag(v2f_MAR i, out half4 outDiffuse        : SV_Target0,
							out half4 outSpecSmoothness : SV_Target1,
							out half4 outNormal : SV_Target2,
							out half4 outEmission : SV_Target3,
							out float outDepth : SV_Depth)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				float dist = CastRay(_WorldSpaceCameraPos, i.rayDir).dist;

				//outDiffuse = _Color;
				outDiffuse = 0.78;
				outSpecSmoothness = 0.22;
				// Invert the normals as they're supposed to be the internal normals.
				outNormal = float4(CalcNormal(_WorldSpaceCameraPos + i.rayDir * dist) * 0.5 + 0.5, 1);
				outEmission = 1 - float4(unity_AmbientSky.rgb, 1);

				outDepth = PixelDepth(dist);
			}

			ENDCG
		}
	}
	Fallback Off
}
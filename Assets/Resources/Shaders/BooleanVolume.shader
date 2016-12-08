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
			ZTest GEqual

			Stencil
			{
				Ref 128
				Pass Replace
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// Enable instancing
			#pragma multi_compile_instancing
			
			#include "UnityCG.cginc"
			#include "Raymarching.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			cbuffer sdf_Ray {
				half3 sdf_Corner;
				half3 sdf_Right;
				half3 sdf_Up;
			};

			

			v2f vert (appdata v)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}


			inline const half3 Ray(const half2 uv)
			{
				return sdf_Corner + (sdf_Right * uv.x) + (sdf_Up * uv.y);
			}
			inline const float PixelDepth(const float z)
			{
				return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
			}
			inline float CastRay(float3 rayOrigin, float3 rayDirection) {
				int maxSteps = 32;
				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;

				UNITY_LOOP
				for (int i = 0; i < maxSteps; i++) {
					half3 p = rayOrigin + rayDirection * distanceFromOrigin;
					half dist = sdSphere(mul(unity_WorldToObject, float4(p,1)), 1);

					UNITY_BRANCH
					if (dist < 0.001) { break; }
					// Max dist case

					distanceFromOrigin += dist;
				}

				// Output the distance to the backface of the sphere (Radius = 1, Diameter = 2)
				// The problem with this is that you cannot create see trhough booleans.
				// Maybe to do a per-object raymarching aproach would be a better solution?
				// TODO: Modify this diameter based on the scale of the sphere.
				// Hack: Only true if it goes through the center
				return distanceFromOrigin + 2;
			}
			float3 CalcNormal(float3 pos)
			{
				float3 eps = float3(0.001, 0.0, 0.0);
				float3 norm = float3(
					sdSphere(mul(unity_WorldToObject, float4(pos + eps.xyy, 1)), 1) - sdSphere(mul(unity_WorldToObject, float4(pos - eps.xyy, 1)), 1),
					sdSphere(mul(unity_WorldToObject, float4(pos + eps.yxy, 1)), 1) - sdSphere(mul(unity_WorldToObject, float4(pos - eps.yxy, 1)), 1),
					sdSphere(mul(unity_WorldToObject, float4(pos + eps.yyx, 1)), 1) - sdSphere(mul(unity_WorldToObject, float4(pos - eps.yyx, 1)), 1));
				return normalize(norm);
			}

			void frag(v2f i, out half4 outDiffuse        : SV_Target0,
							out half4 outSpecSmoothness : SV_Target1,
							out half4 outNormal : SV_Target2,
							out half4 outEmission : SV_Target3,
							out float outDepth : SV_Depth)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				half3 ray = Ray(i.vertex.xy / _ScreenParams.xy);
				float dist = CastRay(_WorldSpaceCameraPos, ray);

				//outDiffuse = float4(ray, 1);
				outDiffuse = 0.78;

				outSpecSmoothness = 0.22;

				// Invert the normals as they're supposed to be the internal normals.
				outNormal = float4(-CalcNormal(_WorldSpaceCameraPos + ray * dist) * 0.5 + 0.5, 1);

				// Bug: SV_Target3 outputs the skybox too? What?
				outEmission = 1 - float4(unity_AmbientSky.rgb, 1);

				// TODO: Figure out why the depth is not being correctly output
				outDepth = PixelDepth(dist);
			}

			ENDCG
		}
	}
}

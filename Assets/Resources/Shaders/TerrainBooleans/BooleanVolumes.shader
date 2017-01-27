Shader "Hidden/BooleanVolumes"
{
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		// Mask front part of the boolean
		// Use a volumetric approach to clip objects properly.
		Pass
		{
			Name "TB_MASK_FRONT"

			Fog{ Mode Off }
			Lighting Off
			Blend Off
			Cull Front
			ZWrite On
			ZTest LEqual

			CGPROGRAM
			#include "MeshAssistedRaymarching.cginc"

			#pragma vertex vert_MAR
			#pragma geometry geo_MAR
			#pragma fragment frag
			#pragma multi_compile_instancing

			// Shader variants for the different primitives
			/*#pragma multi_compile BOOL_0_NULL BOOL_0_BOX BOOL_0_SPHERE BOOL_0_CYLINDER BOOL_0_CAPSULE
			#pragma multi_compile BOOL_1_NULL BOOL_1_BOX BOOL_1_SPHERE BOOL_1_CYLINDER BOOL_1_CAPSULE
			#pragma multi_compile BOOL_2_NULL BOOL_2_BOX BOOL_2_SPHERE BOOL_2_CYLINDER BOOL_2_CAPSULE
			#pragma multi_compile BOOL_3_NULL BOOL_3_BOX BOOL_3_SPHERE BOOL_3_CYLINDER BOOL_3_CAPSULE
			#pragma multi_compile BOOL_4_NULL BOOL_4_BOX BOOL_4_SPHERE BOOL_4_CYLINDER BOOL_4_CAPSULE
			#pragma multi_compile BOOL_5_NULL BOOL_5_BOX BOOL_5_SPHERE BOOL_5_CYLINDER BOOL_5_CAPSULE
			#pragma multi_compile BOOL_6_NULL BOOL_6_BOX BOOL_6_SPHERE BOOL_6_CYLINDER BOOL_6_CAPSULE
			#pragma multi_compile BOOL_7_NULL BOOL_7_BOX BOOL_7_SPHERE BOOL_7_CYLINDER BOOL_7_CAPSULE
			#pragma multi_compile BOOL_8_NULL BOOL_8_BOX BOOL_8_SPHERE BOOL_8_CYLINDER BOOL_8_CAPSULE
			#pragma multi_compile BOOL_9_NULL BOOL_9_BOX BOOL_9_SPHERE BOOL_9_CYLINDER BOOL_9_CAPSULE
			#pragma multi_compile BOOL_10_NULL BOOL_10_BOX BOOL_10_SPHERE BOOL_10_CYLINDER BOOL_10_CAPSULE
			#pragma multi_compile BOOL_11_NULL BOOL_11_BOX BOOL_11_SPHERE BOOL_11_CYLINDER BOOL_11_CAPSULE
			#pragma multi_compile BOOL_12_NULL BOOL_12_BOX BOOL_12_SPHERE BOOL_12_CYLINDER BOOL_12_CAPSULE
			#pragma multi_compile BOOL_13_NULL BOOL_13_BOX BOOL_13_SPHERE BOOL_13_CYLINDER BOOL_13_CAPSULE
			#pragma multi_compile BOOL_14_NULL BOOL_14_BOX BOOL_14_SPHERE BOOL_14_CYLINDER BOOL_14_CAPSULE
			#pragma multi_compile BOOL_15_NULL BOOL_15_BOX BOOL_15_SPHERE BOOL_15_CYLINDER BOOL_15_CAPSULE*/

			// Shader variants based on the number of booleans per-terrain
			#pragma multi_compile BOOL_COUNT_LOW BOOL_COUNT_MID BOOL_COUNT_HIGH

			// Defines
			#define MAX_STEPS 32
			#define INFINITE 999999999

			// Uniforms
			uniform float _MeshScale;
			uniform float3 _MeshScaleInternal;

			#ifdef BOOL_COUNT_LOW
			uniform float4x4 _BooleanModelMatrices[4];
			uniform float3 _BooleanScales[4];
			#elif BOOL_COUNT_MID
			uniform float4x4 _BooleanModelMatrices[8];
			uniform float3 _BooleanScales[8];
			#elif BOOL_COUNT_HIGH
			uniform float4x4 _BooleanModelMatrices[16];
			uniform float3 _BooleanScales[16];
			#endif

			inline const float Map(float3 pos, uint id) {
				return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
				//return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
				//return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2)); // Dist to ellipse: https://www.shadertoy.com/view/4sS3zz
				//return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);

				/*UNITY_BRANCH
				switch (id)
				{
				case 0:
#ifdef BOOL_0_NULL 
					return INFINITE;
#endif
#ifdef BOOL_0_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_0_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_0_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_0_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 1:
#ifdef BOOL_1_NULL 
					return INFINITE;
#endif
#ifdef BOOL_1_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_1_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_1_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_1_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 2:
#ifdef BOOL_2_NULL 
					return INFINITE;
#endif
#ifdef BOOL_2_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_2_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_2_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_2_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 3:
#ifdef BOOL_3_NULL 
					return INFINITE;
#endif
#ifdef BOOL_3_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_3_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_3_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_3_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 4:
#ifdef BOOL_4_NULL 
					return INFINITE;
#endif
#ifdef BOOL_4_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_4_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_4_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_4_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 5:
#ifdef BOOL_5_NULL 
					return INFINITE;
#endif
#ifdef BOOL_5_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_5_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_5_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_5_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 6:
#ifdef BOOL_6_NULL 
					return INFINITE;
#endif
#ifdef BOOL_6_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_6_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_6_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_6_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 7:
#ifdef BOOL_7_NULL 
					return INFINITE;
#endif
#ifdef BOOL_7_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_7_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_7_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_7_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 8:
#ifdef BOOL_8_NULL 
					return INFINITE;
#endif
#ifdef BOOL_8_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_8_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_8_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_8_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 9:
#ifdef BOOL_9_NULL 
					return INFINITE;
#endif
#ifdef BOOL_9_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_9_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_9_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_9_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 10:
#ifdef BOOL_10_NULL 
					return INFINITE;
#endif
#ifdef BOOL_10_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_10_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_10_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_10_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 11:
#ifdef BOOL_11_NULL 
					return INFINITE;
#endif
#ifdef BOOL_11_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_11_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_11_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_11_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 12:
#ifdef BOOL_12_NULL 
					return INFINITE;
#endif
#ifdef BOOL_12_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_12_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_12_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_12_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 13:
#ifdef BOOL_13_NULL 
					return INFINITE;
#endif
#ifdef BOOL_13_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_13_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_13_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_13_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 14:
#ifdef BOOL_14_NULL 
					return INFINITE;
#endif
#ifdef BOOL_14_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_14_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_14_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_14_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
					break;
				case 15:
#ifdef BOOL_15_NULL 
					return INFINITE;
#endif
#ifdef BOOL_15_BOX 
					return sdBox(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_15_SPHERE 
					return sdEllipsoid(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id]);
#endif
#ifdef BOOL_15_CYLINDER 
					return sdCappedCylinder(mul(_BooleanModelMatrices[id], float4(pos, 1)), _BooleanScales[id] * float2(1, 2));
#endif
#ifdef BOOL_15_CAPSULE 
					return sdCapsule(mul(_BooleanModelMatrices[id], float4(pos, 15)), _BooleanScales[id]);
#endif
					break;
				}*/
			}
			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection, uint id) {
				RayHit hit;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;
				half3 p;

				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS; i++) {
					p = rayOrigin + rayDirection * distanceFromOrigin;

					half distToSurface = Map(p, id);

					UNITY_BRANCH
					if (distToSurface < PRECISION) {
						hit.id = 0;
						break;
					}

					distanceFromOrigin += distToSurface;
				}

				hit.dist = distanceFromOrigin;
				return hit;
			}

			inline const void frag(g2f_MAR i, out float outDepth : SV_Depth)
			{
				float3 rayDir = normalize(i.worldPos - _WorldSpaceCameraPos);
				RayHit rayHit = CastRay(_WorldSpaceCameraPos, rayDir, i.id);

				float3 camForward = -UNITY_MATRIX_V[2].xyz;

				// Reproject dist to the Z axis.
				float dist = rayHit.dist * dot(rayDir, camForward);

				outDepth = PixelDepth(dist);
			}
			ENDCG
		}

		// Mask back part of the boolean
		Pass
		{
			Name "TB_MASK_BACK"

			Fog{ Mode Off }
			Lighting Off
			Blend Off
			Cull Front
			ZWrite On
			ZTest LEqual

			CGPROGRAM
			#include "MeshAssistedRaymarching.cginc"

			#pragma vertex vert_MAR
			#pragma geometry geo_MAR
			#pragma fragment frag
			#pragma multi_compile_instancing

			inline const void frag(g2f_MAR i) {}
			ENDCG
		}

		Pass
		{
			Name "TB_MASK_FRONT_LIGHT"

			Fog{ Mode Off }
			Lighting Off
			Blend Off
			Cull Back
			ZWrite On
			ZTest LEqual

			CGPROGRAM
			#include "MeshAssistedRaymarching.cginc"

			#pragma vertex vert_MAR
			#pragma geometry geo_MAR
			#pragma fragment frag
			#pragma multi_compile_instancing

			inline const void frag(g2f_MAR i) {}
			ENDCG
		}
	}
	Fallback Off
}

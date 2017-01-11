Shader "Hidden/TerrainBoolean"
{
	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue" = "Geometry+1" }
		LOD 100

		// Deferred
		Pass
		{
			Name "BV_DEFERRED"
			Tags{ "Lightmode" = "Deferred" }

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
			#include "UnityPBSLighting.cginc"

			#pragma vertex vert_MAR
			#pragma fragment frag
			#pragma multi_compile_instancing
			// TODO: Shader variants for both windows and macos.
			//#pragma target 4.6

			// Defines
			// Per-pass to allow better debugging.
			#define MAX_STEPS_TERRAIN 256
			#define TERRAIN_STEP_PRECISION 0.5
			#define GRID_RESOLUTION 4096

			// Uniforms
			uniform sampler2D _Heightmap;
			uniform float4 _Heightmap_TexelSize;
			uniform float3 _TerrainPosition;
			uniform float3 _TerrainSize;

			uniform float4 _BooleanScales;
			uniform float4x4 _BooleanModelMatrices[4];
			uniform float _MeshScale;
			uniform float3 _MeshScaleInternal;

			uniform sampler2D _DepthFront_0;
			uniform sampler2D _DepthBack_0;
			uniform sampler2D _DepthFront_1;
			uniform sampler2D _DepthBack_1;
			uniform sampler2D _DepthFront_2;
			uniform sampler2D _DepthBack_2;
			uniform sampler2D _DepthFront_3;
			uniform sampler2D _DepthBack_3;

			uniform float3 _CameraForward;

			// Functions
			// TODO: Offset the terrain surface to fill the holes.
			inline const float Terrain(float3 pos) {
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
			inline const float Map(float3 pos) {
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

			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection) {
				RayHit hit;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;
				half3 p;

				// March to terrain
				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS_TERRAIN; i++) {
					p = rayOrigin + rayDirection * distanceFromOrigin;

					half distToSurface = Map(p);

					UNITY_BRANCH
					if (distToSurface < PRECISION * distanceFromOrigin) {
						hit.id = 0;
						break;
					} else if (distanceFromOrigin > maxDist || 
						p.x <= 0 || p.z <= 0 ||
						p.x >= _TerrainPosition.x + _TerrainSize.x ||
						p.z >= _TerrainPosition.z + _TerrainSize.z) {
						hit.id = -1; //Skybox
						break;
					}

					distanceFromOrigin += TERRAIN_STEP_PRECISION * distToSurface;
				}

				// Output final distance
				hit.dist = distanceFromOrigin;
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

				float3 rayDir = normalize(i.worldPos - _WorldSpaceCameraPos);
				RayHit rayHit = CastRay(_WorldSpaceCameraPos, rayDir);
				float id = rayHit.id;
				float dist = rayHit.dist;

				float depth = Linear01Depth(PixelDepth(dist * dot(rayDir, _CameraForward)));

				// 0
				float depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_0, i.vertex.xy / _ScreenParams.xy));
				float depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_0, i.vertex.xy / _ScreenParams.xy));
				float maskFront = depth - depthFront;
				float maskBack = depthBack - depth;
				float clipFactor = min(maskFront, maskBack);

				// 1
				depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_1, i.vertex.xy / _ScreenParams.xy));
				depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_1, i.vertex.xy / _ScreenParams.xy));
				maskFront = depth - depthFront;
				maskBack = depthBack - depth;
				clipFactor = max(min(maskFront, maskBack), clipFactor);

				// 2
				depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_2, i.vertex.xy / _ScreenParams.xy));
				depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_2, i.vertex.xy / _ScreenParams.xy));
				maskFront = depth - depthFront;
				maskBack = depthBack - depth;
				clipFactor = max(min(maskFront, maskBack), clipFactor);

				// 3
				depthFront = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthFront_3, i.vertex.xy / _ScreenParams.xy));
				depthBack = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_DepthBack_3, i.vertex.xy / _ScreenParams.xy));
				maskFront = depth - depthFront;
				maskBack = depthBack - depth;
				clipFactor = max(min(maskFront, maskBack), clipFactor);

				clip(clipFactor);

				UNITY_BRANCH
				if (id < 0 ) {
					clip(-1);
				}
				else {
					float3 pos = _WorldSpaceCameraPos + rayDir * dist;

					//outDiffuse = float4(0.78, 0.36, 0.12, 1);
					outDiffuse = float4(0.78, 0.78, 0.78, 1);
					outSpecSmoothness = 0.22;
					outNormal = float4(CalcNormal(pos) * 0.5 + 0.5, 1);
					// Super Hacky hack to get the ambient right
					outEmission = float4(1.19235, 1.25823, 1.34031, 1) - float4(max(0, ShadeSH9(float4(outNormal.xyz, 1))), 0);

					outDepth = PixelDepth(dist * dot(rayDir, _CameraForward));
				}
			}

			ENDCG
		}

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
			#pragma fragment frag
			#pragma multi_compile_instancing

			// Defines
			#define MAX_STEPS 32

			// Uniforms
			uniform float _MeshScale;
			uniform float3 _MeshScaleInternal;
			uniform float3 _CameraForward;

			uniform float4 _BooleanScales;
			uniform float4x4 _BooleanModelMatrices[4];

			inline const float Map(float3 pos) { 
				return sdBox(mul(unity_WorldToObject, float4(pos, 1)), _MeshScaleInternal * float3(1, _MeshScaleInternal.x / _MeshScaleInternal.y, _MeshScaleInternal.x / _MeshScaleInternal.z)) * _MeshScale; 
			
				/*float booleanDist0 = sdBox(mul(_BooleanModelMatrices[0], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.x;
				float booleanDist1 = sdBox(mul(_BooleanModelMatrices[1], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.y;
				float booleanDist2 = sdBox(mul(_BooleanModelMatrices[2], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.z;
				float booleanDist3 = sdBox(mul(_BooleanModelMatrices[3], float4(pos, 1)), float3(0.5, 0.5, 0.5)) * _BooleanScales.w;

				float dist = opU(booleanDist0, booleanDist1);
				dist = opU(booleanDist2, dist);
				dist = opU(booleanDist3, dist);

				return dist;*/
			}
			inline const RayHit CastRay(float3 rayOrigin, float3 rayDirection) {
				RayHit hit;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float distanceFromOrigin = minDist;
				half3 p;

				// March to shell
				UNITY_LOOP
				for (int i = 0; i < MAX_STEPS; i++) {
					p = rayOrigin + rayDirection * distanceFromOrigin;

					half distToSurface = Map(p);

					UNITY_BRANCH
					if (distToSurface < PRECISION) {
						hit.id = 0;
						break;
					}

					distanceFromOrigin += distToSurface;
				}

				// Output final distance
				hit.dist = distanceFromOrigin;
				return hit;
			}

			inline const void frag(v2f_MAR i, out float outDepth : SV_Depth)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				float3 rayDir = normalize(i.worldPos - _WorldSpaceCameraPos);
				RayHit rayHit = CastRay(_WorldSpaceCameraPos, rayDir);

				// Reproject dist to the Z axis.
				float angle = acos(dot(rayDir, _CameraForward));
				float dist = rayHit.dist * cos(angle);

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
			#pragma fragment frag
			#pragma multi_compile_instancing

			inline const void frag(v2f_MAR i, out half4 outDiffuse : SV_Target)
			{
				UNITY_SETUP_INSTANCE_ID(i);

				outDiffuse = 1;
			}
			ENDCG
		}
	}
	Fallback Off
}

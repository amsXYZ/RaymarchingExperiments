Shader "Hidden/DistanceFieldsRaymarcher"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			// Things that I need for a proper raymarcher:
			// GENERAL PURPOSE
			// - Distance Primitives
			// - Distance Operations
			// - Domain Operations
			// - Distance Deformations
			// - Domanin Deformations

			// PER SCENE
			// - Map function (when using a mapping function with 2 values, the second value is the color... Or at least in here: https://www.shadertoy.com/view/Xds3zN)
			// - CastRay function
			// - Aux Functions (lighting models, shadows, AO, normals, render...)

			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "Raymarching.cginc"
			
			sampler2D _MainTex;
			half4 _MainTex_TexelSize;
			uniform half3 f;
			uniform half3 r;
			uniform half3 u;
			uniform half _VFOV;
			uniform half _OrtSize;
			uniform half _Precision;

			// Skybox information
			samplerCUBE _SkyCubemap;
			half4 _SkyCubemap_HDR;
			half4 _SkyTint;
			half _SkyExposure;
			float _SkyRotation;

			float opRepSpheresTest(float3 p, float3 c)
			{
				float3 q = fmod(p, c) - 0.5*c;

				float dist = opBlend(q, sdTorus(p, float2(0.75 * cos(_Time.w * 2), 1)), sdSphere(q + float3(1 + sin(_Time.w), 0, 0), 1.0));
				dist = opBlend(q, dist, sdSphere(q + float3(-1 - sin(_Time.w), 0, 0), 1.0));
				dist = opBlend(q, dist, sdSphere(q + float3(0, 0, 1 + sin(_Time.w)), 1.0));
				dist = opBlend(q, dist, sdSphere(q + float3(0, 0, -1 - sin(_Time.w)), 1.0));

				//float dist = sdSphere(q, 1.0);

				return dist;
			}

			// Map Function: Outputs the distance to the closest primitive in the scene.
			float Map(float3 pos) {
				/*float dist = opBlend(pos, sdBox(pos, float3(1,1,1)), sdSphere(pos + float3(2, 0, 0), 1.0));
				dist = opBlend(pos, dist, sdSphere(pos + float3(-2, 0, 0), 1.0));
				dist = opBlend(pos, dist, sdSphere(pos + float3(0, 0, 2), 1.0));
				dist = opBlend(pos, dist, sdSphere(pos + float3(0, 0, -2), 1.0));*/


				/*float dist = opBlend(pos, sdTorus(pos, float2(0.75 * cos(_Time.w * 2), 1)), sdSphere(pos + float3(1 + sin(_Time.w), 0, 0), 1.0));
				dist = opBlend(pos, dist, sdSphere(pos + float3(-1 - sin(_Time.w), 0, 0), 1.0));
				dist = opBlend(pos, dist, sdSphere(pos + float3(0, 0, 1 + sin(_Time.w)), 1.0));
				dist = opBlend(pos, dist, sdSphere(pos + float3(0, 0, -1 - sin(_Time.w)), 1.0));*/

				float dist = opRepSpheresTest(pos, float3(5, 5, 5));

				/*float dist = opS(sdSphere(pos + float3(3 + sin(_Time.w) * 2, 0, 0), 3 * cos(_Time.w)), udRoundBox(pos, float3(2, 2, 2), 0.5));
				dist = opS(sdSphere(pos + float3( -3 - sin(_Time.w) * 2, 0, 0), 3 * cos(_Time.w)), dist);
				dist = opS(sdSphere(pos + float3(0, 0, 3 + sin(_Time.w) * 2), 3 * cos(_Time.w)), dist);
				dist = opS(sdSphere(pos + float3(0, 0, -3 - sin(_Time.w) * 2), 3 * cos(_Time.w)), dist);
				dist = opU(dist, sdSphere(pos + float3(3 + sin(_Time.w) * 2, 0, 0), cos(_Time.w)));
				dist = opU(dist, sdSphere(pos + float3(-3 - sin(_Time.w) * 2, 0, 0), cos(_Time.w)));
				dist = opU(dist, sdSphere(pos + float3(0, 0, 3 + sin(_Time.w) * 2), cos(_Time.w)));
				dist = opU(dist, sdSphere(pos + float3(0, 0, -3 - sin(_Time.w) * 2), cos(_Time.w)));*/
				//dist = opU(dist, sdPlane(pos + float3(0, 3, 0), float4(0,1,0,0)));

				return dist;
			}

			// CastRay Function: Returns the point of intersection with a primitive.
			float2 CastRay(float3 rayOrigin, float3 rayDirection) {
				int maxSteps = 32;
				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float color = 0;

				float distanceFromOrigin = minDist;
				UNITY_LOOP
				for (int i = 0; i < maxSteps; i++) {
					half3 p = rayOrigin + rayDirection * distanceFromOrigin;
					half dist = Map(p);

					UNITY_BRANCH
					if (dist < _Precision) { color = 1; break; }
					UNITY_BRANCH
					if (distanceFromOrigin > maxDist) break;
					
					/*UNITY_BRANCH
					if (dist < _Precision || distanceFromOrigin > maxDist) break;*/

					distanceFromOrigin += dist;
				}

				// step count debug
				//return float2(distanceFromOrigin, distanceFromOrigin/maxDist);

				return float2(distanceFromOrigin, color);
				
				//return distanceFromOrigin;
			}

			//float TerrainHeight(float2 p) { return snoise(p.xy, 0.075, 2, 0.5, 1, 1, 0, 10); }

			// CalcNormal Function: Outputs the gradient (axis of higher variation in a distance fields, which corresponds with the normal) of a point.
			float3 CalcNormal(float3 pos)
			{
				float3 eps = float3(0.001, 0.0, 0.0);
				float3 norm = float3(
					Map(pos + eps.xyy) - Map(pos - eps.xyy),
					Map(pos + eps.yxy) - Map(pos - eps.yxy),
					Map(pos + eps.yyx) - Map(pos - eps.yyx));
				return normalize(norm);
			}

			// CalcOcclusion Function: 
			float CalcOcclusion(float3 pos, float3 norm) {

				//return norm;

				float occ = 0.0;
				float occInfluence = 1.0;
				for (int i = 0; i<5; i++)
				{
					float occDist = 0.01 + 0.12*float(i) / 4.0;
					float3 aopos = pos + norm * occDist;
					float dist = Map(aopos);
					occ += -(dist - occDist)*occInfluence;
					occInfluence *= 0.95;
				}
				return saturate(1.0 - 3.0*occ);
			}

			float Softshadow(float3 rayOrigin, float3 rayDirection, float k)
			{
				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float res = 1.0;

				for (float t = minDist; t < maxDist; )
				{
					float h = Map(rayOrigin + rayDirection*t);
					if (h<0.001)
						return 0.0;
					res = min(res, k*h / t);
					t += h;
				}

				return res;
			}

			float4 Render(float3 rayOrigin, float3 rayDirection, float4 bgColor) {
				float2 dist = CastRay(rayOrigin, rayDirection);

				UNITY_BRANCH
				if (dist.y == 0) return bgColor;

				float3 pos = rayOrigin + dist.x * rayDirection;
				float3 norm = CalcNormal(pos);
				float3 ref = reflect(rayDirection, norm);
				float3 light = _WorldSpaceLightPos0;

				//Lighting
				float4 ambient = float4(DecodeHDR(texCUBE(_SkyCubemap, ref), _SkyCubemap_HDR), 1);
				float4 diffuse = _LightColor0 * dot(norm, light);
				float specular = pow(saturate(dot(ref, light)), 32.0);
				float fresnel = pow(saturate(1.0 + dot(norm, rayDirection)), 4.0);
				float occlusion = CalcOcclusion(pos, norm);
				//float shadow = Softshadow(pos, light, 32);

				return ambient + diffuse * occlusion + fresnel * ambient * occlusion + specular;
				//return ambient + diffuse * occlusion * shadow + fresnel * ambient * occlusion * shadow + specular;
			}

			fixed4 frag (v2f_img i) : SV_Target
			{
				half4 screenColor = tex2D(_MainTex, i.uv);

				half3 cameraRight = half3(UNITY_MATRIX_V[0][0], UNITY_MATRIX_V[1][0], UNITY_MATRIX_V[2][0]); 
				half3 cameraUp = half3(UNITY_MATRIX_V[0][1], UNITY_MATRIX_V[1][1], UNITY_MATRIX_V[2][1]);
				half3 cameraForward = half3(UNITY_MATRIX_V[0][2], UNITY_MATRIX_V[1][2], UNITY_MATRIX_V[2][2]);

				// Overriding as it seems that the V matrix doesnt update properly...?
				cameraRight = r;
				cameraUp = u;
				cameraForward = f;

				half2 screenCoordinates = ((i.uv * 2) - 1) * half2(_ScreenParams.x/_ScreenParams.y, 1);

				#if UNITY_UV_STARTS_AT_TOP
					UNITY_BRANCH
					if(_MainTex_TexelSize.y < 0) screenCoordinates.y = -screenCoordinates.y;
				#endif

				// Same here as with the V Matrix, I'm not able to get the FOV values from the P matrix...
				//half fovV = tan(UNITY_MATRIX_P[1][1]);

				half screenHeight = tan(radians(_VFOV/2)) * _ProjectionParams.y;

				// Orthogonal (change dir to forward too)
				//half screenHeight = _OrtSize/2;

				half3 rayOrigin = _WorldSpaceCameraPos + _ProjectionParams.y * cameraForward + screenHeight * screenCoordinates.x * cameraRight + screenHeight * screenCoordinates.y * cameraUp;
				half3 rayDirection = normalize(rayOrigin - _WorldSpaceCameraPos);

				half3 rayOrigin1 = _WorldSpaceCameraPos + _ProjectionParams.y * cameraForward + screenHeight * (screenCoordinates.x + _MainTex_TexelSize.x * 0.75) * cameraRight + screenHeight * (screenCoordinates.y + _MainTex_TexelSize.y * 0.75) * cameraUp;
				half3 rayDirection1 = normalize(rayOrigin1 - _WorldSpaceCameraPos);
				half3 rayOrigin2 = _WorldSpaceCameraPos + _ProjectionParams.y * cameraForward + screenHeight * (screenCoordinates.x - _MainTex_TexelSize.x * 0.75) * cameraRight + screenHeight * (screenCoordinates.y - _MainTex_TexelSize.y * 0.75) * cameraUp;
				half3 rayDirection2 = normalize(rayOrigin2 - _WorldSpaceCameraPos);
				half3 rayOrigin3 = _WorldSpaceCameraPos + _ProjectionParams.y * cameraForward + screenHeight * (screenCoordinates.x + _MainTex_TexelSize.x * 0.75) * cameraRight + screenHeight * (screenCoordinates.y - _MainTex_TexelSize.y * 0.75) * cameraUp;
				half3 rayDirection3 = normalize(rayOrigin3 - _WorldSpaceCameraPos);
				half3 rayOrigin4 = _WorldSpaceCameraPos + _ProjectionParams.y * cameraForward + screenHeight * (screenCoordinates.x - _MainTex_TexelSize.x * 0.75) * cameraRight + screenHeight * (screenCoordinates.y + _MainTex_TexelSize.y * 0.75) * cameraUp;
				half3 rayDirection4 = normalize(rayOrigin4 - _WorldSpaceCameraPos);

				// Anti-Aliasing
				return (Render(rayOrigin1, rayDirection1, screenColor) + Render(rayOrigin2, rayDirection2, screenColor) + Render(rayOrigin3, rayDirection3, screenColor) + Render(rayOrigin4, rayDirection4, screenColor)) / 4;

				// Aliased version
				//return Render(rayOrigin, rayDirection, screenColor);

				return screenColor;
			}

			ENDCG
		}
	}
}

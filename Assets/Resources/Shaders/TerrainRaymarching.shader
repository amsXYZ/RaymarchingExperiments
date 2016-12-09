Shader "Hidden/TerrainRaymarching"
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
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			
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

			// Terrain info
			uniform float _Frequency;
			uniform float _Lacunarity;
			uniform float _Persistence;
			uniform int _Octaves;
			uniform float _Billowy;
			uniform float _Inverse;
			uniform float _Intensity;

			// Noise texture
			uniform sampler2D _WhiteNoise;
			uniform float4 _WhiteNoise_TexelSize;

			// Detail texture
			uniform sampler2D _DetailNoise;
			uniform float4 _DetailNoise_TexelSize;
			uniform float _DetailFrequency;

			uniform sampler2D _CameraDepthTexture;

			uniform float _ShadowSharpness;

			uniform float4 _BottomColor;
			uniform float4 _TopColor;
			uniform float4 _YColor;

			// Terrain octaves = 4 - 8
			// Noise octaves = 16
			// Shadow octaves = 2

			// Checklist
			// - Texture-based noise: DONE
			// - Noise derivatives: DONE
			// - Terrain Noise (Low/Medium/High): DONE
			// - Detail Noise (Medium/High): Needs rework
			// - CastRayTerrain (Terrain Interpolation)
			// - CalcNormals: DONE
			// - Shadows: DONE
			// - FBM (for texturing)
			// - Rendering

			// Noise and its derivatives
			float3 Noise(float2 pos) {
				float2 p = floor(pos);
				float2 f = frac(pos);
				// Cubic smooth function
				//float2 u = f * f * (3.0 - 2.0 * f);
				// Quintic smooth function
				float2 u = f * f * f * (6.0 * f * f - 15.0 * f + 10);

				float a = tex2Dlod(_WhiteNoise, float4((p + float2(0.5, 0.5)) / _WhiteNoise_TexelSize.z, 0, -1)).x;
				float b = tex2Dlod(_WhiteNoise, float4((p + float2(1.5, 0.5)) / _WhiteNoise_TexelSize.z, 0, -1)).x;
				float c = tex2Dlod(_WhiteNoise, float4((p + float2(0.5, 1.5)) / _WhiteNoise_TexelSize.z, 0, -1)).x;
				float d = tex2Dlod(_WhiteNoise, float4((p + float2(1.5, 1.5)) / _WhiteNoise_TexelSize.z, 0, -1)).x;

				float n = a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
				
				// Cubic derivatives
				//float2 der = 6 * f * (1 - f) * (float2(b - a, c - a) + (a - b - c + d) * u.yx);
				// Quintic derivatives
				float2 der = f * f * (30 * f * f - 60.0 * f + 30) * (float2(b - a, c - a) + (a - b - c + d) * u.yx);
				
				return float3(n, der);
			}

			// Detail noise functions
			float DetailMedium(float2 pos) {
				return 50 * tex2Dlod(_DetailNoise, float4(pos * _DetailFrequency * 0.03, 0, 0)).x;
			}
			float DetailHigh(float2 pos) {
				return /*DetailMedium(pos) +*/ 0.5 * tex2Dlod(_DetailNoise, float4(pos * _DetailFrequency * 2, 0, 0)).x;
			}

			// Terrain functions
			float Terrain(float2 pos, int octaves) {
				float freq = 0.003 * _Frequency;
				float2 p = pos * freq /* + float2(_Time.y, 0)*/;
				float noise = 0;
				float amplitude = 1;
				float2 derivatives = float2(0, 0);

				for (int i = 0; i< octaves; i++)
				{
					float3 n = Noise(p);
					derivatives += n.yz;
					noise += amplitude * n.x / (1.0 + dot(derivatives, derivatives));
					UNITY_BRANCH
					if(i < 2) noise *= saturate(pow(abs(pos.y - 2000) / 800, 0.8));
					amplitude *= _Persistence;
					p = _Lacunarity * float2(0.8 * p.x - 0.6 * p.y, 0.6 * p.x + 0.8 * p.y);
				}

				//float de = DetailHigh(pos);
				//return _Intensity * noise - de;
				return _Intensity * noise;
			}

			float2 CastRayTerrain(float3 rayOrigin, float3 rayDirection) {
				int maxSteps = 512;
				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;
				float color = 0;

				float dt;
				float t;
				float lastRayHeight = rayOrigin.y;
				float lastTerrainHeight = rayOrigin.y;

				float distanceFromOrigin = minDist;
				UNITY_LOOP
				for (int i = 0; i < maxSteps; i++) {
					half3 pos = rayOrigin + rayDirection * distanceFromOrigin;
					int oct = round(lerp(8, 2, saturate(distanceFromOrigin / _ProjectionParams.z * 8)));
					float height = pos.y - Terrain(pos.xz, oct);

					// Terrain Interpolation?

					/*UNITY_BRANCH
					if (height < _Precision * distanceFromOrigin) { color = oct; dt = 0.5 * height; t = (lastRayHeight - lastTerrainHeight) / (pos.y - lastRayHeight - lastTerrainHeight + height - pos.y); break; }
					UNITY_BRANCH
					if (distanceFromOrigin > maxDist) { color = oct; dt = 0.5 * height; t = (lastRayHeight - lastTerrainHeight) / (lastRayHeight - lastTerrainHeight + height - pos.y); break; }
					*/

					UNITY_BRANCH
					if (height < _Precision * distanceFromOrigin || distanceFromOrigin > maxDist) { color = oct; break; }

					distanceFromOrigin += 0.5 * height;

					lastRayHeight = pos.y;
					lastTerrainHeight = height;
				}

				// Last distance + lerp(0, dt, errora/errorb)
				// lastDistance = distanceFromOigin
				// dt = 0.5 * height;

				return float2(distanceFromOrigin, color);
			}

			float3 CalcNormalTerrain(in float3 pos, float t)
			{
				float2  eps = float2(0.002*t, 0.0);
				int oct = round(lerp(16, 2, saturate(t / _ProjectionParams.z * 8)));

				return normalize(float3(Terrain(pos.xz - eps.xy, oct) - Terrain(pos.xz + eps.xy, oct),
					2.0*eps.x,
					Terrain(pos.xz - eps.yx, oct) - Terrain(pos.xz + eps.yx, oct)));
			}

			float Softshadow(float3 rayOrigin, float3 rayDirection, float k)
			{
				int maxShadowSteps = 54;

				float minDist = _ProjectionParams.y;
				float maxDist = _ProjectionParams.z;

				float res = 1.0;
				float dist = 0.001;

				for (int i = 0; i<maxShadowSteps; i++)
				{
					float3 p = rayOrigin + dist * rayDirection;
					float h = p.y - Terrain(p.xz, 2);
					res = min(res, k * h / dist);
					dist += h;

					// Review max shadow distance
					if ( res < 0.001 || p.y > (_Intensity * 200.0)) break;
				}

				return saturate(res);
			}

			float4 RenderTerrain(float3 rayOrigin, float3 rayDirection, float4 bgColor, float2 uv) {
				float2 dist = CastRayTerrain(rayOrigin, rayDirection);

				float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
				d = Linear01Depth(d);

				UNITY_BRANCH
				if (dist.y == 0 || dist.x / _ProjectionParams.z > d) return bgColor;
				// Debug noise octaves
				//else return dist.y / 8;

				float3 pos = rayOrigin + dist.x * rayDirection;
				float3 norm = CalcNormalTerrain(pos, dist.x);
				float3 ref = reflect(rayDirection, norm);
				float3 light = _WorldSpaceLightPos0;

				//Lighting
				float4 ambient = 0.3 * saturate(0.5 + 0.5 * norm.y) * float4(0.96,0.86,0.74, 1) /* * float4(DecodeHDR(texCUBE(_SkyCubemap, ref), _SkyCubemap_HDR), 1)*/;
				float shadow = Softshadow(pos, light, _ShadowSharpness);
				float4 diffuse = saturate(_LightColor0 * lerp(lerp(_BottomColor, _TopColor, saturate(pos.y / 600 - 0.3)), _YColor, pow(norm.y, 64)) * dot(norm, light) * shadow);
				float specular = pow(saturate(dot(ref, light)), 8.0);
				float fresnel = pow(saturate(1.0 + dot(norm, rayDirection)), 4.0);

				float4 col = diffuse + specular * 0.06675 + fresnel * ambient * 0.3 + ambient;

				// Sun dot
				float sundot = saturate(dot(rayDirection,light));
				//return sundot;

				// fog
			    float fo = saturate(log(dist.x / _ProjectionParams.z) + 2) + (1 - saturate((pos.y + 200) / 600)) * 2;
			    float4 fogColor = float4( 0.75 * float3(0.42,0.39,0.43) + 0.3 * float3(0.96,0.86,0.74) * pow( sundot, 4.0 ), 1 );
				col = lerp( col, fogColor, fo );

			    // sun scatter
				col += float4(0.3 * float3(0.96,0.86,0.74)  * pow( sundot, 8.0 ) * fo,0);
				return col;

				//return fresnel;
				//return float4(norm, 1);
			}

			// The near cliping camera changes creates a resolution artifact
			fixed4 frag (v2f_img i) : SV_Target
			{
				fixed4 screenColor = tex2D(_MainTex, i.uv);

				//half3 cameraRight = half3(UNITY_MATRIX_V[0][0], UNITY_MATRIX_V[1][0], UNITY_MATRIX_V[2][0]); 
				//half3 cameraUp = half3(UNITY_MATRIX_V[0][1], UNITY_MATRIX_V[1][1], UNITY_MATRIX_V[2][1]);
				//half3 cameraForward = half3(UNITY_MATRIX_V[0][2], UNITY_MATRIX_V[1][2], UNITY_MATRIX_V[2][2]);

				// Overriding as it seems that the V matrix doesnt update properly...?
				fixed3 cameraRight = r;
				fixed3 cameraUp = u;
				fixed3 cameraForward = f;

				fixed2 screenCoordinates = ((i.uv * 2) - 1) * fixed2(_ScreenParams.x/_ScreenParams.y, 1);

				#if UNITY_UV_STARTS_AT_TOP
					UNITY_BRANCH
					if(_MainTex_TexelSize.y < 0) screenCoordinates.y = -screenCoordinates.y;
				#endif

				// Same here as with the V Matrix, I'm not able to get the FOV values from the P matrix...
				//half fovV = tan(UNITY_MATRIX_P[1][1]);

				fixed screenHeight = tan(radians(_VFOV/2)) * _ProjectionParams.y;

				fixed3 rayOrigin = _WorldSpaceCameraPos + _ProjectionParams.y * cameraForward + screenHeight * screenCoordinates.x * cameraRight + screenHeight * screenCoordinates.y * cameraUp;
				fixed3 rayDirection = normalize(rayOrigin - _WorldSpaceCameraPos);

				// Terrain
				return RenderTerrain(rayOrigin, rayDirection, screenColor, i.uv);
			}

			ENDCG
		}
	}
}


#ifndef MESHASSISTEDRAYMARCHING_CG_INCLUDED
#define MESHASSISTEDRAYMARCHING_CG_INCLUDED

	// Includes
	#include "UnityCG.cginc"
	#include "Raymarching.cginc"

	// Constants
	#define PRECISION 0.001

	// Data structures
	struct appdata_MAR
	{
		float4 vertex : POSITION;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};
	struct v2f_MAR
	{
		float4 vertex : SV_POSITION;
		float3 rayDir : NORMAL;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};
	struct RayHit {
		float dist;
		int id;
	};

	// Vertex Shader Function
	inline const v2f_MAR vert_MAR(appdata_MAR v)
	{
		v2f_MAR o;

		UNITY_SETUP_INSTANCE_ID(v);
		UNITY_TRANSFER_INSTANCE_ID(v, o);

		o.vertex = UnityObjectToClipPos(v.vertex);
		o.rayDir = normalize(mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos);
		return o;
	}

	// Auxiliary Functions
	inline const float PixelDepth(const float z)
	{
		return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
	}

#endif // MESHASSISTEDRAYMARCHING_CG_INCLUDED

#ifndef MESHASSISTEDRAYMARCHING_CG_INCLUDED
#define MESHASSISTEDRAYMARCHING_CG_INCLUDED

	// Includes
	#include "UnityCG.cginc"
	#include "../Raymarching.cginc"

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
		float4 worldPos : COLOR0;
		uint id : TEXCOORD0;
	};
	struct v2g_MAR
	{
		float4 vertex : SV_POSITION;
		float4 worldPos : COLOR0;
		uint id : TEXCOORD0;
	};
	struct g2f_MAR {
		float4 vertex : SV_POSITION;
		float4 worldPos : COLOR0;
		uint slice : SV_RenderTargetArrayIndex;
		uint id : TEXCOORD0;
	};
	struct RayHit {
		float dist;
		int id;
	};

	float4x4 IMV;

	// Vertex Shader Function
	inline const v2f_MAR vert_MAR(appdata_MAR v)
	{
		v2f_MAR o;

		UNITY_SETUP_INSTANCE_ID(v);
		//UNITY_TRANSFER_INSTANCE_ID(v, o);

		o.vertex = UnityObjectToClipPos(v.vertex);
		o.worldPos = mul(unity_ObjectToWorld, v.vertex);

		#if defined(INSTANCING_ON)
		o.id = v.instanceID;
		#else
		o.id = 0;
		#endif

		return o;
	}

	inline const v2g_MAR vert_MARG(appdata_MAR v)
	{
		v2g_MAR o;

		UNITY_SETUP_INSTANCE_ID(v);
		//UNITY_TRANSFER_INSTANCE_ID(v, o);

		o.vertex = UnityObjectToClipPos(v.vertex);
		o.worldPos = mul(unity_ObjectToWorld, v.vertex);

		#if defined(INSTANCING_ON)
		o.id = v.instanceID;
		#else
		o.id = 0;
		#endif

		return o;
	}

	[maxvertexcount(3)]
	void geo_MAR(triangle v2g_MAR input[3], inout TriangleStream<g2f_MAR> output)
	{
		v2g_MAR i;
		g2f_MAR o;

		UNITY_UNROLL
		for (uint j = 0; j < 3; j++)
		{
			i = input[j];

			o.vertex = i.vertex;
			o.worldPos = i.worldPos;
			o.slice = i.id;
			o.id = i.id;

			output.Append(o);
		}
	}

	// Auxiliary Functions
	inline const float PixelDepth(const float z)
	{
		return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
	}

#endif // MESHASSISTEDRAYMARCHING_CG_INCLUDED
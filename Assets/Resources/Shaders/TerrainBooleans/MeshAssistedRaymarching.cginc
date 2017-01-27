
#ifndef MESHASSISTEDRAYMARCHING_CG_INCLUDED
#define MESHASSISTEDRAYMARCHING_CG_INCLUDED

	// Includes
	#include "UnityCG.cginc"

	// Constants
	#define PRECISION 0.001

	// Data structures
	struct appdata_MAR
	{
		float4 vertex : POSITION;
		UNITY_VERTEX_INPUT_INSTANCE_ID
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

	// Vertex Shader Function
	inline const v2g_MAR vert_MAR(appdata_MAR v)
	{
		v2g_MAR o;

		UNITY_SETUP_INSTANCE_ID(v);

		o.vertex = UnityObjectToClipPos(v.vertex);
		o.worldPos = mul(unity_ObjectToWorld, v.vertex);

		#if defined(INSTANCING_ON)
		o.id = v.instanceID;
		#else
		o.id = 0;
		#endif

		return o;
	}

	// Geometry Shader Function
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

	// Dist to depth
	inline const float PixelDepth(const float z)
	{
		return (1.0 - (z * _ZBufferParams.w)) / (z * _ZBufferParams.z);
	}

	// Raymarching primitives
	float sdBox(float3 p, float3 b){
		float3 d = abs(p) - b;
		return min(max(d.x, max(d.y, d.z)),0) + length(max(d,0.0));
	}
	float sdEllipsoid(in float3 p, in float3 r)
	{
		return (length(p / r) - 1.0) * min(min(r.x, r.y), r.z);
	}
	float sdCappedCylinder(float3 p, float2 h)
	{
		float2 d = abs(float2(length(p.xz), p.y)) - h;
		return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
	}
	float sdCapsule(float3 p, float3 s)
	{
		float dET = sdEllipsoid(p + float3(0, s.y, 0), s);
		float dEB = sdEllipsoid(p - float3(0, s.y, 0), s);
		float dC = sdCappedCylinder(p, s);
		return min(dET, min(dEB, dC));
	}

#endif // MESHASSISTEDRAYMARCHING_CG_INCLUDED
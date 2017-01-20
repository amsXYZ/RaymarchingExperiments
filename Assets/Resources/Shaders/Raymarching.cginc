
#ifndef RAYMARCHING_CG_INCLUDED
#define RAYMARCHING_CG_INCLUDED

	// Credits to Iñigo Quilez for this, and many more awesome articles, about SDFs: http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
	
	// Primitives
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

#endif // RAYMARCHING_CG_INCLUDED
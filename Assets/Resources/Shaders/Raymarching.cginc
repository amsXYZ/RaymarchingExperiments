
#ifndef RAYMARCHING_CG_INCLUDED
#define RAYMARCHING_CG_INCLUDED

	// All the functions here belong to this article by Inigo Quilex: http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm

	// Primitives

	// Sphere - signed - exact
	float sdSphere (float3 p, float s){
		return length(p)-s;
	}
	// Box - unsigned - exact
	float udBox(float3 p, float3 b){
		return length(max(abs(p)-b, 0.0));
	}
	// Round Box - unsigned - exact
	float udRoundBox(float3 p, float3 b, float r){
		return length(max(abs(p)-b,0.0))-r;
	}
	// Box - signed - exact
	float sdBox(float3 p, float3 b){
		float3 d = abs(p) - b;
		return min(max(d.x, max(d.y, d.z)),0) + length(max(d,0.0));
	}
	// Torus - signed - exact
	float sdTorus(float3 p, float2 t){
		float2 q = float2(length(p.xz)-t.x,p.y);
		return length(q)-t.y;
	}
	// Cylinder - signed - exact
	float sdCylinder(float3 p, float3 c){
		return length(p.xz-c.xy)-c.z;
	}
	// Cone - signed - exact
	float sdCone(float3 p, float2 c)
	{
		// c must be normalized
		float q = length(p.xy);
		return dot(c, float2(q, p.z));
	}
	// Plane - signed - exact
	float sdPlane(float3 p, float4 n)
	{
		// n must be normalized
		return dot(p, n.xyz) + n.w;
	}
	// Hexagonal Prism - signed - exact
	float sdHexPrism(float3 p, float2 h)
	{
		float3 q = abs(p);
		return max(q.z - h.y, max((q.x*0.866025 + q.y*0.5), q.y) - h.x);
	}
	// Triangular Prism - signed - exact
	float sdTriPrism(float3 p, float2 h)
	{
		float3 q = abs(p);
		return max(q.z - h.y, max(q.x*0.866025 + p.y*0.5, -p.y) - h.x*0.5);
	}
	// Capsule / Line - signed - exact
	float sdCapsule(float3 p, float3 a, float3 b, float r)
	{
		float3 pa = p - a, ba = b - a;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		return length(pa - ba*h) - r;
	}
	// Capped cylinder - signed - exact
	float sdCappedCylinder(float3 p, float2 h)
	{
		float2 d = abs(float2(length(p.xz), p.y)) - h;
		return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
	}
	// Capped Cone - signed - bound
	float sdCappedCone(in float3 p, in float3 c)
	{
		float2 q = float2(length(p.xz), p.y);
		float2 v = float2(c.z*c.y / c.x, -c.z);
		float2 w = v - q;
		float2 vv = float2(dot(v, v), v.x*v.x);
		float2 qv = float2(dot(v, w), v.x*w.x);
		float2 d = max(qv, 0.0)*qv / vv;
		return sqrt(dot(w, w) - max(d.x, d.y)) * sign(max(q.y*v.x - q.x*v.y, w.y));
	}
	// Ellipsoid - signed - bound
	float sdEllipsoid(in float3 p, in float3 r)
	{
		return (length(p / r) - 1.0) * min(min(r.x, r.y), r.z);
	}
	// Auxiliary function used in Tris/Quads distance functions
	float dot2(in float3 v) { return dot(v, v); }
	// Triangle - unsigned - exact
	float udTriangle(float3 p, float3 a, float3 b, float3 c)
	{
		float3 ba = b - a; float3 pa = p - a;
		float3 cb = c - b; float3 pb = p - b;
		float3 ac = a - c; float3 pc = p - c;
		float3 nor = cross(ba, ac);

		return sqrt(
			(sign(dot(cross(ba, nor), pa)) +
				sign(dot(cross(cb, nor), pb)) +
				sign(dot(cross(ac, nor), pc))<2.0)
			?
			min(min(
				dot2(ba*clamp(dot(ba, pa) / dot2(ba), 0.0, 1.0) - pa),
				dot2(cb*clamp(dot(cb, pb) / dot2(cb), 0.0, 1.0) - pb)),
				dot2(ac*clamp(dot(ac, pc) / dot2(ac), 0.0, 1.0) - pc))
			:
			dot(nor, pa)*dot(nor, pa) / dot2(nor));
	}
	// Quad - unsigned - exact
	float udQuad(float3 p, float3 a, float3 b, float3 c, float3 d)
	{
		float3 ba = b - a; float3 pa = p - a;
		float3 cb = c - b; float3 pb = p - b;
		float3 dc = d - c; float3 pc = p - c;
		float3 ad = a - d; float3 pd = p - d;
		float3 nor = cross(ba, ad);

		return sqrt(
			(sign(dot(cross(ba, nor), pa)) +
				sign(dot(cross(cb, nor), pb)) +
				sign(dot(cross(dc, nor), pc)) +
				sign(dot(cross(ad, nor), pd))<3.0)
			?
			min(min(min(
				dot2(ba*clamp(dot(ba, pa) / dot2(ba), 0.0, 1.0) - pa),
				dot2(cb*clamp(dot(cb, pb) / dot2(cb), 0.0, 1.0) - pb)),
				dot2(dc*clamp(dot(dc, pc) / dot2(dc), 0.0, 1.0) - pc)),
				dot2(ad*clamp(dot(ad, pd) / dot2(ad), 0.0, 1.0) - pd))
			:
			dot(nor, pa)*dot(nor, pa) / dot2(nor));
	}
	// Modifications of the length function to achieve non-euclidean geometries
	float length2(float2 p)
	{
		return sqrt(p.x*p.x + p.y*p.y);
	}
	float length6(float2 p)
	{
		p = p*p*p; p = p*p;
		return pow(p.x + p.y, 1.0 / 6.0);
	}
	float length8(float2 p)
	{
		p = p*p; p = p*p; p = p*p;
		return pow(p.x + p.y, 1.0 / 8.0);
	}
	// Torus82 - signed
	float sdTorus82(float3 p, float2 t)
	{
		float2 q = float2(length2(p.xz) - t.x, p.y);
		return length8(q) - t.y;
	}
	// Torus88 - signed
	float sdTorus88(float3 p, float2 t)
	{
		float2 q = float2(length8(p.xz) - t.x, p.y);
		return length8(q) - t.y;
	}

	// Distance Operations

	// Union
	float opU(float d1, float d2)
	{
		return min(d1, d2);
	}
	//Substraction
	float opS(float d1, float d2)
	{
		return max(-d1, d2);
	}
	// Intersection
	float opI(float d1, float d2)
	{
		return max(d1, d2);
	}

	// Domain Operations (Sphere)
	// TODO: Add support for different primitives' domain operations.

	// Repetition
	float opRep(float3 p, float3 c)
	{
		float3 q = fmod(p, c) - 0.5*c;
		return sdSphere(q, 1.0);
	}
	// Rotation / Translation
	float3 opTx(float3 p, float4x4 m)
	{
		//float3 q = mul(invert(m), p); CG/HLSL doesnt support invert function. Thats why I expect that the matrix is already inverted.
		float3 q = mul(m, float4(p,1));
		return sdSphere(q, 1.0);
	}
	// Scale
	float opScale(float3 p, float s)
	{
		return sdSphere(p / s, 1.0)*s;
	}

	// Take into account that distance and domain deformations do not preserve distances, so you must decrease your step. More info: http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm

	// Distance Deformations
	
	// TODO: Implement more displacement functions
	float displacement(float3 p) {
		return sin(20 * p.x) * sin(20 * p.y) * sin(20 * p.z);
	}
	// Displacement. Modified version of the one by iQuilez than can be used with any distance primitive.
	float opDisplace(float3 p, float d1)
	{
		//float d1 = primitive(p, 1.0);
		float d2 = displacement(p);
		return d1 + d2;
	}
	// Polynomial smooth min (k = 0.1). Exponential and Power approaches here: http://www.iquilezles.org/www/articles/smin/smin.htm
	float smin(float a, float b)
	{
		float k = 0.1;
		float h = clamp(0.5 + 0.5*(b - a) / k, 0.0, 1.0);
		return lerp(b, a, h) - k*h*(1.0 - h);
	}
	// Blend. 
	float opBlend(float3 p, float d1, float d2)
	{
		//float d1 = primitiveA(p);
		//float d2 = primitiveB(p);
		return smin(d1, d2);
	}

	// Domain Deformations (Sphere)

	// Twist
	float opTwist(float3 p)
	{
		float c = cos(20.0*p.y);
		float s = sin(20.0*p.y);
		float2x2  m = float2x2(c, -s, s, c);
		float3  q = float3(mul(m,p.xz), p.y);
		return sdSphere(q, 1.0);
	}
	// Cheap Bend
	float opCheapBend(float3 p)
	{
		float c = cos(20.0*p.y);
		float s = sin(20.0*p.y);
		float2x2  m = float2x2(c, -s, s, c);
		float3  q = float3(mul(m,p.xy), p.z);
		return sdSphere(q, 1.0);
	}


#endif // RAYMARCHING_CG_INCLUDED
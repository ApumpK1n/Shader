float _CurvedX;
half _CurvedZ;
float3 _CurvedPivot;
const float2 _zero2 = float2(0,0);

float4 getConvertPos(float4 vertex) 
{
	float4 worldPos = mul(unity_ObjectToWorld, vertex); 
	worldPos.xyz -= _CurvedPivot;

	float2 xzOff = max(_zero2, abs(worldPos.zx));
	xzOff *= step(_zero2, worldPos.zx) * 2 - 1;
	xzOff *= xzOff;
	
	float4 offset = float4(0, (_CurvedX * xzOff.x + _CurvedZ * xzOff.y) * 0.001, 0, 0); 

	return vertex + mul(unity_WorldToObject, offset);
}
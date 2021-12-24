fixed4 CalculateAlbedoAndAlpha(v2f IN, inout fixed3 albedo, inout fixed a)
{
	#if TEXTURE
		#if HUE_LINEAR
			fixed4 sampledColor = tex2D(_MainTex, IN.uv);
			fixed4 texColor = fixed4((1 - IN.color.a) * sampledColor.rgb + IN.color.a * IN.color.rgb, sampledColor.a);
		#elif HUE_ADD
			fixed4 texColor = tex2D(_MainTex, IN.uv) + IN.color;
		#else
			fixed4 texColor = tex2D(_MainTex, IN.uv) * IN.color;
		#endif

		albedo = texColor.rgb;
		#if defined(TRANSPARENT) || defined(CUTOUT)
			a = texColor.a;
		#endif
		#if SECONDARY_TEXTURE
			float4 second = tex2D(_SecondaryTex, IN.uv_secondary);

			// NOTE: Instead of doing a normal alpha blending, we balance the two textures so that the secondary texture doesn't add brightness.
			float alpha = 1 - (1 - a) * (1 - second.a);
			if (alpha > 0) 
			{
				float mixAlpha = second.a / alpha;
				albedo.rgb = lerp(albedo.rgb, second.rgb, mixAlpha);
			}

			#if ALPHA_TEXTURE
				a = alpha * tex2D(_AlphaTex, IN.uv_alpha).a;
			#endif
		#elif ALPHA_TEXTURE
			a = tex2D(_AlphaTex, IN.uv_alpha).a;
		#endif
	#elif ALPHA_TEXTURE
		albedo = IN.color;
		a = tex2D(_MainTex, IN.uv).a;
	#else
		albedo = IN.color.rgb;
		#if defined(TRANSPARENT)
			a = IN.color.a;
		#endif
	#endif

	return fixed4(albedo.r, albedo.g, albedo.b, a);
}

// Based on UnityComputeForwardShadows without support for cascade shadows and other fluff
fixed CustomComputeForwardShadows(float2 lightmapUV, float3 worldPos)
{
	#if SHADOWS_SCREEN
		// NOTE: This was the original method. It seems unnecessarily complex for what we want. If shadow fading has problems, swap with the optimized one.
		// float zDist = dot(_WorldSpaceCameraPos - worldPos, UNITY_MATRIX_V[2].xyz);
		float zDist = _WorldSpaceCameraPos.z - worldPos.z;
		float fadeDist = UnityComputeShadowFadeDistance(worldPos, zDist);
		fixed shadowFade = UnityComputeShadowFade(fadeDist);

		fixed shadowAttenuation = unitySampleShadow(mul(unity_WorldToShadow[0], float4(worldPos, 1.0)));

		return saturate(shadowAttenuation + shadowFade);
	#else
		return 1.0;
	#endif
}

#if SHADOWS_SCREEN
	#define CUSTOM_SHADOW_ATTENUATION(lightmapUV, worldPos) CustomComputeForwardShadows(lightmapUV, worldPos)
#else
	#define CUSTOM_SHADOW_ATTENUATION(lightmapUV, worldPos) 1.0;
#endif


#if LIGHTING
	// Ambient lighting, implemented in Unity usin Spherical Harmonics when using gradient ambient
	fixed3 SphericalHarmonics(fixed3 worldNormal)
	{
		fixed4 normal = fixed4(worldNormal, 1.0);
		fixed3 res = SHEvalLinearL0L1(normal);
		res += SHEvalLinearL2(normal);
		res = LinearToGammaSpace(res);
		return res;
	}
#endif
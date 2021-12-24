Shader "Custom/Master" 
{
	Properties 
	{
		[Toggle(TEXTURE)] _HasTexture("Texture", Float) = 0
		[Toggle(SECONDARY_TEXTURE)] _HasSecondaryTexture("Seconadry Texture", Float) = 0
		[Toggle(ALPHA_TEXTURE)] _HasAlphaTexture("Alpha Texture", Float) = 0
		[Toggle(VERTEX_COLOR)] _VertexColor("Vertex Color", Float) = 0
		[Toggle(LIGHTING)] _Lighting("Lighting", Float) = 0
		[Toggle(FOG)] _Fog("Fog", Float) = 0
		[Toggle(CURVE)] _Curve("Curve", Float) = 0
		[Toggle(VERTICAL_FOG)]_VerticalFog("Vertical Fog", Float) = 0
		[Toggle(DISABLE_SHADOW_NORMAL_OFFSET)] _DisableShadowNormalOffset("Disable Shadow Normal Offset", Float) = 0
		[Toggle(RECT_MASK)] _RectMask("Rect Mask", Float) = 0
		_Color("Color", Color) = (1,1,1,1)
		_ShadowColor("ShadowColor", Color) = (1,1,1,1)
		_MainTex("Texture", 2D) = "white" {}
		_SecondaryTex("Secondary Texture", 2D) = "white" {}
		_AlphaTex("Alpha Texture", 2D) = "white" {}
		_CutOff("Cut off", float) = 0.1
		_VerticalFogY("Vertical Fog Y", float) = 0.0
		_VerticalFogHeight("Vertical Fog Height", float) = 10.0
		_VerticalFogColor("Vertical Fog Color", Color) = (1,1,1,1)

		// Stencil
		_StencilComp("Stencil Comparison", Float) = 8
		_Stencil("Stencil ID", Float) = 0
		_StencilOp("Stencil Operation", Float) = 0
		_StencilWriteMask("Stencil Write Mask", Float) = 255
		_StencilReadMask("Stencil Read Mask", Float) = 255
		_ColorMask("Color Mask", Float) = 15

		// Alpha
		_ZWrite ("ZWrite", Float) = 1
		[Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 2
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Float) = 0
	}

	SubShader 
	{
		Stencil {
			Ref [_Stencil]
			Comp [_StencilComp]
			Pass[_StencilOp]
			ReadMask[_StencilReadMask]
			WriteMask[_StencilWriteMask]
		}


		Pass {
			Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase" }
			ZWrite [_ZWrite]
			Cull [_CullMode]
			Blend [_SrcBlend] [_DstBlend]
			ColorMask[_ColorMask]

			CGPROGRAM

			#pragma shader_feature_local TEXTURE
			#pragma shader_feature_local SECONDARY_TEXTURE
			#pragma shader_feature_local ALPHA_TEXTURE
			#pragma shader_feature_local VERTEX_COLOR
			#pragma shader_feature_local LIGHTING
			#pragma shader_feature_local FOG
			#pragma shader_feature_local CURVE
			#pragma shader_feature_local TRANSPARENT
			#pragma shader_feature_local CUTOUT
			#pragma shader_feature_local ADDITIVE
			#pragma shader_feature_local VERTICAL_FOG
			#pragma shader_feature_local RECT_MASK
			#pragma shader_feature_local BLEND_ADD
			#pragma shader_feature_local COLOR_IS_ALPHA
			#pragma shader_feature_local HUE_MULTIPLY
			#pragma shader_feature_local HUE_LINEAR
			#pragma shader_feature_local HUE_ADD
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase
			#include "UnityCG.cginc"
			#include "UnityUI.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#if CURVE
				#include "Include/CurvedGeometry.cginc"
			#endif

			struct vertex_data {
				float4 vertex : POSITION;
				#if LIGHTING
					float3 normal : NORMAL;
				#endif
				#if defined(TEXTURE) || defined(ALPHA_TEXTURE)
					fixed2 texcoord : TEXCOORD0;
				#endif
				#if VERTEX_COLOR
					fixed4 color : COLOR;
				#endif
			};

			fixed4 _Color;
			fixed4 _ShadowColor;
			// sampler2D _ShadowMapTexture;
			#if defined(TEXTURE) || defined(ALPHA_TEXTURE)
				sampler2D _MainTex;
				float4 _MainTex_ST;
			#endif
			#if defined(TEXTURE) && defined(SECONDARY_TEXTURE)
				sampler2D _SecondaryTex;
				float4 _SecondaryTex_ST;
			#endif
			#if defined(TEXTURE) && defined(ALPHA_TEXTURE)
				sampler2D _AlphaTex;
				float4 _AlphaTex_ST;
			#endif

			#if CUTOUT
				float _CutOff;
			#endif

			#if VERTICAL_FOG
				fixed _VerticalFogY;
				fixed _VerticalFogHeight;
				fixed4 _VerticalFogColor;
			#endif

			#if RECT_MASK
				float4 _ClipRect;
			#endif

			struct v2f {
				UNITY_POSITION(pos);

				#if defined(TEXTURE) || defined(ALPHA_TEXTURE)
					fixed2 uv : TEXCOORD0;
				#endif
				#if defined(TEXTURE) && defined(SECONDARY_TEXTURE)
					fixed2 uv_secondary : TEXCOORD1;
				#endif
				#if defined(TEXTURE) && defined(ALPHA_TEXTURE)
					fixed2 uv_alpha : TEXCOORD2;
				#endif

				fixed4 color : COLOR0;
				float3 worldPos : TEXCOORD3;
				#if LIGHTING
					fixed diffuseLight : TEXCOORD4;
					fixed3 sphericalHarmonics : TEXCOORD5;
				#endif
				#if FOG
					UNITY_FOG_COORDS(6)
				#endif
				#if RECT_MASK
					fixed3 localPosition : TEXCOORD7;
				#endif
			};

			// NOTE: Include after defining v2f and uniforms, Utils depends on them
			#include "Include/Utils.cginc"

			v2f vert (vertex_data v) {
				v2f o;
				#if RECT_MASK
					o.localPosition = v.vertex;
				#endif
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				#if CURVE
					v.vertex = getConvertPos(v.vertex);
				#endif
				o.pos = UnityObjectToClipPos(v.vertex);

				#if defined(TEXTURE) || defined(ALPHA_TEXTURE)
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				#endif
				#if defined(TEXTURE) && defined(SECONDARY_TEXTURE)
					o.uv_secondary = TRANSFORM_TEX(v.texcoord, _SecondaryTex);
				#endif
				#if defined(TEXTURE) && defined(ALPHA_TEXTURE)
					o.uv_alpha = TRANSFORM_TEX(v.texcoord, _AlphaTex);
				#endif

				o.color = _Color;
				#if VERTEX_COLOR
					#if HUE_LINEAR
						o.color = fixed4((1.0 - o.color.a) * v.color + o.color.a * o.color.rgb, v.color.a);
					#elif HUE_ADD
						o.color += v.color;
					#else
						o.color *= v.color;
					#endif
				#endif
				#if BLEND_ADD
					o.color.rgb *= o.color.a;
				#endif
				
				#if LIGHTING
					float3 worldNormal = UnityObjectToWorldNormal(v.normal);
					o.diffuseLight = max(0, dot (worldNormal, _WorldSpaceLightPos0.xyz));
					o.sphericalHarmonics = SphericalHarmonics(worldNormal);
				#endif

				#if FOG
					UNITY_TRANSFER_FOG(o, o.pos);
				#endif
				
				return o;
			}

			fixed4 frag (v2f IN) : SV_Target {
				fixed atten = CUSTOM_SHADOW_ATTENUATION(0, IN.worldPos);

				fixed3 albedo = 0;
				fixed alpha = 1;
				fixed4 color = CalculateAlbedoAndAlpha(IN, albedo, alpha);

				fixed4 c = 0;
				#if LIGHTING
					c.rgb += albedo * IN.diffuseLight * _LightColor0.rgb * atten;
					c.rgb += albedo * IN.sphericalHarmonics;
				#else
					c.rgb += albedo * atten * (1.0 + (1.0f - atten) * _ShadowColor);
				#endif
				
				#if VERTICAL_FOG
					fixed fogValue = smoothstep(_VerticalFogY, _VerticalFogY - _VerticalFogHeight, IN.worldPos.y) * _VerticalFogColor.a;
					c.rgb = c.rgb * (1.0 - fogValue) + _VerticalFogColor * fogValue;
				#endif

				#if FOG
					UNITY_APPLY_FOG(IN.fogCoord, c);
				#endif

				#if TRANSPARENT
					#if COLOR_IS_ALPHA
						c.a = min(1.0, (c.r + c.g + c.b)) - alpha;
					#else
						c.a = alpha;
					#endif
				#elif CUTOUT
					if(alpha < _CutOff) discard;
				#endif

				#if RECT_MASK
					c.a *= UnityGet2DClipping(IN.localPosition.xy, _ClipRect);
				#endif

				return c;
			}

			ENDCG
		}




		Pass {
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On 
			ZTest LEqual
			Cull Back

			CGPROGRAM

			#pragma shader_feature_local DISABLE_SHADOW_NORMAL_OFFSET
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct vertex_data {
				float4 vertex : POSITION;
				#if !defined(DISABLE_SHADOW_NORMAL_OFFSET)
					float4 normal : NORMAL;
				#endif
			};

			struct v2f {
				V2F_SHADOW_CASTER;
			};

			v2f vert (vertex_data v) {
				v2f o;
				#if DISABLE_SHADOW_NORMAL_OFFSET
					TRANSFER_SHADOW_CASTER(o)
				#else
					TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				#endif
				return o;
			}

			fixed4 frag (v2f IN) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(IN)
			}

			ENDCG
		}
	}

	CustomEditor "MasterShaderGUI"

	Fallback "VertexLit"
}
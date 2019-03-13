Shader "Custom/PGMToonGuiltyShader" {
	Properties {
		//Prop to control breakpoint between light and shadow
		_LitOffset ("Lit offset", Range(0,1)) = 0.25
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RBG)", 2D)= "white" {}
		//Add SSS Map (SubSurface Scattering) to improve shadinding so areas arent totoally dark
		_SSSTex("SSS Map", 2D) = "black" {}
		_SSSColor("SSS Tint", Color) = (1,1,1,1)
		//Combined Map
		_CombMap("Comb Map", 2D) = "white" {}
		//control Specular size
		_SpecPower("Specular Power", Range(0,100)) = 20.0
		//scale intensity of Specular comp
		_SpecScale("Specular Scale", Range(0,10)) = 1.0
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_OutlineThickness("Outline Thickness", Range(0,1)) = 0.3
	}
	SubShader {
		Tags {"RenderType" = "Opaque"}
		LOD 200
		
		//Outline Pass
		//mix regular vetex/fragment passes with surface passes
		Pass {
			Cull Front
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			half4 _OutlineColor;
			half _OutlineThickness;

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex+normalize(v.normal)*(_OutlineThickness/100));
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				return _OutlineColor;
			}
			ENDCG
		}

		CGPROGRAM
		#pragma surface surf ToonLighting

		//Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _SSSTex;
		sampler2D _CombMap;
		half4 _Color;
		half4 _SSSColor;
		half _LitOffset;
		half _SpecPower;
		half _SpecScale;

		//CustomSurfaceOutput for using extra data from textures
		struct CustomSurfaceOutput {
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half Alpha;
			half3 SSS;
			half vertexOc;
			half Glossy;
			half Glossiness;
			half Shadow;
			half InnerLine;
		};

		//custom lighting function
		half4 LightingToonLighting( CustomSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
		{
			float oc = step(0.9, s.vertexOc);
			//To get lighting, use dot product. Get normal and light direction
			//dot gives -1,1 values according to light incidence, saturate clamp it to 0-1
			float NdotL = saturate(dot(s.Normal, lightDir)) * atten;
			
			//step function to discretize smoothness
			//Step will return 0 to 1, if second paramater is greater than first 1, else 0
			float toonL = step(_LitOffset, NdotL) * s.Shadow * oc;
	
			half3 albedoColor = lerp( s.Albedo * s.SSS, s.Albedo * _LightColor0 * toonL, toonL);
			
			//with the pow function, we'll control size of reflection
			half3 specularColor = saturate( pow(dot(reflect(-lightDir, s.Normal), viewDir), s.Glossiness * _SpecPower)) 
								  * toonL * _LightColor0 * s.Glossy * _SpecScale;
			return half4( (albedoColor + specularColor) * s.InnerLine, 1);
			//Reads Albedo texture and returns color as is
			//return half4(s.Albedo,1);
		}

		struct Input {
			float2 uv_MainTex;
			float4 vertColor : COLOR;
		};

		void surf (Input IN, inout CustomSurfaceOutput o) {
			// Albedo comes from texture tinted by Color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			half4 comb = tex2D(_CombMap, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.SSS = tex2D(_SSSTex, IN.uv_MainTex) * _SSSColor;
			o.vertexOc = IN.vertColor.r;
			o.Glossy = comb.r;
			//Give Blue CombMap channel a use: scale the Specular Power
			//Darker is bigger. The smaller the exponent, the bigger the highlight
			o.Glossiness = comb.b;
			//Green schannel to add extra shadows. (If textures aren't made correctly, they could pixelate)
			o.Shadow = comb.g;
			//Alpha channel used as InnerLine mask. Alpha 0 is a line.
			o.InnerLine = comb.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
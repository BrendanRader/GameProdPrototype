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
	}
	SubShader {
		Tags {"RenderType" = "Opaque"}
		LOD 200

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

		//CustomSurfaceOutput for using extra data from textures
		struct CustomSurfaceOutput {
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half Alpha;
			half3 SSS;
			half vertexOc;
			half Glossy;
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
			float toonL = step(_LitOffset, NdotL) *oc;
	
			half3 albedoColor = lerp( s.Albedo * s.SSS, s.Albedo * _LightColor0 * toonL, toonL);
			
			//with the pow function, we'll control size of reflection
			half3 specularColor = saturate( pow(dot(reflect(-lightDir, s.Normal), viewDir), 20));
			return half4( albedoColor, 1);
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
		}
		ENDCG
	}
	FallBack "Diffuse"
}
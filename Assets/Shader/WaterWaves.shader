
Shader "Custom/WaterSurface"
{
    Properties
    {
        
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _WaterFogColour ("Water Fog Colour", Color) = (0, 0, 0, 0)
        _WaterFogDensity ("Water Fog Density", Range(0.1, 0.95)) = 0.1
        _Wave1 ("Wave 1 (Direction XY, Steepness, Wavelength)", Vector) = (1, 0, 0.5, 10)
        _Wave2 ("Wave 2 (Direction XY, Steepness, Wavelength)", Vector) = (1, 0, 0.5, 10)

    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200

        GrabPass { "_WaterBackground" }

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard alpha vertex:vert finalcolor:ResetAlpha fullforwardshadows addshadow

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        //include waterdepth file
        #include "LookingThroughWater.cging"

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float4 screenPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
        float4 _Wave1, _Wave2;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        //generate a wave
        float3 GerstnerWave (float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
        {
            float steepness = wave.z;
            float wavelength = wave.w;
            float k = UNITY_PI * 2 / wavelength;           //wave number
            float c = sqrt(9.8 / k);                        //wave velocity
            float2 d = normalize(wave.xy);               //wave direction
            float f = k * (dot(d, p.xz) - c * _Time.y);     //time function
            float a = steepness / k;                       //amplitude 

            //calculate derivative of the wave function
            //and find tangent of this vector
            tangent += float3(-d.x * d.x * (steepness * sin(f)), 
                              d.x * (steepness * cos(f)), 
                              -d.x * d.y * (steepness * sin(f)));
                           
            binormal += float3(-d.x * d.y * (steepness * sin(f)), 
                               d.x * (steepness * cos(f)), 
                               -d.y * d.x * (steepness * sin(f)));

            return float3(d.x * (a * cos(f)),
                          a * sin(f),
                          d.y * (a * cos(f)));

        }

        void ResetAlpha (Input IN, SurfaceOutputStandard o, inout fixed4 color)
        {
            color.a = 1;
        }

        //changes position of vertex
        void vert (inout appdata_full v)
        {
            //get vertex position
            float3 g = v.vertex.xyz;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            float3 p = g;

            //add vectors for each wave
            p += GerstnerWave(_Wave1, g, tangent, binormal);
            p += GerstnerWave(_Wave2, g, tangent, binormal);

            //calculate new normal and apply vectors to vertex
            float3 normal = normalize(cross(binormal, tangent));
            v.vertex.xyz = p;
            v.normal = normal;
        }

        /*float3 ColorBelowWater (float4 screenPos) 
        {
	        float2 uv = screenPos.xy / screenPos.w;
	        float backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	        float surfaceDepth = Unity_Z_0_FAR_FROM_CLIPSPACE(screenPos.z);
	        float depthDifference = backgroundDepth - surfaceDepth;
	        return depthDifference / 20;
        }*/

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
            //o.Albedo = ColorBelowWater(IN.screenPos);
            o.Emission = ColorBelowWater(IN.screenPos) * (1-c.a);
        }
        ENDCG
    }
}

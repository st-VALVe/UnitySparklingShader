Shader "Custom/Sparkling"
{
    Properties
    {
        [Header(Texture Masks)]
        [Space(10)]
        _Color ("Main color", Color) = (0.07429244,0.0,0.2641509,1)        
        _SparklingMap ("Sparkling map", 2D) = "white" {}
        [HDR]_SparklingColor ("Sparkling color", Color) = (1,1,1,1)
        _SparklingPower ("Sparkling power", Range(0, 10)) = 4
        _SparklingContrast ("Sparkling contrast", Range(1, 10)) = 2
        _SparklingSpeed ("Sparkling speed", Range(0, 1)) = 0.5
        _SparklingMaskScale ("Sparkling dots scale", Range(0.1, 8)) = 2
        [Space(10)]
        _ReflectionCubemap("Reflection cubemap", Cube) = "black" {}
        _ReflectionCubemapPower("Reflection cubemap power", Range(0, 1)) = 0.5
        _ReflectionCubemapBlur("Cubemap blur", Range(0, 10)) = 0
        _Glossiness("Glossiness", Range(1, 20)) = 7
        _SpecularPower("Specular power", Range(0, 5)) = 1.5
        _SpecularContrast("Specular contrast", Range(1, 5)) = 2
    }
    SubShader {
        Tags {"Queue" = "Geometry"}
        
        CGINCLUDE
            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile_fog
            #pragma exclude_renderers xbox360 ps3 
            #pragma target 3.0

            uniform float4 _LightColor0;
            uniform float _Glossiness;
            uniform float _SpecularPower;
            uniform float _SparklingPower;
            uniform float4 _Color;
            uniform float _FakeLight;
            uniform float4 _SparklingColor;
            uniform float _SparklingMaskScale;
            uniform float _SparklingSpeed;
            uniform sampler2D _SparklingMap; uniform float4 _SparklingMap_ST;
            uniform samplerCUBE _ReflectionCubemap;
            uniform float _ReflectionCubemapPower;
            uniform float _ReflectionCubemapBlur;
            uniform float _SparklingContrast;
            uniform float _SpecularContrast;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord0 : TEXCOORD0;
            };
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float3 normalDir : TEXCOORD2;
                float3 tangentDir : TEXCOORD3;
                float3 bitangentDir : TEXCOORD4;
                LIGHTING_COORDS(5, 6)
                UNITY_FOG_COORDS(7)
            };
            v2f vert(appdata v) {
                v2f o;
                o.uv = v.texcoord0;
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }
            float4 frag(v2f i) : SV_Target{
                float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                float3 normalDirection = normalize(i.normalDir);
                float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                float3 halfDirection = normalize(viewDirection + lightDirection);
                float NdotL = saturate(dot(normalDirection, lightDirection));

                float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
                float2 tangent2view = mul(tangentTransform, viewDirection).xy;
                _SparklingSpeed = _SparklingSpeed * 0.05;

                float2 glitterUV = (i.uv - _SparklingSpeed * tangent2view).rg * _SparklingMaskScale;
                fixed glitterMap = tex2D(_SparklingMap,TRANSFORM_TEX(glitterUV, _SparklingMap));

                float2 glitterUV2 = (i.uv + _SparklingSpeed * tangent2view).rg * _SparklingMaskScale;
                fixed glitterMap2 = tex2D(_SparklingMap, TRANSFORM_TEX(glitterUV2, _SparklingMap));

                fixed specularSparklingMap = tex2D(_SparklingMap,TRANSFORM_TEX(i.uv, _SparklingMap) * 5);

                float specularMask = pow(_SparklingPower * glitterMap2, _SparklingContrast) * glitterMap;
                specularMask += pow(specularSparklingMap * _SpecularPower, _SpecularContrast);
                float3 specular = _LightColor0.xyz * pow(saturate(dot(halfDirection, normalDirection)), _Glossiness) * specularMask;
                specular += specular * _SparklingColor.rgb;

                float3 emissive = specularMask * 0.05 * _SparklingColor.rgb;
                emissive += emissive * _SparklingColor.rgb;

                float3 viewReflectDirection = reflect(-viewDirection, normalDirection);
                emissive += texCUBElod(_ReflectionCubemap, float4(viewReflectDirection, _ReflectionCubemapBlur)).rgb * _ReflectionCubemapPower;

                float3 directDiffuse = NdotL * _LightColor0.xyz;
                float3 diffuse = (directDiffuse + UNITY_LIGHTMODEL_AMBIENT.rgb) * _Color.rgb;

                float3 finalColor = diffuse + specular + emissive;
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return fixed4(finalColor, 1);
            }
        ENDCG

        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }                       
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag            
            ENDCG
        }
        /*
        Pass{
            Name "FORWARD_DELTA"
            Tags {
                "LightMode" = "ForwardAdd"
            }
            Blend One One
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
        */
    }
    FallBack "Diffuse"
}

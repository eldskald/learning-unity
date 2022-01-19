#if !defined(PLANAR_REFLECTIONS_INCLUDED)
#define PLANAR_REFLECTIONS_INCLUDED

#if defined(_PLANAR_REFLECTIONS_ENABLED)

    #if defined(_PRID_ONE)
        sampler2D _PlanarReflectionsTex1;
        fixed4 SamplePlanarReflections (float4 screenUV) {
            float2 uv = screenUV.xy / screenUV.w;
            uv.x = 1 - uv.x;
            return tex2D(_PlanarReflectionsTex1, uv);
        }

    #elif defined(_PRID_TWO)
        sampler2D _PlanarReflectionsTex2;
        fixed4 SamplePlanarReflections (float4 screenUV) {
            float2 uv = screenUV.xy / screenUV.w;
            uv.x = 1 - uv.x;
            return tex2D(_PlanarReflectionsTex2, uv);
        }

    #elif defined(_PRID_THREE)
        sampler2D _PlanarReflectionsTex3;
        fixed4 SamplePlanarReflections (float4 screenUV) {
            float2 uv = screenUV.xy / screenUV.w;
            uv.x = 1 - uv.x;
            return tex2D(_PlanarReflectionsTex3, uv);
        }

    #elif defined(_PRID_FOUR)
        sampler2D _PlanarReflectionsTex4;
        fixed4 SamplePlanarReflections (float4 screenUV) {
            float2 uv = screenUV.xy / screenUV.w;
            uv.x = 1 - uv.x;
            return tex2D(_PlanarReflectionsTex4, uv);
        }

    #endif
#endif

#endif
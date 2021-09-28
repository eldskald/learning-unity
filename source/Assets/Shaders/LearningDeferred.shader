Shader "Custom/DeferredShading" {
	
	Properties {
	}

	SubShader {

		Pass {
			Cull Off
			ZTest Always
			ZWrite Off
			
			CGPROGRAM

			#pragma target 3.0
			#pragma exclude_renderers nomrt

			#define DEFERRED_LIGHT_PASS
			
			#include "DeferredInclude.cginc"

			ENDCG
		}

        Pass {
			Cull Off
			ZTest Always
			ZWrite Off
			
			Stencil {
				Ref [_StencilNonBackground]
				ReadMask [_StencilNonBackground]
				CompBack Equal
				CompFront Equal
			}

			CGPROGRAM

			#pragma target 3.0
			#pragma exclude_renderers nomrt

			#define DEFERRED_LIGHT_PASS
			
			#include "DeferredInclude.cginc"

			ENDCG
		}
	}
}
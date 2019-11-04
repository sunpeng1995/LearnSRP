#ifndef MYRP_SHADOWCASTER_INCLUDED
#define MYRP_SHADOWCASTER_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

CBUFFER_START(UnityPerFrame)
    float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
CBUFFER_END

CBUFFER_START(_ShadowCasterBuffer)
    float _ShadowBias;
CBUFFER_END

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float _Cutoff;
CBUFFER_END

#define UNITY_MATRIX_M unity_ObjectToWorld
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

UNITY_INSTANCING_BUFFER_START(PerInstance)
	UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(PerInstance)

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

struct VertexInput {
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
    float4 clipPos : SV_POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

VertexOutput ShadowCasterPassVertex(VertexInput input) {
    VertexOutput o;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, o);
    float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
    o.clipPos = mul(unity_MatrixVP, worldPos);

    // 防止顶点因超出近平面而被裁剪
#if UNITY_REVERSED_Z
    o.clipPos.z -= _ShadowBias;
    o.clipPos.z = min(o.clipPos.z, o.clipPos.w * UNITY_NEAR_CLIP_VALUE);
#else
    o.clipPos.z += _ShadowBias;
    o.clipPos.z = max(o.clipPos.z, o.clipPos.w * UNITY_NEAR_CLIP_VALUE);
#endif
    o.uv = TRANSFORM_TEX(input.uv, _MainTex);
    return o;
}

float4 ShadowCasterPassFragment(VertexOutput input) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(input);
#if !defined(_CLIPPING_OFF)
    float4 albedoAlpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    albedoAlpha *= UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color);

    clip(albedoAlpha.a - _Cutoff);
#endif

    return 0;
}

#endif
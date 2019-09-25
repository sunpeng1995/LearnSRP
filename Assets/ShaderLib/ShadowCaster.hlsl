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

#define UNITY_MATRIX_M unity_ObjectToWorld
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

struct VertexInput {
    float4 pos : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
    float4 clipPos : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

VertexOutput ShadowCasterPassVertex(VertexInput input) {
    VertexOutput o;
    UNITY_SETUP_INSTANCE_ID(input);
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
    return o;
}

float4 ShadowCasterPassFragment(VertexOutput input) : SV_TARGET {
    return 0;
}

#endif
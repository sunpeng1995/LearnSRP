#ifndef MYRP_LIT_INCLUDED
#define MYRP_LIT_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

CBUFFER_START(UnityPerFrame)
    float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4 unity_LightIndicesOffsetAndCount;
    float4 unity_4LightIndices0, unity_4LightIndices1;
CBUFFER_END

#define UNITY_MATRIX_M unity_ObjectToWorld
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

// CBUFFER_START(UnityPerMaterial)
//     float4 _Color;
// CBUFFER_END
UNITY_INSTANCING_BUFFER_START(PerInstance)
	UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(PerInstance)

struct VertexInput {
    float4 pos : POSITION;
    float3 normal : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
    float4 clipPos : SV_POSITION;
    float3 normal : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 vertexLighting : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#define MAX_VISIBLE_LIGHTS 16
CBUFFER_START(_LightBuffer)
    float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
CBUFFER_END

CBUFFER_START(_ShadowBuffer)
    // float4x4 _WorldToShadowMatrix;
    // float _ShadowStrength;
    float4x4 _WorldToShadowMatrices[MAX_VISIBLE_LIGHTS];
    float4x4 _WorldToShadowCascadeMatrices[4];
    float4 _ShadowData[MAX_VISIBLE_LIGHTS];
    float4 _ShadowMapSize;
    float4 _CascadedShadowMapSize;
    float4 _GlobalShadowData;
    float4 _CascadedShadowStrength;
CBUFFER_END

CBUFFER_START(UnityPerCamera)
    float3 _WorldSpaceCameraPos;
CBUFFER_END

TEXTURE2D_SHADOW(_ShadowMap);
SAMPLER_CMP(sampler_ShadowMap);

TEXTURE2D_SHADOW(_CascadedShadowMap);
SAMPLER_CMP(sampler_CascadedShadowMap);

float DistanceToCameraSqr(float3 worldPos) {
    float cameraToFragment = worldPos - _WorldSpaceCameraPos;
    return dot(cameraToFragment, cameraToFragment);
}

float HardShadowAttenuation(float4 shadowPos, bool cascade = false) {
    if (cascade) {
        return SAMPLE_TEXTURE2D_SHADOW(_CascadedShadowMap, sampler_CascadedShadowMap, shadowPos.xyz);
    }
    else {
        return SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
    }
}

float SoftShadowAttenuation(float4 shadowPos, bool cascade = false) {
    real tentWeights[9];
    real2 tentUVs[9];
    float4 size = cascade ? _CascadedShadowMapSize : _ShadowMapSize;
    SampleShadow_ComputeSamples_Tent_5x5(size, shadowPos.xy, tentWeights, tentUVs);
    float attenuation = 0;
    for (int i = 0; i < 9; i++) {
        attenuation += tentWeights[i] * HardShadowAttenuation(float4(tentUVs[i], shadowPos.z, 0), cascade);
    }
    return attenuation;
}

// return 1 in light, 0 in shadow
float ShadowAttenuation(int index, float3 worldPos) {
#if !defined(_SHADOWS_HARD) && !defined(_SHADOWS_SOFT)
    return 1.0;
#endif
    if (_ShadowData[index].x <= 0 ||
        DistanceToCameraSqr(worldPos) > _GlobalShadowData.y) {
        return 1.0;
    }
    float4 shadowPos = mul(_WorldToShadowMatrices[index], float4(worldPos, 1.0f));
    shadowPos.xyz /= shadowPos.w;
    shadowPos.xy = saturate(shadowPos.xy);
    shadowPos.xy = shadowPos.xy * _GlobalShadowData.x + _ShadowData[index].zw;
    float attenuation = 1;// = SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
#if defined(_SHADOWS_HARD)
  #if defined(_SHADOWS_SOFT)
    if (_ShadowData[index].y == 0) {
        attenuation = HardShadowAttenuation(shadowPos);
    }
    else {
        attenuation = SoftShadowAttenuation(shadowPos);
    }
  #else
    attenuation = HardShadowAttenuation(shadowPos);
  #endif
#else
    attenuation = SoftShadowAttenuation(shadowPos);
#endif
    return lerp(1, attenuation, _ShadowData[index].x);
}

float CascadedShadowAttenuation(float3 worldPos) {
#if !defined(_CASCADED_SHADOWS_HARD) && !defined(_CASCADED_SHADOWS_SOFT)
    return 1.0;
#endif

    float cascadeIndex = 2;
    float4 shadowPos = mul(_WorldToShadowCascadeMatrices[cascadeIndex], float4(worldPos, 1.0));
    float attenuation = 1;
#if defined(_CASCADED_SHADOWS_HARD)
    attenuation = HardShadowAttenuation(shadowPos, true);
#else
    attenuation = SoftShadowAttenuation(shadowPos, true);
#endif
    return lerp(1, attenuation, _CascadedShadowStrength);
}

float3 MainLight(float3 normal, float3 worldPos) {
    float shadowAttenuation = CascadedShadowAttenuation(worldPos);
    float3 lightColor = _VisibleLightColors[0].rgb;
    float3 lightDirection = _VisibleLightDirectionsOrPositions[0].xyz;
    float diffuse = saturate(dot(normal, lightDirection)) * shadowAttenuation;
    return diffuse * lightColor;
}

float3 DiffuseLight(int index, float3 normal, float3 worldPos, float shadowAttenuation) {
    float3 lightColor = _VisibleLightColors[index].rgb;
    float4 lightDirectionOrPosition = _VisibleLightDirectionsOrPositions[index];
    float4 lightAttenuation = _VisibleLightAttenuations[index];
    float3 spotDirection = _VisibleLightSpotDirections[index].xyz;

    float3 lightVector = lightDirectionOrPosition.xyz - worldPos * lightDirectionOrPosition.w;//w分量在点和方向分别为1和0
    float3 lightDirection = normalize(lightVector);
    float diffuse = saturate(dot(normal, lightDirection));

    // (1 - (dir^2 / range^2)^2)^2
    float rangeFade = dot(lightVector, lightVector) * lightAttenuation.x;
    rangeFade = saturate(1.0 - rangeFade * rangeFade);
    rangeFade *= rangeFade;

    float spotFade = dot(spotDirection, lightDirection);
    spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
    spotFade *= spotFade;

    float distanceSqr = max(dot(lightVector, lightVector), 0.00001);//方向向量dot结果为1，即衰减不影响方向光
    diffuse *= shadowAttenuation * spotFade * rangeFade / distanceSqr;

    return diffuse * lightColor;
}

VertexOutput LitPassVertex(VertexInput input) {
    VertexOutput o;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, o);
    float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
    o.clipPos = mul(unity_MatrixVP, worldPos);
    o.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
    o.worldPos = worldPos.xyz;
    o.vertexLighting = 0;
    for (int i = 4; i < min(unity_LightIndicesOffsetAndCount.y, 8); i++) {
        int lightIdx = unity_4LightIndices1[i - 4];
        o.vertexLighting += DiffuseLight(lightIdx, o.normal, o.worldPos, 1);
    }
    return o;
}

float4 LitPassFragment(VertexOutput input) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(input);
    input.normal = normalize(input.normal);
    float3 albedo = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color).rgb;
    float3 diffuseLight = input.vertexLighting;
#if defined(_CASCADED_SHADOWS_HARD) || defined(_CASCADED_SHADOWS_SOFT)
    diffuseLight += MainLight(input.normal, input.worldPos);
#endif
    for (int i = 0; i < min(unity_LightIndicesOffsetAndCount.y, 4); i++) {
        int lightIdx = unity_4LightIndices0[i];
        float shadowAttenuation = ShadowAttenuation(lightIdx, input.worldPos);
        diffuseLight += DiffuseLight(lightIdx, input.normal, input.worldPos, shadowAttenuation);
    }
    float3 color = diffuseLight * albedo;//input.normal;// * 0.5 + 0.5;
    return float4(color, 1);
}

#endif
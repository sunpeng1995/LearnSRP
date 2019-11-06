#ifndef MYRP_LIT_INCLUDED
#define MYRP_LIT_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

CBUFFER_START(UnityPerFrame)
    float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld, unity_WorldToObject;
    float4 unity_LightIndicesOffsetAndCount;
    float4 unity_4LightIndices0, unity_4LightIndices1;
CBUFFER_END

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

#include "Lighting.hlsl"

// CBUFFER_START(UnityPerMaterial)
//     float4 _Color;
// CBUFFER_END
UNITY_INSTANCING_BUFFER_START(PerInstance)
	UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_INSTANCING_BUFFER_END(PerInstance)

struct VertexInput {
    float4 pos : POSITION;
    float3 normal : NORMAL;
    float2 uv :TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
    float4 clipPos : SV_POSITION;
    float3 normal : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 vertexLighting : TEXCOORD2;
    float2 uv : TEXCOORD3;
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
    float4x4 _WorldToShadowCascadeMatrices[5];
    float4 _CascadeCullingSpheres[4];
    float4 _ShadowData[MAX_VISIBLE_LIGHTS];
    float4 _ShadowMapSize;
    float4 _CascadedShadowMapSize;
    float4 _GlobalShadowData;
    float _CascadedShadowStrength;
CBUFFER_END

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float _Cutoff;
CBUFFER_END

CBUFFER_START(UnityPerCamera)
    float3 _WorldSpaceCameraPos;
CBUFFER_END

TEXTURE2D_SHADOW(_ShadowMap);
SAMPLER_CMP(sampler_ShadowMap);

TEXTURE2D_SHADOW(_CascadedShadowMap);
SAMPLER_CMP(sampler_CascadedShadowMap);

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

TEXTURECUBE(unity_SpecCube0);
SAMPLER(samplerunity_SpecCube0);

float3 SampleEnvironment(LitSurface s) {
    float3 reflectVector = reflect(-s.viewDir, s.normal);
    float mip = PerceptualRoughnessToMipmapLevel(s.perceptualRoughness);

    float3 uvw = reflectVector;
    float4 sampled = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, uvw, mip);

    float3 color = sampled.rgb;
    return color;
}

float3 ReflectEnvironment(LitSurface s, float3 environment) {
    if (s.perfectDiffuser)
        return 0;
    
    environment *= s.specular;
    environment /= s.roughness * s.roughness + 1.0;
    float fresnel = Pow4(1.0 - saturate(dot(s.normal, s.viewDir)));
    environment *= lerp(s.specular, s.fresnelStrength, fresnel);
    return environment;
}

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
#if !defined(_RECEIVE_SHADOWS)
    return 1.0;
#elif !defined(_SHADOWS_HARD) && !defined(_SHADOWS_SOFT)
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

float InsideCascadeCullingSphere(int index, float3 worldPos) {
    float4 s = _CascadeCullingSpheres[index];
    return dot(worldPos - s.xyz, worldPos - s.xyz) < s.w;
}

float CascadedShadowAttenuation(float3 worldPos) {
#if !defined(_RECEIVE_SHADOWS)
    return 1.0;
#elif !defined(_CASCADED_SHADOWS_HARD) && !defined(_CASCADED_SHADOWS_SOFT)
    return 1.0;
#endif
    if (DistanceToCameraSqr(worldPos) > _GlobalShadowData.y)
        return 1.0;

    float4 cascadeFlags = float4(
        InsideCascadeCullingSphere(0, worldPos),
        InsideCascadeCullingSphere(1, worldPos),
        InsideCascadeCullingSphere(2, worldPos),
        InsideCascadeCullingSphere(3, worldPos)
    );
    cascadeFlags.yzw = saturate(cascadeFlags.yzw - cascadeFlags.xyz);
    float cascadeIndex = 4 - dot(cascadeFlags, float4(4, 3, 2, 1));
    float4 shadowPos = mul(_WorldToShadowCascadeMatrices[cascadeIndex], float4(worldPos, 1.0));
    float attenuation = 1;
#if defined(_CASCADED_SHADOWS_HARD)
    attenuation = HardShadowAttenuation(shadowPos, true);
#else
    attenuation = SoftShadowAttenuation(shadowPos, true);
#endif
    return lerp(1, attenuation, _CascadedShadowStrength);
}

float3 MainLight(LitSurface s) {
    float shadowAttenuation = CascadedShadowAttenuation(s.position);
    float3 lightColor = _VisibleLightColors[0].rgb;
    float3 lightDirection = _VisibleLightDirectionsOrPositions[0].xyz;
    // float diffuse = saturate(dot(normal, lightDirection)) * shadowAttenuation;
    float3 color = LightSurface(s, lightDirection);
    color *= shadowAttenuation;
    return color * lightColor;
}

float3 GenericLight(int index, LitSurface s, float shadowAttenuation) {
    float3 lightColor = _VisibleLightColors[index].rgb;
    float4 lightDirectionOrPosition = _VisibleLightDirectionsOrPositions[index];
    float4 lightAttenuation = _VisibleLightAttenuations[index];
    float3 spotDirection = _VisibleLightSpotDirections[index].xyz;

    float3 lightVector = lightDirectionOrPosition.xyz - s.position * lightDirectionOrPosition.w;//w分量在点和方向分别为1和0
    float3 lightDirection = normalize(lightVector);
    // float diffuse = saturate(dot(normal, lightDirection));
    float3 color = LightSurface(s, lightDirection);

    // (1 - (dir^2 / range^2)^2)^2
    float rangeFade = dot(lightVector, lightVector) * lightAttenuation.x;
    rangeFade = saturate(1.0 - rangeFade * rangeFade);
    rangeFade *= rangeFade;

    float spotFade = dot(spotDirection, lightDirection);
    spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
    spotFade *= spotFade;

    float distanceSqr = max(dot(lightVector, lightVector), 0.00001);//方向向量dot结果为1，即衰减不影响方向光
    color *= shadowAttenuation * spotFade * rangeFade / distanceSqr;

    return color * lightColor;
}

VertexOutput LitPassVertex(VertexInput input) {
    VertexOutput o;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, o);
    float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
    o.clipPos = mul(unity_MatrixVP, worldPos);
#if defined(UNITY_ASSUME_UNIFORM_SCALING)
    o.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
#else
    o.normal = normalize(mul(input.normal, (float3x3)UNITY_MATRIX_I_M));
#endif
    o.worldPos = worldPos.xyz;
    LitSurface surface = GetLitSurfaceVertex(o.normal, o.worldPos);
    o.vertexLighting = 0;
    for (int i = 4; i < min(unity_LightIndicesOffsetAndCount.y, 8); i++) {
        int lightIdx = unity_4LightIndices1[i - 4];
        o.vertexLighting += GenericLight(lightIdx, surface, 1);
    }
    o.uv = TRANSFORM_TEX(input.uv, _MainTex);
    return o;
}

float4 LitPassFragment(VertexOutput input, FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(input);
    input.normal = normalize(input.normal);
    input.normal = IS_FRONT_VFACE(isFrontFace, input.normal, -input.normal);
    // float3 albedo = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color).rgb;
    float4 albedoAlpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    albedoAlpha *= UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color);

#if defined(_CLIPPING_ON)
    clip(albedoAlpha.a - _Cutoff);
#endif

    float3 viewDir = normalize(_WorldSpaceCameraPos - input.worldPos.xyz);
    LitSurface surface = GetLitSurface(input.normal, input.worldPos, viewDir, albedoAlpha.rgb, 
        UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Metallic),
        UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Smoothness));

    float3 color = input.vertexLighting * surface.diffuse;

#if defined(_CASCADED_SHADOWS_HARD) || defined(_CASCADED_SHADOWS_SOFT)
    color += MainLight(surface);
#endif

    for (int i = 0; i < min(unity_LightIndicesOffsetAndCount.y, 4); i++) {
        int lightIdx = unity_4LightIndices0[i];
        float shadowAttenuation = ShadowAttenuation(lightIdx, input.worldPos);
        color += GenericLight(lightIdx, surface, shadowAttenuation);
    }
    // float3 color = diffuseLight * albedoAlpha.rgb;//input.normal;// * 0.5 + 0.5;
    color += ReflectEnvironment(surface, SampleEnvironment(surface));
    return float4(color, albedoAlpha.a);
}

#endif
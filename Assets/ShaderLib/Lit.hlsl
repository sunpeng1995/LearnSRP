#ifndef MYRP_LIT_INCLUDED
#define MYRP_LIT_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

CBUFFER_START(UnityPerFrame)
    float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
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
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#define MAX_VISIBLE_LIGHTS 4
CBUFFER_START(_LightBuffer)
    float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
CBUFFER_END

float3 DiffuseLight(int index, float3 normal, float3 worldPos) {
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
    float attenuation = spotFade * rangeFade / distanceSqr;
    diffuse *= attenuation;

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
    return o;
}

float4 LitPassFragment(VertexOutput input) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(input);
    input.normal = normalize(input.normal);
    float3 albedo = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color).rgb;
    float3 diffuseLight = 0;
    for (int i = 0; i < MAX_VISIBLE_LIGHTS; i++) {
        diffuseLight += DiffuseLight(i, input.normal, input.worldPos);
    }
    float3 color = diffuseLight * albedo;//input.normal;// * 0.5 + 0.5;
    return float4(color, 1);
}

#endif
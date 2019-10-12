Shader "MyPipeline/Lit"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 0, 1)
        _MainTex("Albedo & Alpha", 2D) = "white" {}
        [Toggle(_CLIPPING)]_Clipping("Alpha Clipping", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)]_Cull("Cull", Float) = 2
    }
    SubShader
    {
        Pass
        {
            Cull [_Cull]
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma multi_compile_instancing

            // 让Unity不传递model逆矩阵
            #pragma instancing_options assumeuniformscaling

            #pragma shader_feature _CLIPPING

            #pragma multi_compile _ _CASCADED_SHADOWS_HARD _CASCADED_SHADOWS_SOFT
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _SHADOWS_HARD

            #include "../ShaderLib/Lit.hlsl"
            ENDHLSL
        }

        Pass 
        {
            Tags { "LightMode" = "ShadowCaster" }
            Cull [_Cull]
            HLSLPROGRAM
            #pragma target 3.5
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling
            #pragma shader_feature _CLIPPING
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment
            #include "../ShaderLib/ShadowCaster.hlsl"
            ENDHLSL
        }
    }
}

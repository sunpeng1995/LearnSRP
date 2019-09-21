Shader "MyPipeline/Lit"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 0, 1)
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma multi_compile_instancing

            // 让Unity不传递model逆矩阵
            #pragma instancing_options assumeuniformscaling

            #include "../ShaderLib/Lit.hlsl"
            ENDHLSL
        }
    }
}

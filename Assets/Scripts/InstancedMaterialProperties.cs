using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InstancedMaterialProperties : MonoBehaviour
{
    [SerializeField]
    Color color = Color.white;

    [SerializeField, Range(0, 1)]
    float smoothness = 0.5f;

    [SerializeField, Range(0, 1)]
    float metallic;

    static MaterialPropertyBlock propertyBlock;
    static int colorID = Shader.PropertyToID("_Color");
    static int smoothnessID = Shader.PropertyToID("_Smoothness");
    static int metallicID = Shader.PropertyToID("_Metallic");

    void Start()
    {
        //color = new Color(Random.value, Random.value, Random.value);
        if (propertyBlock == null)
            propertyBlock = new MaterialPropertyBlock();
        propertyBlock.SetColor(colorID, color);
        propertyBlock.SetFloat(smoothnessID, smoothness);
        propertyBlock.SetFloat(metallicID, metallic);
        GetComponent<MeshRenderer>().SetPropertyBlock(propertyBlock);
    }
}

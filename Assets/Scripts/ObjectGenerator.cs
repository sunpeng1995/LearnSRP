using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObjectGenerator : MonoBehaviour
{
    public int ObjectCount = 30;
    public Material[] material;
    public bool randomShape = false;

    void Start()
    {
        for (int i = 0; i < ObjectCount; i++)
        {
            GameObject go;
            if (randomShape)
                go = GameObject.CreatePrimitive(Random.value > 0.5 ? PrimitiveType.Cube : PrimitiveType.Sphere);
            else
                go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = "Object " + i;
            go.transform.position = transform.position +
                new Vector3(Random.Range(-5, 5), Random.Range(-2.5f, 2.5f), Random.Range(-5, 5));
            go.transform.rotation = Quaternion.Euler(new Vector3(Random.Range(-180, 180), Random.Range(-180, 180), Random.Range(-180, 180)));
            var scale = Random.Range(0.5f, 2);
            go.transform.localScale = new Vector3(scale, scale, scale);

            var renderer = go.GetComponent<MeshRenderer>();
            renderer.material = material[0];

            go.AddComponent<InstancedColor>();
        }
    }

}

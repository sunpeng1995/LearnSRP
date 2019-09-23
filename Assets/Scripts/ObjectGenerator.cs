using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObjectGenerator : MonoBehaviour
{
    public int ObjectCount = 30;
    public Material[] material;
    public bool randomShape = false;
    public PrimitiveType defaultPrimitiveType = PrimitiveType.Sphere;
    public bool randomTransform = false;

    void Start()
    {
        if (!randomTransform)
            ObjectCount = 81;

        for (int i = 0; i < ObjectCount; i++)
        {
            GameObject go;
            if (randomShape)
                go = GameObject.CreatePrimitive(Random.value > 0.5 ? PrimitiveType.Cube : PrimitiveType.Sphere);
            else
                go = GameObject.CreatePrimitive(defaultPrimitiveType);
            go.name = "Object " + i;
            if (randomTransform)
            {
                go.transform.position = transform.position +
                    new Vector3(Random.Range(-5, 5), Random.Range(-2.5f, 2.5f), Random.Range(-5, 5));
                go.transform.rotation = Quaternion.Euler(new Vector3(Random.Range(-180, 180), Random.Range(-180, 180), Random.Range(-180, 180)));
                var scale = Random.Range(0.5f, 2);
                go.transform.localScale = new Vector3(scale, scale, scale);
            }
            else
            {
                go.transform.position = new Vector3((i / 9) * 2, 0, (i % 9) * 2);
            }

            var renderer = go.GetComponent<MeshRenderer>();
            renderer.material = material[0];

            go.AddComponent<InstancedColor>();
        }
    }

}

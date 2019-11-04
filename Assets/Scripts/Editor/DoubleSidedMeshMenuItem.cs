using UnityEditor;
using UnityEngine;

public static class DoubleSidedMeshMenuItem
{
    // 创建双面网格的脚本，用于双面透明物件
    [MenuItem("Assets/Create/Double-Sided Mesh")]
    static void MakeDoubleSidedMeshAsset()
    {
        var sourceMesh = Selection.activeObject as Mesh;
        if (sourceMesh == null)
        {
            Debug.LogError("You must select a mesh asset");
            return;
        }

        Mesh insideMesh = Object.Instantiate(sourceMesh);

        var triangles = insideMesh.triangles;
        System.Array.Reverse(triangles);
        insideMesh.triangles = triangles;

        var normals = insideMesh.normals;
        for (int i = 0; i < normals.Length; i++)
        {
            normals[i] = -normals[i];
        }
        insideMesh.normals = normals;

        var combinedMesh = new Mesh();
        combinedMesh.CombineMeshes(
            new CombineInstance[]
            {
                new CombineInstance{mesh = insideMesh},
                new CombineInstance{mesh = sourceMesh}
            }, true, false, false
        );

        Object.DestroyImmediate(insideMesh);

        AssetDatabase.CreateAsset(combinedMesh, System.IO.Path.Combine("Assets", sourceMesh.name + " Double-Sided.asset"));
    }

    [MenuItem("Assets/Create/Sphere")]
    static void Sphere()
    {
        var sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        var mesh = sphere.GetComponent<MeshFilter>().mesh;
        AssetDatabase.CreateAsset(mesh, "Assets/Sphere.asset");
        Object.DestroyImmediate(sphere);
    }
}

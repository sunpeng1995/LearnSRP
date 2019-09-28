using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Pipeline")]
public class MyPipelineAsset : RenderPipelineAsset
{
    public enum ShadowCascades
    {
        Zero = 0,
        Two = 2,
        Four = 4
    }
    public enum ShadowMapSize
    {
        _256 = 256,
        _512 = 512,
        _1024 = 1024,
        _2048 = 2048,
        _4096 = 4096
    }
    [SerializeField]
    ShadowMapSize shadowMapSize = ShadowMapSize._1024;
    [SerializeField]
    float shadowDistance = 100f;
    [SerializeField]
    bool dynamicBatching;
    [SerializeField]
    bool instancing;

    [SerializeField]
    ShadowCascades shadowCascades = ShadowCascades.Four;
    [SerializeField, HideInInspector]
    float twoCascadeSplit = 0.25f;
    [SerializeField, HideInInspector]
    Vector3 fourCascadeSplit = new Vector3(0.067f, 0.2f, 0.467f);

    protected override IRenderPipeline InternalCreatePipeline()
    {
        Vector3 shadowCascadeSplit = shadowCascades == ShadowCascades.Four ?
            fourCascadeSplit : new Vector3(twoCascadeSplit, 0);
        return new MyPipeline(dynamicBatching, instancing, (int)shadowMapSize, shadowDistance, 
            (int)shadowCascades, shadowCascadeSplit);
    }
}

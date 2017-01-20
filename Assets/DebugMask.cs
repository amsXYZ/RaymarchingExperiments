using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class DebugMask : MonoBehaviour {

    [SerializeField]
    private TerrainBooleanManager _manager;

    [SerializeField, Range(0, 3)]
    private int _slice;

    public bool enabled = false;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (enabled)
        {
            Material mat = new Material(Shader.Find("Hidden/Test"));
            mat.SetInt("_Slice", _slice);
            Graphics.Blit(_manager.FrontFacesRT, destination, mat);
        }
        else Graphics.Blit(source, destination);
    }
}

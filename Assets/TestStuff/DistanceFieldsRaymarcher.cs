using UnityEngine;
using System.Collections;

[RequireComponent(typeof(Camera)),ExecuteInEditMode]
#if UNITY_5_4_OR_NEWER
[ImageEffectAllowedInSceneView]
#endif
public class DistanceFieldsRaymarcher : MonoBehaviour {

	public float precision;

	private Material _material;

	void Start(){
		_material = new Material (Shader.Find ("Hidden/DistanceFieldsRaymarcher"));
	}

	void Update(){
		//Debug.Log (GetComponent<Camera> ().worldToCameraMatrix);
	}

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if(!_material) _material = new Material (Shader.Find ("Hidden/DistanceFieldsRaymarcher"));

		_material.SetFloat ("_Precision", precision);
		_material.SetFloat("_OrtSize", GetComponent<Camera>().orthographicSize);
		_material.SetFloat("_VFOV", GetComponent<Camera>().fieldOfView);
		_material.SetVector("f", transform.forward);
		_material.SetVector("u", transform.up);
		_material.SetVector("r", transform.right);

        // Transfer the skybox parameters.
        var skybox = RenderSettings.skybox;
        _material.SetTexture("_SkyCubemap", skybox.GetTexture("_Tex"));
        _material.SetColor("_SkyTint", skybox.GetColor("_Tint"));
        _material.SetFloat("_SkyExposure", skybox.GetFloat("_Exposure"));
        _material.SetFloat("_SkyRotation", skybox.GetFloat("_Rotation"));

        Graphics.Blit (src, dest, _material);
	}
}

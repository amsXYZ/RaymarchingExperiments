using UnityEngine;

[RequireComponent(typeof(Camera)), ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class TerrainRaymarching : MonoBehaviour
{

	[Range(1, 5)]
	public int downsampling = 1;

	[Space]
	public float precision = 0.02f;

	[Space]
	public float frequency = 0.000375f;
	public float lacunarity = 2;
	[Range(0, 1)]
	public float persistence = 0.5f;
	[Range(1, 16)]
	public int octaves = 1;
	[Range(0, 1)]
	public float billowy = 1;
	[Range(0, 1)]
	public float inverse = 0;

	[Space]
	public float intensity = 100;

	[Space]
	public Texture2D whiteNoise;
	public Texture2D detailNoise;

	[Space, Range(1, 256)]
	public float shadowSharpness;

	[Space]
	public Color bottom;
	public Color top;

	private Material _material;

	void Start()
	{
		_material = new Material(Shader.Find("Hidden/TerrainRaymarching"));
	}

	void Update()
	{
		//Debug.Log (GetComponent<Camera> ().worldToCameraMatrix);
	}

	void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if (!_material)
			_material = new Material(Shader.Find("Hidden/TerrainRaymarching"));

		_material.SetFloat("_Precision", precision);
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

		// Noise
		_material.SetFloat("_Frequency", frequency);
		_material.SetFloat("_Lacunarity", lacunarity);
		_material.SetFloat("_Persistence", persistence);
		_material.SetFloat("_Octaves", octaves);
		_material.SetFloat("_Billowy", billowy);
		_material.SetFloat("_Inverse", inverse);

		_material.SetTexture("_WhiteNoise", whiteNoise);
		_material.SetTexture("_DetailNoise", detailNoise);

		_material.SetFloat("_Intensity", intensity);

		_material.SetFloat("_ShadowSharpness", shadowSharpness);

		_material.SetColor("_BottomColor", bottom);
		_material.SetColor("_TopColor", top);

		Graphics.Blit(src, dest, _material, 0);
	}
}

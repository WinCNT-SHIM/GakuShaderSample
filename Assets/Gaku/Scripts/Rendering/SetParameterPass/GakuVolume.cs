using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace Gaku
{
    [Serializable]
    [VolumeComponentMenu("GakuVolume")]
    public class GakuVolume : VolumeComponent
    {
        public void SetSH2()
        {
            DynamicGI.UpdateEnvironment();
            SH2.value = RenderSettings.ambientProbe;
        }
        
        [Header("Skybox & ReflectionProbe")]
        public MaterialParameter _skyboxMaterial = new(null);
        public ClampedFloatParameter _skyboxIntensity = new(1f, 0f, 8f);
        public CubemapParameter _reflectionProbe = new(null);
        
        [Header("Spherical Harmonics L2")]
        public SH2Parameter SH2 = new(new SphericalHarmonicsL2());
        
        [Header("Global Variables")]
        // var dir = -DirectionalLight.transform.forward;
        public FloatParameter _SkinSaturation = new FloatParameter(1.0f);
        // public ColorParameter _MatCapLightColor = DirectionalLight.color;
        public ColorParameter _MatCapLightColor = new ColorParameter(Color.white, hdr: true, showAlpha: true, showEyeDropper: true);
        public ColorParameter _MatCapRimColor = new ColorParameter(Color.black, hdr: true, showAlpha: true, showEyeDropper: true);
        public ColorParameter _VLSpecColor = new ColorParameter(Color.white, hdr: true, showAlpha: true, showEyeDropper: true);
        public Vector4Parameter _MatCapParam = new Vector4Parameter(Vector4.zero);
        // Shader.SetGlobalVector("_MatCapMainLight", -DirectionalLight.transform.forward);
        // Shader.SetGlobalVector("_MatCapMainLight", new Vector4(NormalizedLight.x, NormalizedLight.y, NormalizedLight.z, MainLightDirection.w));
        // Shader.SetGlobalVector("_MatCapRimLight", MatCapRimLight);
        // // Shader.SetGlobalVector("_HeadDirection", Face.transform.forward);
        // // Shader.SetGlobalVector("_HeadUpDirection", Face.transform.up);
        // // public ColorParameter _EyeHightlightColor = new ColorParameter(Color.white, hdr: true, showAlpha: true, showEyeDropper: true);
        // // public FloatParameter _OutlineParam = new FloatParameter(0.2f);
        public Vector4Parameter _FadeParam = new Vector4Parameter(Vector4.zero);
    }
    
    [Serializable]
    public class SH2Parameter : VolumeParameter<SphericalHarmonicsL2>
    {
        public SH2Parameter(SphericalHarmonicsL2 value, bool overrideState = false) : base(value, overrideState)
        {
        }
    }
}
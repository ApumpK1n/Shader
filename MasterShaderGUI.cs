using UnityEngine;
using UnityEditor;
using System;
using System.Collections.Generic;
using System.Linq;


public class MasterShaderGUI : ShaderGUI
{
    enum BlendType { Opaque, Transparent, Additive, Cutout, BlendAdd, BlendAddColorAlpha }
    enum HueType { Multiply, Linear, Add }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material material = materialEditor.target as Material;
        List<string> handledPropertyNames = new List<string>();
        Blending();
        Stencil();
        RenderToggleWithProperties("_VerticalFog", "Vertical Fog", "VERTICAL_FOG", new[] { "_VerticalFogY", "_VerticalFogHeight", "_VerticalFogColor" });
        bool hasTexture = RenderToggleWithProperties("_HasTexture", "Has Texture", "TEXTURE", new[] { "_MainTex" });
        if (hasTexture)
        {
            RenderToggleWithProperties("_HasSecondaryTexture", "Has Secondary Texture", "SECONDARY_TEXTURE", new[] { "_SecondaryTex" });
            RenderToggleWithProperties("_HasAlphaTexture", "Has Alpha Texture", "ALPHA_TEXTURE", new[] { "_AlphaTex" });
        }
        else
        {
            handledPropertyNames.Add("_SecondaryTex");
            handledPropertyNames.Add("_HasSecondaryTexture");
            handledPropertyNames.Add("_AlphaTex");
            handledPropertyNames.Add("_HasAlphaTexture");
            RenderToggleWithProperties("_HasAlphaTexture", "Has Alpha Texture", "ALPHA_TEXTURE", new[] { "_MainTex" });
        }

        Hue();

        EditorGUILayout.Space();

        var renderedProperties = properties.Join(handledPropertyNames, v => v.name, v => v, (v, _) => v);
        foreach (var remainingProperty in properties.Except(renderedProperties))
        {
            RenderProperty(remainingProperty);
        }

        EditorGUILayout.Space();

        materialEditor.RenderQueueField();

        bool RenderToggleWithProperties(string name, string displayName, string keyword, string[] propertyNames = null)
        {
            handledPropertyNames.Add(name);
            if (propertyNames != null)
                handledPropertyNames.AddRange(propertyNames);

            bool isPropertyOn = material.GetInt(name) == 1;
            EditorGUI.BeginChangeCheck();
            isPropertyOn = EditorGUILayout.Toggle(displayName, isPropertyOn);
            if (isPropertyOn && propertyNames != null)
            {
                foreach (var property in properties.Join(propertyNames, v => v.name, v => v, (v, _) => v))
                    RenderProperty(property);
                EditorGUILayout.Space();
            }
            if (EditorGUI.EndChangeCheck())
            {
                UnityEditor.Undo.RecordObject(material, "Change Material");
                material.SetInt(name, isPropertyOn ? 1 : 0);
                if (isPropertyOn)
                    material.EnableKeyword(keyword);
                else
                    material.DisableKeyword(keyword);
            }

            return isPropertyOn;

        }

        void RenderProperty(MaterialProperty property)
        {
            float h = materialEditor.GetPropertyHeight(property, property.displayName);
            Rect r = EditorGUILayout.GetControlRect(true, h, EditorStyles.layerMaskField);

            materialEditor.ShaderProperty(r, property, property.displayName);
        }

        void Stencil()
        {
            bool hasHoles = material.GetInt("_StencilComp") == (int)UnityEngine.Rendering.CompareFunction.Equal;
            EditorGUI.BeginChangeCheck();
            hasHoles = EditorGUILayout.Toggle("Stencil Holes", hasHoles);
            if (EditorGUI.EndChangeCheck())
            {
                UnityEditor.Undo.RecordObject(material, "Change Material");
                if (hasHoles)
                {
                    material.SetInt("_StencilComp", (int)UnityEngine.Rendering.CompareFunction.Equal);
                    material.SetInt("_Stencil", 0);
                }
                else
                {
                    material.SetInt("_StencilComp", (int)UnityEngine.Rendering.CompareFunction.Always);
                }
            }

            handledPropertyNames.Add("_StencilCompare");
        }

        void Blending()
        {
            handledPropertyNames.Add("_ZWrite");
            // handledPropertyNames.Add("_CullMode");
            handledPropertyNames.Add("_DstBlend");
            handledPropertyNames.Add("_SrcBlend");
            handledPropertyNames.Add("_CutOff");

            BlendType blendType = BlendType.Opaque;
            if (Array.IndexOf(material.shaderKeywords, "ADDITIVE") != -1) blendType = BlendType.Additive;
            else if (Array.IndexOf(material.shaderKeywords, "COLOR_IS_ALPHA") != -1) blendType = BlendType.BlendAddColorAlpha;
            else if (Array.IndexOf(material.shaderKeywords, "BLEND_ADD") != -1) blendType = BlendType.BlendAdd;
            else if (Array.IndexOf(material.shaderKeywords, "TRANSPARENT") != -1) blendType = BlendType.Transparent;
            else if (Array.IndexOf(material.shaderKeywords, "CUTOUT") != -1) blendType = BlendType.Cutout;

            EditorGUI.BeginChangeCheck();

            blendType = (BlendType)EditorGUILayout.Popup("Blend", (int)blendType, new[] { "Opaque", "Transparent", "Additive", "Cutout", "BlendAdd", "BlendAdd (ColorAlpha)" });

            if (EditorGUI.EndChangeCheck())
            {
                UnityEditor.Undo.RecordObject(material, "Change Material");

                // NOTE: Disable all flags, then enable then as needed
                material.DisableKeyword("TRANSPARENT");
                material.DisableKeyword("ADDITIVE");
                material.DisableKeyword("BLEND_ADD");
                material.DisableKeyword("COLOR_IS_ALPHA");
                material.DisableKeyword("CUTOUT");
                material.DisableKeyword("ADDITIVE");

                if (blendType == BlendType.Transparent || blendType == BlendType.Additive || blendType == BlendType.BlendAdd || blendType == BlendType.BlendAddColorAlpha)
                {
                    material.SetOverrideTag("RenderType", "Transparent");
                    if (blendType == BlendType.BlendAdd || blendType == BlendType.BlendAddColorAlpha)
                    {
                        material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                        material.EnableKeyword("BLEND_ADD");
                        if (blendType == BlendType.BlendAddColorAlpha)
                        {
                            material.EnableKeyword("COLOR_IS_ALPHA");
                        }
                    }
                    else
                    {
                        material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    }

                    if (blendType == BlendType.Additive)
                    {
                        material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    }
                    else
                    {
                        material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    }
                    material.SetInt("_ZWrite", 0);
                    material.SetInt("_CullMode", (int)UnityEngine.Rendering.CullMode.Off);
                    material.EnableKeyword("TRANSPARENT");
                    if (blendType == BlendType.Additive)
                    {
                        material.EnableKeyword("ADDITIVE");
                    }
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                }
                else if (blendType == BlendType.Cutout)
                {
                    material.SetOverrideTag("RenderType", "AlphaTest");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 1);
                    material.SetInt("_CullMode", (int)UnityEngine.Rendering.CullMode.Off);
                    material.EnableKeyword("CUTOUT");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                }
                else if (blendType == BlendType.Opaque)
                {
                    material.SetOverrideTag("RenderType", "Opaque");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 1);
                    material.SetInt("_CullMode", (int)UnityEngine.Rendering.CullMode.Back);
                    material.renderQueue = -1;
                }
            }

            if (blendType == BlendType.Cutout)
            {
                RenderProperty(Array.Find(properties, (v => v.name == "_CutOff")));
            }
        }

        void Hue()
        {
            handledPropertyNames.Add("_Color");

            HueType hueType;
            if (Array.IndexOf(material.shaderKeywords, "HUE_ADD") != -1) hueType = HueType.Add;
            else if (Array.IndexOf(material.shaderKeywords, "HUE_LINEAR") != -1) hueType = HueType.Linear;
            else hueType = HueType.Multiply;

            EditorGUI.BeginChangeCheck();

            hueType = (HueType)EditorGUILayout.Popup("Hue", (int)hueType, new[] { "Multiply", "Linear", "Additive"});

            if (EditorGUI.EndChangeCheck())
            {
                material.DisableKeyword("HUE_MULTIPLY");
                material.DisableKeyword("HUE_LINEAR");
                material.DisableKeyword("HUE_ADD");

                switch (hueType)
                {
                    case HueType.Multiply: material.EnableKeyword("HUE_MULTIPLY"); break;
                    case HueType.Linear: material.EnableKeyword("HUE_LINEAR"); break;
                    case HueType.Add: material.EnableKeyword("HUE_ADD"); break;
                }
            }

            var colorProperty = Array.Find(properties, v => v.name == "_Color");
            RenderProperty(colorProperty);
        }
    }

    void RenderProperty(MaterialEditor materialEditor, MaterialProperty property)
    {
        float h = materialEditor.GetPropertyHeight(property, property.displayName);
        Rect r = EditorGUILayout.GetControlRect(true, h, EditorStyles.layerMaskField);

        materialEditor.ShaderProperty(r, property, property.displayName);
    }
}

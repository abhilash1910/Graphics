// Upgrade NOTE: replaced 'defined at' with 'defined (at)'
#ifndef SHADERPASS
#error SHADERPASS must be defined (at) this point
#endif

// Make VFX only sample probe volumes as SH0 for performance.
//TODOPAUL : Check this implementation in URP
//#define PROBE_VOLUMES_SAMPLING_MODE PROBEVOLUMESENCODINGMODES_SPHERICAL_HARMONICS_L0

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

float3 VFXGetPositionRWS(VFX_VARYING_PS_INPUTS i)
{
    float3 posWS = (float3)0;
    #ifdef VFX_VARYING_POSWS
    posWS = i.VFX_VARYING_POSWS;
    #endif
    return VFXGetPositionRWS(posWS);
}

//TODOPAUL : Remove surfaceData & opacity (and probably VFXUVData)
InputData VFXGetInputData(const VFX_VARYING_PS_INPUTS i, const PositionInputs posInputs, const SurfaceData surfaceData, const VFXUVData uvData, float3 normalWS, float opacity)
{
    InputData inputData = (InputData)0;

    inputData.positionWS = posInputs.positionWS.xyz;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = inputData.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.VFX_VARYING_POSCS);
    return inputData;
}


#ifndef VFX_SHADERGRAPH

SurfaceData VFXGetSurfaceData(const VFX_VARYING_PS_INPUTS i, float3 normalWS, const VFXUVData uvData, out float opacity)
{
    SurfaceData surfaceData = (SurfaceData)0;

    float4 color = float4(1,1,1,1);
    #if URP_USE_BASE_COLOR
    color *= VFXGetParticleColor(i);
    #elif URP_USE_ADDITIONAL_BASE_COLOR
    #if defined(VFX_VARYING_COLOR)
    color.xyz *= i.VFX_VARYING_COLOR;
    #endif
    #if defined(VFX_VARYING_ALPHA)
    color.a *= i.VFX_VARYING_ALPHA;
    #endif
    #endif
    #if URP_USE_BASE_COLOR_MAP
    float4 colorMap = SampleTexture(VFX_SAMPLER(baseColorMap),uvData);
    #if URP_USE_BASE_COLOR_MAP_COLOR
    color.xyz *= colorMap.xyz;
    #endif
    #if URP_USE_BASE_COLOR_MAP_ALPHA
    color.a *= colorMap.a;
    #endif
    #endif
    color.a *= VFXGetSoftParticleFade(i);
    VFXClipFragmentColor(color.a,i);
    surfaceData.albedo = saturate(color.rgb);

    #if IS_OPAQUE_PARTICLE
    opacity = 1.0f;
    #else
    opacity = saturate(color.a);
    #endif
    surfaceData.alpha = opacity;

    #if URP_MATERIAL_TYPE_METALLIC
    #ifdef VFX_VARYING_METALLIC
    surfaceData.metallic = i.VFX_VARYING_METALLIC;
    #endif
    #elif URP_MATERIAL_TYPE_SPECULAR
    #ifdef VFX_VARYING_SPECULAR
    surfaceData.specular = saturate(i.VFX_VARYING_SPECULAR);
    #endif
    #endif

    surfaceData.normalTS = float3(1.0f, 0.0f, 0.0f); //NormalWS is directly modified in VFX
    #ifdef VFX_VARYING_SMOOTHNESS
    surfaceData.smoothness = i.VFX_VARYING_SMOOTHNESS;
    #endif
    surfaceData.occlusion = 1.0f;

    #if URP_USE_MASK_MAP
    float4 mask = SampleTexture(VFX_SAMPLER(maskMap),uvData);
    surfaceData.metallic *= mask.r;
    surfaceData.occlusion *= mask.g;
    surfaceData.smoothness *= mask.a;
    #endif

    #if URP_USE_EMISSIVE
    surfaceData.emission = float3(1, 1, 1);
    #if URP_USE_EMISSIVE_MAP
    float emissiveScale = 1.0f;
    #ifdef VFX_VARYING_EMISSIVESCALE
    emissiveScale = i.VFX_VARYING_EMISSIVESCALE;
    #endif
    surfaceData.emission *= SampleTexture(VFX_SAMPLER(emissiveMap), uvData).rgb * emissiveScale;
    #endif
    #if defined(VFX_VARYING_EMISSIVE) && (URP_USE_EMISSIVE_COLOR || URP_USE_ADDITIONAL_EMISSIVE_COLOR)
    surfaceData.emission *= i.VFX_VARYING_EMISSIVE;
    #endif
    #ifdef VFX_VARYING_EXPOSUREWEIGHT
    surfaceData.emission *= lerp(GetInverseCurrentExposureMultiplier(), 1.0f, i.VFX_VARYING_EXPOSUREWEIGHT);
    #endif
    surfaceData.emission *= opacity;
    #endif

    return surfaceData;
}


#endif

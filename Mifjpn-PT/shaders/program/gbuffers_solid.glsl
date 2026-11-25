// Mifjpn-PT | Opaque G-Buffer Pass
// SPDX-License-Identifier: MIT
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/waves.glsl"
#include "/lib/sky.glsl"
#include "/lib/wetness.glsl"
#include "/lib/pbr.glsl"

varying vec2  vTexCoord;
varying vec2  vLightMap;
varying vec4  vColor;
varying vec3  vNormal;
varying vec3  vTangent;
varying vec3  vBinormal;
varying float vMatID;
varying vec3  vWorldPos;
varying vec3  vViewPos;
varying vec4  vTileBounds;

vec3 safeUnit(vec3 v, vec3 fallback) {
    float len2 = dot(v, v);
    return len2 > 1e-6 ? (v * inversesqrt(len2)) : fallback;
}

#ifdef VSH
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

#if defined ENTITIES && !defined SNOW_ID_VIA_ATTRIBUTE
uniform int entityId;
#endif

void main() {
    vTexCoord  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 rawLM = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vLightMap  = saturate((rawLM - 0.03125) * 1.06667);
    vColor     = gl_Color;

    vNormal   = safeUnit(gl_NormalMatrix * gl_Normal, vec3(0.0, 0.0, 1.0));
    vTangent  = safeUnit(gl_NormalMatrix * at_tangent.xyz, vec3(1.0, 0.0, 0.0));
    vBinormal = safeUnit(gl_NormalMatrix * (cross(at_tangent.xyz, gl_Normal) * sign(at_tangent.w)), vec3(0.0, 1.0, 0.0));

#if defined TERRAIN
    vMatID = mc_Entity.x > 9999.5 ? (mc_Entity.x - 10000.0) : MAT_NONE;
#elif defined HAND
    vMatID = MAT_HAND;
#elif defined ENTITIES
    bool physSnow = abs(mc_Entity.x - float(PHYSICS_SNOW_ID)) < 0.5;
    #ifndef SNOW_ID_VIA_ATTRIBUTE
    physSnow = physSnow || (entityId == PHYSICS_SNOW_ID);
    #endif
    vMatID = physSnow ? MAT_SNOW : MAT_ENTITY;
#else
    vMatID = MAT_NONE;
#endif

    vViewPos    = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec4 relPos = gbufferModelViewInverse * vec4(vViewPos, 1.0);
    vWorldPos   = relPos.xyz + cameraPosition;

#ifdef ENTITIES
    vec2  eyeLM = saturate(vec2(eyeBrightnessSmooth) * (1.0 / 240.0));
    float proxW = 1.0 - smoothstep(2.5, 7.0, length(relPos.xyz));
    vLightMap   = max(vLightMap, eyeLM * (proxW * 0.85));
#endif

#if defined TERRAIN
    vec2 centerUV = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
    vec2 halfExt  = abs(vTexCoord - centerUV);
    vTileBounds   = vec4(centerUV - halfExt, halfExt * 2.0);
#else
    vTileBounds   = vec4(0.0, 0.0, 1.0, 1.0);
#endif

#if defined TERRAIN && defined WAVING_PLANTS
    if (abs(vMatID - MAT_LEAVES) < 0.5) relPos.xyz += windOffset(vWorldPos, 0.6);
    else if (abs(vMatID - MAT_PLANT) < 0.5 && vTexCoord.y < mc_midTexCoord.y) relPos.xyz += windOffset(vWorldPos, 1.0);
    gl_Position = gl_ProjectionMatrix * (gbufferModelView * relPos);
#else
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
#endif
}
#endif

#ifdef FSH
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform ivec2     atlasSize;

/* DRAWBUFFERS:0126 */
void main() {
    float matCode = floor(vMatID + 0.5);
    vec3 N = safeUnit(vNormal,   vec3(0.0, 0.0, 1.0));
    vec3 T = safeUnit(vTangent,  vec3(1.0, 0.0, 0.0));
    vec3 B = safeUnit(vBinormal, vec3(0.0, 1.0, 0.0));

#ifdef ENTITIES
    if (!gl_FrontFacing) N = -N;
#endif

    vec2 uv    = vTexCoord;
    vec2 gradX = dFdx(vTexCoord);
    vec2 gradY = dFdy(vTexCoord);

#ifdef MIFJPN_POM
    float camDist = length(vViewPos);
    if (camDist < POM_DISTANCE && matCode != MAT_PLANT && matCode != MAT_LAVA) {
        vec3  tsRay   = vec3(dot(vViewPos, T), dot(vViewPos, B), dot(vViewPos, N));
        float pomFade = 1.0 - smoothstep(POM_DISTANCE * 0.6, POM_DISTANCE, camDist);
        uv = parallaxUV(normals, vTexCoord, vTileBounds, tsRay, gradX, gradY, pomFade);
    }
#endif

    vec4 baseSample = pbrSample(texture, uv, gradX, gradY);
#ifdef TERRAIN
    baseSample.rgb *= vColor.rgb;
    float surfAO    = vColor.a;
#else
    baseSample     *= vColor;
    float surfAO    = 1.0;
#endif
    if (baseSample.a < 0.1) discard;

#ifdef ENTITIES
    baseSample.rgb = mix(baseSample.rgb, entityColor.rgb, entityColor.a);
    #if defined NETHER
    baseSample.rgb *= vec3(0.50, 0.39, 0.37);
    #endif
#endif

    float smoothness = 0.0, f0Code = 0.02, emission = 0.0, porosity = PBR_DEFAULT_POROSITY, sssAmt = 0.0;
    vec3  tsN     = vec3(0.0, 0.0, 1.0);
    bool  useBump = false;

#if defined LABPBR && !defined ENTITIES && !defined HAND
    float pbrAO = 1.0;
    useBump = decodeNormalMap(pbrSample(normals, uv, gradX, gradY), tsN, pbrAO);
    surfAO *= pbrAO;
    decodeSpecular(pbrSample(specular, uv, gradX, gradY), smoothness, f0Code, emission, porosity, sssAmt);
#endif

#if defined GENERATED_NORMALS && defined TERRAIN
    vec2 atlasDim = vec2(atlasSize);
    if (!useBump && atlasDim.x > 1.0 && matCode != MAT_PLANT && matCode != MAT_LAVA) {
        tsN     = generatedNormal(texture, uv, vTileBounds, 1.0 / atlasDim, gradX, gradY);
        useBump = true;
    }
#endif

    if (useBump) {
        vec2  refDim    = atlasSize.x > 0 ? vec2(atlasSize) : vec2(64.0);
        float footprint = max(length(gradX * refDim), length(gradY * refDim));
        tsN = normalize(mix(vec3(0.0, 0.0, 1.0), tsN, 1.0 - smoothstep(0.5, 1.5, footprint)));
        N   = normalize(T * tsN.x + B * tsN.y + N * tsN.z);
    }

#if defined ENTITIES || defined HAND
    emission = 0.0;
#endif

    if      (matCode == MAT_METAL)    { smoothness = max(smoothness, 0.72); if (f0Code < 0.9) f0Code = 0.95; }
    else if (matCode == MAT_POLISHED) { smoothness = max(smoothness, 0.62); f0Code = max(f0Code, 0.04); }
    else if (matCode == MAT_GLASS)    { smoothness = max(smoothness, 0.93); f0Code = max(f0Code, 0.04); }
    else if (matCode == MAT_SNOW)     { smoothness = max(smoothness, 0.18); f0Code = max(f0Code, 0.04); }
    else if (matCode == MAT_EMISSIVE) { emission = max(emission, smoothstep(0.45, 0.85, max(baseSample.r, max(baseSample.g, baseSample.b)))); }
    else if (matCode == MAT_LAVA)     { emission = 1.0; }

#if defined NETHER && defined NETHER_LAVA
    if (matCode == MAT_LAVA) {
        float fw      = max(fwidth(vWorldPos.x), max(fwidth(vWorldPos.y), fwidth(vWorldPos.z)));
        vec4  crust   = netherLava(vWorldPos, (mat3(gbufferModelViewInverse) * safeUnit(vNormal, vec3(0.0, 0.0, 1.0))).y, luma(baseSample.rgb), smoothstep(0.25, 0.90, fw));
        baseSample.rgb = crust.rgb;
        emission       = crust.a;
    }
#endif

#if defined TERRAIN && defined RAIN_PUDDLES && !defined NETHER && !defined END
    bool canWet = (matCode != MAT_PLANT && matCode != MAT_LEAVES && matCode != MAT_EMISSIVE && matCode != MAT_LAVA && matCode != MAT_SNOW && matCode != MAT_GLASS);
    if ((wetness > 0.002 || rainStrength > 0.01) && canWet) {
        vec3       geomWorldN = mat3(gbufferModelViewInverse) * safeUnit(vNormal, vec3(0.0, 0.0, 1.0));
        WetSurface wet        = evalWetSurface(vWorldPos, geomWorldN, vLightMap.y, pixelFootprint(length(vWorldPos - cameraPosition)));

        baseSample.rgb  = pow(baseSample.rgb, vec3(1.0 + mix(0.3, 0.9, porosity) * wet.wet));
        baseSample.rgb *= (1.0 - 0.40 * wet.puddle) * (1.0 - 0.20 * wet.film * (1.0 - wet.puddle));

        float coatGloss = mix(0.50, mix(0.90, 0.64, porosity), wet.film);
        smoothness      = mix(mix(smoothness, max(smoothness, coatGloss), wet.wet * mix(0.6, 1.0, wet.film)), 0.97, wet.puddle);
        f0Code          = mix(f0Code, 0.02, wet.puddle);

        vec3 flatWaterN = normalize(mat3(gbufferModelView) * vec3(-wet.ripple.x, 1.0, -wet.ripple.y));
        N = normalize(mix(N, flatWaterN, wet.puddle));
        N = normalize(N + (mat3(gbufferModelView) * vec3(-wet.ripple.x, 0.0, -wet.ripple.y)) * (1.0 - wet.puddle));

        baseSample.rgb = mix(baseSample.rgb, vec3(0.80, 0.84, 0.88), wet.splash * 0.75);
        smoothness     = mix(smoothness, 0.25, wet.splash * 0.8);
    }
#endif

    gl_FragData[0] = vec4(baseSample.rgb, 1.0);
    gl_FragData[1] = vec4(encodeNormal(N), vLightMap);
    gl_FragData[2] = vec4(smoothness, f0Code, emission, 1.0);
    gl_FragData[3] = vec4(surfAO, matCode / 255.0, sssAmt, 1.0);
}
#endif

// Mifjpn-PT | Deferred Pass 2: Direct + Indirect Surface Shading & Sky Synthesis
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/gi.glsl"
#include "/lib/sky.glsl"
#include "/lib/wetness.glsl"
#include "/lib/water.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"

varying vec2 texcoord;

#ifdef VSH
void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    texcoord    = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex10;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;

vec3 reconstructIndirectGI(vec2 uv, float linDepth, vec3 viewN) {
    vec2 res = giRes();
#ifdef GI_HALF_RES
    vec2  grid      = uv * res - 0.5;
    vec2  baseCell  = floor(grid);
    vec2  fracUV    = grid - baseCell;
    vec3  accum     = vec3(0.0);
    float wSum      = 0.0;
    float invZScale = 1.0 / (linDepth * 0.05 + 0.05);

    for (int i = 0; i < 4; ++i) {
        vec2 off  = vec2(mod(float(i), 2.0), floor(float(i) * 0.5));
        vec2 cell = clamp(baseCell + off, vec2(0.0), res - 1.0);
        vec4 giS  = texture2D(colortex4, (cell + 0.5) / res);
        vec3 repN = decodeNormal(texture2D(colortex1, (cell * 2.0 + 1.5) / fullRes()).xy);

        float wBilin  = (off.x > 0.5 ? fracUV.x : (1.0 - fracUV.x)) * (off.y > 0.5 ? fracUV.y : (1.0 - fracUV.y));
        float wDepth  = exp(-abs(giS.a - linDepth) * invZScale) * step(1e-4, giS.a);
        float w       = wBilin * wDepth * pow(max(dot(repN, viewN), 0.0), 12.0);
        accum += giS.rgb * w;
        wSum  += w;
    }
    return wSum > 1e-4 ? (accum / wSum) : texture2D(colortex4, snapToTexel(uv, res)).rgb;
#else
    vec2  stepUV    = 1.0 / res;
    vec3  accum     = vec3(0.0);
    float wSum      = 0.0;
    float invZScale = 1.0 / (linDepth * 0.04 + 0.05);
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            vec2 tapUV = uv + vec2(float(dx), float(dy)) * stepUV;
            vec4 giS   = texture2D(colortex4, tapUV);
            vec3 tapN  = decodeNormal(texture2D(colortex1, tapUV).xy);
            float w    = exp(-abs(giS.a - linDepth) * invZScale) * pow(max(dot(tapN, viewN), 0.0), 8.0);
            accum += giS.rgb * w;
            wSum  += w;
        }
    }
    return wSum > 1e-4 ? (accum / wSum) : texture2D(colortex4, uv).rgb;
#endif
}

/* DRAWBUFFERS:0 */
void main() {
    auroraBiome    = texture2D(colortex10, vec2(0.5)).g;
    vec4 baseTexel = texture2D(colortex0, texcoord);
    float rawDepth = texture2D(depthtex0, texcoord).r;
    vec3 viewPos   = screenToView(vec3(texcoord, rawDepth));

    bool isFarDH = false;
#ifdef DISTANT_HORIZONS
    if (rawDepth >= 1.0) {
        float dhZ = texture2D(dhDepthTex1, texcoord).r;
        if (dhZ < 1.0) {
            isFarDH   = true;
            viewPos   = dhScreenToView(vec3(texcoord, dhZ));
            baseTexel = texture2D(colortex14, texcoord);
        }
    }
#endif

    if (rawDepth >= 1.0 && !isFarDH) {
        vec3 skyRay = normalize(mat3(gbufferModelViewInverse) * viewPos);
        vec3 skyCol = getSky(skyRay, true, true);
    #if !defined END
        skyCol += toLinear(baseTexel.rgb) * (1.5 * MOON_BRIGHTNESS);
    #endif
        gl_FragData[0] = vec4(finiteColor(skyCol), 1.0);
        return;
    }

    vec3 albedo = toLinear(baseTexel.rgb);
    vec4 gbuf1  = texture2D(colortex1, texcoord);
    vec4 gbuf2  = texture2D(colortex2, texcoord);
    vec4 gbuf6  = texture2D(colortex6, texcoord);

    vec3  N          = decodeNormal(gbuf1.xy);
    float lmBlock    = gbuf1.z;
    float lmSky      = gbuf1.w;
    float smoothness = gbuf2.r;
    float f0Code     = gbuf2.g;
    float emission   = gbuf2.b;
    float surfAO     = mix(1.0, gbuf6.r, AO_STRENGTH);
    float matID      = floor(gbuf6.g * 255.0 + 0.5);
    float sssAmount  = gbuf6.b;

    bool isHand     = (rawDepth < 0.56) && !isFarDH;
    bool isMetallic = isMetalCode(f0Code);
    bool isPlant    = (matID == MAT_PLANT || matID == MAT_LEAVES);
    bool isSnowSurf = (matID == MAT_SNOW);
    bool isEntity   = (matID == MAT_ENTITY);

    vec3  V        = -normalize(viewPos);
    vec3  L        = normalize(shadowLightPosition);
    vec3  sunRad   = getLightColor();
    vec3  relPos   = viewToPlayer(viewPos);
    vec3  worldN   = mat3(gbufferModelViewInverse) * N;
    vec3  worldPos = relPos + cameraPosition;
    float shNoise  = ign(gl_FragCoord.xy, 0.0);

    float rawNL    = dot(N, L);
    float diffTerm = max(rawNL, 0.0);
    if (isPlant)    diffTerm = diffTerm * 0.6 + 0.4;
    if (isSnowSurf) diffTerm = max(rawNL * 0.7 + 0.3, 0.0) * 0.85;

    bool usePbrSSS = false;
#ifdef PBR_SSS
    usePbrSSS = (sssAmount > 0.02) && !isPlant && !isSnowSurf;
    if (usePbrSSS) diffTerm = mix(diffTerm, max(rawNL * 0.6 + 0.4, 0.0) * 0.9, sssAmount * 0.7);
#endif

    vec3  visShadow = vec3(0.0);
    float waterDist = 0.0;
    if (diffTerm > 0.0) {
    #ifdef SHADOWS
        visShadow = getShadow(relPos, isPlant ? lightDirWorld() : worldN, shNoise, lmSky, waterDist);
    #else
        visShadow = vec3(unshadowedLight(lmSky));
    #endif
    }

#if defined VOLUMETRIC_CLOUDS && !defined NETHER && !defined END
    visShadow *= cloudShadow(worldPos, lightDirWorld());
#endif

    vec3 waterFilter = vec3(1.0);
    if (waterDist > 0.02) {
        vec3  sunWorld = lightDirWorld();
        float colDepth = waterDist * max(sunWorld.y, 0.05);
    #ifdef WATER_CAUSTICS
        float caust = waterCaustics(worldPos.xz, colDepth, sunWorld, pixelFootprint(length(viewPos)));
        visShadow *= max(1.0 + (caust - 1.0) * CAUSTIC_STRENGTH, 0.0);
    #endif
        waterFilter = exp(-waterAbsorption(WATER_DEFAULT_TINT) * (colDepth * 1.2));
    }

    vec3 specTerm = sunRad * visShadow * specularGGX(N, V, L, 1.0 - smoothness, isMetallic ? 1.0 : f0Code);
    if (isMetallic) specTerm *= metalColor(f0Code, albedo);

    vec3 scatterAdd = vec3(0.0);
    if (isSnowSurf) {
        scatterAdd += albedo * sunRad * visShadow * vec3(0.45, 0.70, 1.0) * (0.16 * (1.0 - saturate(rawNL)));
        vec3  grainCell = floor(worldPos * 30.0);
        float grainMask = step(0.94, hash13(grainCell));
        vec3  facetN    = normalize(N + (vec3(hash13(grainCell + 1.7), hash13(grainCell + 2.9), hash13(grainCell + 4.3)) * 2.0 - 1.0) * 0.9);
        scatterAdd += sunRad * visShadow * specularGGX(facetN, V, L, 0.12, 0.04) * (grainMask * 1.4);
    }
#ifdef PBR_SSS
    if (usePbrSSS) scatterAdd += (albedo * albedo) * sunRad * visShadow * (sssAmount * 0.30 * (1.0 - saturate(rawNL)));
#endif
    if (isPlant) scatterAdd += albedo * vec3(1.0, 1.05, 0.55) * sunRad * visShadow * (saturate(-rawNL) * 0.55);

    vec3  skyAmb = getSkyAmbient();
    float skyVis = skyOcclusion(lmSky);
    vec3  giLight;
#ifdef PATH_TRACING
    giLight = (isHand || isFarDH) ? (skyAmb * skyVis) : (reconstructIndirectGI(texcoord, -viewPos.z, N) * PT_STRENGTH);
#else
    giLight = skyAmb * skyVis;
#endif

    vec3 totalIrrad = sunRad * visShadow * diffTerm
                    + (giLight + skyAmb * (skyVis * (isEntity ? 0.18 : 0.0))) * waterFilter * surfAO
                    + auroraGroundGlow() * (skyVis * surfAO)
                    + blockLight(lmBlock) * surfAO
                    + vec3(0.004 + nightVision * 0.25) * surfAO;
#if defined NETHER
    totalIrrad += netherUnderglow(worldPos, worldN) * surfAO;
#endif

    vec3 litColor = albedo * totalIrrad * (isMetallic ? 0.2 : 1.0)
                  + specTerm
                  + scatterAdd
                  + albedo * (emission * EMISSION_STRENGTH);
    gl_FragData[0] = vec4(finiteColor(litColor), 1.0);
}
#endif

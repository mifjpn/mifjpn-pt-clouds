// Mifjpn-PT | Composite Pass 0: Water Optics, SSR, Translucent Resolve & Volumetric Media
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/gi.glsl"
#include "/lib/sky.glsl"
#include "/lib/wetness.glsl"
#include "/lib/water.glsl"
#include "/lib/rain.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"
#include "/lib/raytrace.glsl"

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
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex15;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

float vlAirDensityGain = 1.0;

#ifdef VOLUMETRIC_LIGHT
vec3 evalVolumetricShafts(vec3 worldDir, float geomDist, float jitter, vec3 sunRad) {
    if (luma(sunRad) < 0.003) return vec3(0.0);

    float span      = min(geomDist, shadowDistance);
    float stepLen   = span / float(max(VL_STEPS, 1));
    vec3  clipOrig  = shadowClip(vec3(0.0));
    vec3  clipDelta = shadowClip(worldDir) - clipOrig;

    float unoccluded = 0.0;
    for (int i = 0; i < VL_STEPS; ++i) {
        float t  = stepLen * (float(i) + jitter);
        vec3  sc = distortShadow(clipOrig + clipDelta * t) * 0.5 + 0.5;
        unoccluded += step(sc.z, texture2D(shadowtex1, sc.xy).r);
    }
    unoccluded *= stepLen;

    float phase  = (phaseHGn(dot(worldDir, lightDirWorld()), 0.70) * 0.60 + 0.40) * (0.25 / PI);
    float sigmaS = (0.0035 + rainStrength * 0.0060) * VL_STRENGTH * vlAirDensityGain;
    if (isEyeInWater == 1) sigmaS *= 6.0;

#if defined END
    return sunRad * (unoccluded * phase * sigmaS * 0.55);
#else
    float skyEye = float(eyeBrightnessSmooth.y) * (1.0 / 240.0);
    return sunRad * (unoccluded * phase * sigmaS * mix(0.20, 1.0, skyEye));
#endif
}
#endif

vec3 traceOpaqueReflection(vec3 viewPos, vec3 reflDir, vec3 geomN, vec3 fallbackRad, float reflWeight, float jitter, out float outHitLen) {
    outHitLen = -1.0;
    vec3 res  = fallbackRad;
#ifdef RAY_TRACED_REFLECTIONS
    if (reflWeight > 0.03) {
        float camDist = -viewPos.z;
        int   steps   = camDist > 96.0 ? (RT_STEPS / 2) : RT_STEPS;
        vec3  startP  = viewPos + geomN * (0.01 * (1.0 + camDist * 0.05));
        vec2  hitUV;
        if (rayTrace(depthtex1, startP, reflDir, 0.15 + camDist * 0.01, 1.12, jitter, steps, hitUV)) {
            vec2  border = smoothstep(0.0, 0.08, hitUV) * smoothstep(0.0, 0.08, 1.0 - hitUV);
            float hitZ   = texture2D(depthtex1, snapToTexel(hitUV, fullRes())).r;
            outHitLen    = length(screenToView(vec3(hitUV, hitZ)) - viewPos);
            res          = mix(fallbackRad, texture2D(colortex0, hitUV).rgb, border.x * border.y);
        }
    }
#endif
    return res;
}

vec3 smoothWaterBiomeTint(vec2 centerUV, vec3 baseTint, float viewDist) {
#if WATER_COLOR_MODE == 0
    float radiusPx = clamp(1.6 / max(pixelFootprint(viewDist), 1e-4), 2.0, 80.0);
    vec2  uvRadius = radiusPx / vec2(viewWidth, viewHeight);
    vec3  accum    = baseTint;
    float count    = 1.0;
    for (int k = 0; k < 10; ++k) {
        vec2 tapUV = clamp(centerUV + vogelDisk(k, 10, 0.7) * uvRadius, 0.001, 0.999);
        if (floor(texture2D(colortex6, tapUV).g * 255.0 + 0.5) == MAT_WATER) {
            accum += texture2D(colortex2, tapUV).rgb;
            count += 1.0;
        }
    }
    return accum / count;
#else
    return baseTint;
#endif
}

/* DRAWBUFFERS:0 */
void main() {
    vec4 state10 = texture2D(colortex10, vec2(0.5));
    auroraBiome  = state10.g;

#if defined END
    endSplash = texture2D(colortex11, vec2(0.5));
#endif

    vec2 sampleUV = texcoord;

#if !defined NETHER && !defined END
    vec4 air15 = texture2D(colortex15, vec2(0.5));
    if (air15.a < 1e-3) air15 = vec4(1.0);
    vec4  state11    = texture2D(colortex11, vec2(0.5));
    float lowMistW   = state10.a;
    vlAirDensityGain = mix(1.0, air15.a, 0.60) * (1.0 + 0.60 * lowMistW);

    #ifdef VOLUMETRIC_CLOUDS
    cloudEntry = state11.rg;
    #endif

    float shimmerAmt = state11.b * dayAmount() * (1.0 - rainStrength);
    if (shimmerAmt > 0.01 && isEyeInWater == 0) {
        float rawD = texture2D(depthtex0, texcoord).r;
        if (rawD >= 0.56 && rawD < 1.0) {
            float dMeters  = length(screenToView(vec3(texcoord, rawD)));
            vec2  shGrid   = texcoord * vec2(viewWidth / max(viewHeight, 1.0), 1.0) * 30.0;
            float nowT     = frameTimeCounter;
            vec2  shWave   = vec2(noise2D(shGrid + vec2(0.0, -nowT * 1.8)) - 0.5, 0.5 * (noise2D(shGrid * 1.7 + vec2(5.0, -nowT * 2.6)) - 0.5));
            vec2  warpedUV = clamp(texcoord + shWave * (smoothstep(12.0, 70.0, dMeters) * 0.0024 * shimmerAmt), 0.001, 0.999);
            float warpD    = texture2D(depthtex0, warpedUV).r;
            if (warpD >= 0.56 && warpD < 1.0) sampleUV = warpedUV;
        }
    }
#endif

#if defined NETHER
    if (NETHER_HEAT > 0.0 && isEyeInWater == 0) {
        float rawD = texture2D(depthtex0, texcoord).r;
        if (rawD >= 0.56) {
            vec2 warpedUV = clamp(texcoord + netherHeat(texcoord, length(screenToView(vec3(texcoord, rawD)))), 0.001, 0.999);
            if (texture2D(depthtex0, warpedUV).r >= 0.56) sampleUV = warpedUV;
        }
    }
#endif

    float depthNear   = texture2D(depthtex0, sampleUV).r;
    float depthOpaque = texture2D(depthtex1, sampleUV).r;

#ifdef REALISTIC_RAIN
    if (depthNear < depthOpaque && texture2D(colortex13, sampleUV).r > 0.5) {
        float surfMat = floor(texture2D(colortex6, sampleUV).g * 255.0 + 0.5);
        depthNear     = depthOpaque;
        if (surfMat == MAT_WATER || surfMat == MAT_GLASS) {
            vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
            for (int r = 0; r < 16; ++r) {
                float ring = (r < 4) ? 2.0 : ((r < 8) ? 4.0 : ((r < 12) ? 7.0 : 11.0));
                int   axis = r - 4 * (r / 4);
                vec2  dir2 = (axis == 0) ? vec2(ring, 0.0) : ((axis == 1) ? vec2(-ring, 0.0) : ((axis == 2) ? vec2(0.0, ring) : vec2(0.0, -ring)));
                vec2  probeUV = saturate(sampleUV + dir2 * texel);
                if (texture2D(colortex13, probeUV).r < 0.5) {
                    depthNear = texture2D(depthtex0, probeUV).r;
                    break;
                }
            }
        }
    }
#endif

    bool isHand  = (depthNear < 0.56);
    bool isFarDH = false;

#ifdef DISTANT_HORIZONS
    if (depthNear >= 1.0) {
        float dhNear = texture2D(dhDepthTex, sampleUV).r;
        if (dhNear < 1.0) {
            isFarDH     = true;
            depthNear   = dhNear;
            depthOpaque = texture2D(dhDepthTex1, sampleUV).r;
        }
    }
    vec3 viewPosNear   = isFarDH ? dhScreenToView(vec3(sampleUV, depthNear))   : screenToView(vec3(sampleUV, depthNear));
    vec3 viewPosOpaque = isFarDH ? dhScreenToView(vec3(sampleUV, depthOpaque)) : screenToView(vec3(sampleUV, depthOpaque));
#else
    vec3 viewPosNear   = screenToView(vec3(sampleUV, depthNear));
    vec3 viewPosOpaque = screenToView(vec3(sampleUV, depthOpaque));
#endif

    vec3  relPosNear = viewToPlayer(viewPosNear);
    vec3  opaqueRad  = texture2D(colortex0, sampleUV).rgb;
    vec4  transLayer = texture2D(colortex5, sampleUV);
    vec4  gbuf1      = texture2D(colortex1, sampleUV);
    vec4  gbuf2      = texture2D(colortex2, sampleUV);
    vec4  gbuf6      = texture2D(colortex6, sampleUV);
    float matCode    = floor(gbuf6.g * 255.0 + 0.5);
    float lmSky      = gbuf1.w;

    bool isSky         = (depthNear >= 1.0);
    bool hasTransLayer = (depthNear < depthOpaque);
    bool isWaterSurf   = hasTransLayer && (matCode == MAT_WATER);
    bool camSubmerged  = (isEyeInWater == 1);

    vec3  viewRay  = normalize(viewPosNear);
    vec3  worldDir = mat3(gbufferModelViewInverse) * viewRay;
    vec3  sunRad   = getLightColor();
    vec3  viewL    = normalize(shadowLightPosition);
    vec3  worldL   = lightDirWorld();
    float viewDist = length(viewPosNear);
    float dither   = ign(gl_FragCoord.xy, 0.0);

    vec3 skyAmb = getSkyAmbient();
    vec3 sigmaA = waterAbsorption(WATER_DEFAULT_TINT);
    vec3 sigmaS = waterScattering();

    if (camSubmerged) {
        vec3  linFog = toLinear(fogColor);
        vec3  uwHue  = linFog / max(max(linFog.r, max(linFog.g, linFog.b)), 1e-3);
        float murk   = waterMurk(uwHue);
        sigmaA = (vec3(0.40, 0.050, 0.030) + (vec3(1.0) - uwHue) * 0.10 + vec3(0.26, 0.26, 0.68) * murk) / max(WATER_CLARITY, 0.05);
        sigmaS = waterScattering() * mix(vec3(1.0), 0.40 + 1.20 * uwHue, 0.70) + vec3(0.17, 0.22, 0.085) * murk;
    }

    vec3  subSunDir    = refractedLight(worldL);
    float cosSubSun    = max(-subSunDir.y, 0.10);
    vec3  uwHorizonRad = vec3(0.0);
    if (camSubmerged) {
        float skyEye = float(eyeBrightnessSmooth.y) * (1.0 / 240.0);
        uwHorizonRad = waterInscatter(sunRad * (max(worldL.y, 0.0) * skyEye * skyEye * 0.90), skyAmb * skyEye, sigmaA, sigmaS, 60.0, 0.70, cosSubSun, 1.0);
    }

    vec3 sceneRad;

    if (isWaterSurf && !camSubmerged) {
        vec3  waterTint = smoothWaterBiomeTint(sampleUV, gbuf2.rgb, viewDist);
        float waveCrest = gbuf2.a;
        float subRough  = gbuf6.r;
        float foamSeed  = gbuf6.b;

        vec3 surfN = decodeNormal(gbuf1.xy);
        if (dot(surfN, viewRay) > 0.0) surfN = -surfN;
        vec3 viewUp = normalize(gbufferModelView[1].xyz);
        surfN       = normalize(mix(surfN, viewUp, 0.50 * smoothstep(0.25, 0.80, pixelFootprint(viewDist))));

        float cosInc  = clamp(dot(surfN, -viewRay), 5e-4, 1.0);
        float fresnel = fresnelDielectric(cosInc, 1.0, WATER_IOR);

        vec3 refrN = normalize(viewUp + (surfN - viewUp) * REFRACTION_STRENGTH);
        if (dot(refrN, viewRay) > 0.0) refrN = surfN;
        vec3  refrRay = refract(viewRay, refrN, 1.0 / WATER_IOR);
        vec2  refrUV  = sampleUV;
        float slabLen = (depthOpaque >= 1.0) ? 96.0 : length(viewPosOpaque - viewPosNear);

#ifdef WATER_REFRACTION
        if (!isHand && !isFarDH) {
            for (int iter = 0; iter < 2; ++iter) {
                vec3 candPos = viewPosNear + refrRay * slabLen;
                if (candPos.z < -0.05) {
                    vec2 candUV = viewToScreen(candPos).xy;
                    if (candUV.x > 0.002 && candUV.x < 0.998 && candUV.y > 0.002 && candUV.y < 0.998) {
                        float candZ = texture2D(depthtex1, candUV).r;
                        if (candZ > depthNear) {
                            refrUV  = candUV;
                            slabLen = (candZ >= 1.0) ? 96.0 : length(screenToView(vec3(candUV, candZ)) - viewPosNear);
                        }
                    }
                }
            }
            float margin = min(min(refrUV.x, 1.0 - refrUV.x), min(refrUV.y, 1.0 - refrUV.y));
            refrUV = mix(sampleUV, refrUV, smoothstep(0.0, 0.06, margin));
        }
#endif
        vec3 seabedRad  = texture2D(colortex0, refrUV).rgb;
        vec3 surfShadow = vec3(unshadowedLight(lmSky));
#ifdef SHADOWS
        surfShadow = getShadowFast(relPosNear, vec3(0.0, 1.0, 0.0), lmSky);
#endif
#if defined VOLUMETRIC_CLOUDS && !defined NETHER && !defined END
        surfShadow *= cloudShadow(relPosNear + cameraPosition, worldL);
#endif
        float sunElev    = max(worldL.y, 0.0);
        vec3  sunEntered = sunRad * surfShadow * (sunElev * (1.0 - fresnelDielectric(max(sunElev, 0.02), 1.0, WATER_IOR)));
        vec3  skyEntered = skyAmb * (skyOcclusion(lmSky) * 0.90);
        sunEntered      *= mix(1.0, clamp(saturate(dot(surfN, viewL)) / max(saturate(dot(viewUp, viewL)), 0.25), 0.35, 1.90), 0.75);

        vec3 localAbs = waterAbsorption(waterTint);
#if WATER_COLOR_MODE == 0
        vec3  normTint  = waterTint / max(max(waterTint.r, max(waterTint.g, waterTint.b)), 1e-3);
        float murkAmt   = waterMurk(waterTint);
        vec3  biomeScat = sigmaS * mix(vec3(1.0), (0.20 + 1.80 * normTint) * 1.30, min(0.90 * WATER_BIOME_TINT, 1.0))
                        + vec3(0.0, 0.006, 0.004) * (1.0 - murkAmt)
                        + vec3(0.17, 0.22, 0.085) * (murkAmt * min(WATER_BIOME_TINT, 1.5));
        vec3  localScat = applyWaterVariation(biomeScat, waterVariation(relPosNear.xz + cameraPosition.xz));
#else
        vec3  localScat = applyWaterVariation(sigmaS, waterVariation(relPosNear.xz + cameraPosition.xz));
#endif

        vec3  beamTrans   = exp(-(localAbs + localScat) * slabLen);
        vec3  worldRefr   = mat3(gbufferModelViewInverse) * refrRay;
        vec3  subwaterRad = seabedRad * beamTrans
                          + waterInscatter(sunEntered, skyEntered, localAbs, localScat, slabLen, max(abs(worldRefr.y), 0.04), cosSubSun, phaseHGn(dot(subSunDir, -worldRefr), 0.50));

#ifdef WATER_SSS
        float fwdSun = saturate(dot(worldDir, worldL));
        subwaterRad += sunEntered * vec3(0.012, 0.085, 0.070) * (waveCrest * fwdSun * fwdSun * fwdSun);
#endif

        vec3  reflRay   = reflect(viewRay, surfN);
        vec3  skyMirror = getSkyReflection(mat3(gbufferModelViewInverse) * reflRay) * skyOcclusion(lmSky);
        float reflW     = saturate(fresnel * WATER_REFLECTIVITY);
        vec3  reflRad   = skyMirror;
        float ssrFade   = 1.0 - smoothstep(48.0, 96.0, viewDist);
        if (!isHand && !isFarDH && ssrFade > 0.0) {
            float unusedHit;
            reflRad = mix(skyMirror, traceOpaqueReflection(viewPosNear, reflRay, surfN, skyMirror, reflW, dither, unusedHit), ssrFade);
        }

        sceneRad  = mix(subwaterRad, reflRad, reflW);
        sceneRad += sunRad * surfShadow * specularGGX(surfN, -viewRay, viewL, max(subRough, 0.028), 0.02) * (WATER_GLITTER * 2.40);

#ifdef WATER_FOAM
        vec2  worldXZ  = relPosNear.xz + cameraPosition.xz;
        float shoreRim = 0.0;
    #ifdef WATER_SHORE_FOAM
        float surge = 0.5 + 0.5 * sin(frameTimeCounter * 0.90 - dot(worldXZ, vec2(0.85, 0.52)) * 0.11);
        shoreRim    = (depthOpaque >= 1.0) ? 0.0 : (1.0 - smoothstep(0.04, 0.35 + 1.50 * surge, length(viewPosOpaque - viewPosNear)));
        shoreRim   *= smoothstep(0.30, 0.65, noise2D(worldXZ * 2.6 + vec2(frameTimeCounter * 0.25, -frameTimeCounter * 0.15)) + shoreRim * 0.35);
    #endif
        float bedY      = (depthOpaque >= 1.0) ? -1.0e3 : viewToPlayer(viewPosOpaque).y;
        float crestFoam = foamSeed * smoothstep(1.5, 7.0, relPosNear.y - bedY) * (1.0 - 0.90 * waterMurk(waterTint));

        vec2  windAx = vec2(0.851, 0.525);
        vec2  windUV = vec2(dot(worldXZ, windAx), dot(worldXZ, vec2(-windAx.y, windAx.x)));
        float nowT   = frameTimeCounter;
        float webTex = noise2D(windUV * vec2(0.8, 2.4) + vec2(nowT * 0.35, 0.0)) * 0.50
                     + noise2D(windUV * vec2(2.2, 5.6) - vec2(nowT * 0.50, 1.7)) * 0.32
                     + noise2D(worldXZ * 9.0 + nowT * 0.20) * 0.18;
        webTex = mix(0.5, webTex, 1.0 - smoothstep(0.03, 0.12, pixelFootprint(viewDist)));

        float capMask = smoothstep(0.03, 0.45, crestFoam) * smoothstep(0.38, 0.72, webTex + crestFoam * 0.55 - 0.22);
        float dropSp  = 0.0;
    #ifdef RAIN_SPLASHES
        dropSp = rainSplash(worldXZ, pixelFootprint(viewDist), rainStrength * smoothstep(0.50, 0.95, lmSky)) * 0.85;
    #endif
        float totalFoam  = saturate(max(max(capMask, dropSp), shoreRim) * FOAM_AMOUNT);
        vec3  foamAlbedo = 0.85 * (sunEntered * 0.32 + skyEntered);
        foamAlbedo       = mix(vec3(luma(foamAlbedo)), foamAlbedo, 0.40);
        sceneRad         = mix(sceneRad, foamAlbedo, totalFoam * 0.90);
#endif
        sceneRad = sceneRad * (1.0 - transLayer.a) + transLayer.rgb;

    } else if (isWaterSurf && camSubmerged) {
        vec3 surfN = decodeNormal(gbuf1.xy);
        if (dot(surfN, viewRay) > 0.0) surfN = -surfN;

#ifdef SNELLS_WINDOW
        float cosInc = clamp(dot(surfN, -viewRay), 5e-4, 1.0);
        float tirF   = (fresnelDielectric(cosInc - 0.07, WATER_IOR, 1.0)
                      + fresnelDielectric(cosInc,        WATER_IOR, 1.0)
                      + fresnelDielectric(cosInc + 0.07, WATER_IOR, 1.0)) * (1.0 / 3.0);

        vec3 exitRay = refract(viewRay, surfN, WATER_IOR);
        vec2 winUV   = sampleUV;
        if (dot(exitRay, exitRay) > 0.0) {
            vec3 pRefr = viewPosNear + exitRay * 8.0;
            vec3 pView = viewPosNear + viewRay * 8.0;
            if (pRefr.z < -0.05 && pView.z < -0.05) winUV = clamp(sampleUV + viewToScreen(pRefr).xy - viewToScreen(pView).xy, 0.002, 0.998);
        }
        vec3  skyWindow = mix(texture2D(colortex0, winUV).rgb * exp(-(sigmaA + sigmaS) * 7.0), uwHorizonRad * 1.60, 0.45);
        float hitLen    = -1.0;
        vec3  tirRefl   = isFarDH ? uwHorizonRad : traceOpaqueReflection(viewPosNear, reflect(viewRay, surfN), surfN, uwHorizonRad, tirF, dither, hitLen);
        if (hitLen > 0.0) tirRefl *= exp(-(sigmaA + sigmaS) * hitLen);
        sceneRad = mix(skyWindow, tirRefl, tirF);
#else
        float cosInc  = saturate(dot(surfN, -viewRay));
        vec3  tangent = surfN - dot(surfN, viewRay) * viewRay;
        vec2  bentUV  = clamp(sampleUV + (mat3(gbufferProjection) * tangent).xy * 0.04, 0.002, 0.998);
        sceneRad      = mix(texture2D(colortex0, bentUV).rgb * exp(-(sigmaA + sigmaS) * 7.0), uwHorizonRad * 1.60, 0.45 + 0.45 * (1.0 - smoothstep(0.05, 0.55, cosInc)));
#endif
        sceneRad = sceneRad * (1.0 - transLayer.a) + transLayer.rgb;

    } else {
        sceneRad = opaqueRad;
        if (hasTransLayer || transLayer.a > 1e-3) sceneRad = sceneRad * (1.0 - transLayer.a) + transLayer.rgb;

        float smoothness = gbuf2.r;
        float f0Code     = gbuf2.g;
        if (!isSky && !isHand && smoothness > 0.30) {
            vec3  surfN  = decodeNormal(gbuf1.xy);
            float rough  = 1.0 - smoothness;
            vec3  microN = surfN;
#ifdef ROUGH_REFLECTIONS
            microN = normalize(surfN + (cosineHemisphere(surfN, vec2(dither, hash12(gl_FragCoord.xy * 1.37))) - surfN) * (rough * rough * 1.50));
#endif
            vec3 reflRay = reflect(viewRay, microN);
            if (dot(reflRay, surfN) < 0.0) reflRay = reflect(viewRay, surfN);

            float nv       = clamp(dot(surfN, -viewRay), 5e-4, 1.0);
            bool  metallic = isMetalCode(f0Code);
            float rootF0   = sqrt(clamp(f0Code, 0.0, 0.20));
            float reflF    = (metallic ? fresnelSchlick(nv, f0Code) : fresnelDielectric(nv, 1.0, (1.0 + rootF0) / (1.0 - rootF0))) * smoothstep(0.30, 0.70, smoothness);

            vec3  missEnv = camSubmerged ? uwHorizonRad : (getSkyReflection(mat3(gbufferModelViewInverse) * reflRay) * skyOcclusion(lmSky));
            float hitLen  = -1.0;
            vec3  reflCol = isFarDH ? missEnv : traceOpaqueReflection(viewPosNear, reflRay, surfN, missEnv, reflF, dither, hitLen);
            if (camSubmerged && hitLen > 0.0) reflCol *= exp(-(sigmaA + sigmaS) * hitLen);

            if (metallic) {
                vec3 metalTint = sceneRad / max(luma(sceneRad), 1e-3) * 0.50 + 0.50;
                vec3 presetCol;
                if (namedMetal(f0Code, presetCol)) metalTint = presetCol;
                sceneRad = mix(sceneRad, reflCol * metalTint, reflF);
            } else {
                sceneRad = mix(sceneRad, reflCol, reflF);
            }

            if (hasTransLayer) {
                vec3 sh = vec3(1.0);
#ifdef SHADOWS
                sh = getShadowFast(relPosNear, mat3(gbufferModelViewInverse) * surfN, lmSky);
#endif
                sceneRad += sunRad * sh * specularGGX(surfN, -viewRay, viewL, max(rough, 0.04), f0Code);
            }
        }
    }

    if (camSubmerged) {
        float skyEye = float(eyeBrightnessSmooth.y) * (1.0 / 240.0);
        float spanM  = isSky ? 120.0 : viewDist;
        vec3  sigmaT = sigmaA + sigmaS;
        vec3  uwSun  = sunRad * (max(worldL.y, 0.0) * skyEye * skyEye * 0.90) * exp(-sigmaT * (2.5 / cosSubSun));
        vec3  uwSky  = skyAmb * skyEye * exp(-sigmaT * 2.5);
        sceneRad     = sceneRad * exp(-sigmaT * spanM) + waterInscatter(uwSun, uwSky, sigmaA, sigmaS, spanM, 0.70, cosSubSun, phaseHGn(dot(subSunDir, -worldDir), 0.50));
    } else if (isEyeInWater == 2) {
        sceneRad = mix(sceneRad, vec3(1.50, 0.35, 0.05), 1.0 - exp(-viewDist * 0.80));
    } else if (isEyeInWater == 3) {
        sceneRad = mix(sceneRad, vec3(0.60, 0.70, 0.80), 1.0 - exp(-viewDist * 0.50));
    } else if (!isSky) {
#if defined NETHER
    #ifdef NETHER_SMOKE
        float border = smoothstep(worldEdge() * 0.60, worldEdge() * 0.96, viewDist);
        if (border > 1e-3) sceneRad = mix(sceneRad, getSky(worldDir, true, true), border);
    #else
        float hazeA = max(1.0 - exp(-viewDist * 0.012 * FOG_DENSITY * NETHER_SMOKE_DENSITY), smoothstep(worldEdge() * 0.50, worldEdge(), viewDist));
        sceneRad    = mix(sceneRad, getSky(worldDir, false, false), hazeA);
    #endif
#elif defined END
    #ifdef END_MIST_VOLUME
        float hazeA = 1.0 - exp(-viewDist * 0.0026 * FOG_DENSITY * END_MIST_DENSITY);
    #else
        float rootMist = smoothstep(46.0, END_MIST_LEVEL, relPosNear.y + cameraPosition.y);
        float hazeA    = 1.0 - exp(-viewDist * (0.0026 + 0.020 * rootMist) * FOG_DENSITY * END_MIST_DENSITY);
    #endif
        vec3  hazeCol = getSky(worldDir, false, false);
        float border  = smoothstep(worldEdge() * 0.72, worldEdge() * 0.97, viewDist);
        if (border > 1e-3) hazeCol = mix(hazeCol, getSky(worldDir, true, true), border);
        sceneRad = mix(sceneRad, hazeCol, max(hazeA, border));
#else
        float skyEye  = float(eyeBrightnessSmooth.y) * (1.0 / 240.0);
        float rainExt = rainStrength * 0.0032 * RAIN_MIST;
    #ifdef REALISTIC_RAIN
        rainExt *= 0.62 + 0.76 * rainCurtains(worldDir);
    #endif
        float airExt  = (0.0009 * air15.a + rainExt) * FOG_DENSITY * mix(0.30, 1.0, skyEye);
        float hazeA   = max(1.0 - exp(-viewDist * airExt), smoothstep(worldEdge() * 0.90, worldEdge(), length(relPosNear.xz)));
        vec3  hazeCol = getSky(normalize(vec3(worldDir.x, max(worldDir.y, 0.0) * 0.50 + 0.06, worldDir.z)), false, false) * mix(0.15, 1.0, skyEye) * air15.rgb * (1.0 - 0.40 * rainStrength);
        hazeCol      += auroraGroundGlow() * (5.0 * skyEye);
        sceneRad      = mix(sceneRad, hazeCol, hazeA);
#endif
    }

#if !defined NETHER && !defined END
    if (isEyeInWater == 0 && !isHand) {
        float skyEye  = float(eyeBrightnessSmooth.y) * (1.0 / 240.0);
        float spanLim = isSky ? 1500.0 : viewDist;

        if (lowMistW > 0.002) {
            float dawnBoost = mix(0.45, 1.0, 1.0 - smoothstep(0.05, 0.40, sunDirWorld().y));
            float marchSpan = min(spanLim, 700.0);
            float colMass   = groundMistDepth(cameraPosition.y, cameraPosition.y + worldDir.y * marchSpan, marchSpan, mix(15.0, 7.0, lowMistW));
            float tauMist   = colMass * (0.028 * lowMistW * dawnBoost * FOG_DENSITY * (1.0 + 0.30 * rainStrength));
            vec3  mistRad   = ((skyAmb * 0.85 + sunRad * (0.20 * phaseHGn(dot(worldDir, worldL), 0.60))) * air15.rgb + auroraGroundGlow() * 4.0) * mix(0.20, 1.0, skyEye) * (1.0 - 0.35 * rainStrength);
            sceneRad        = mix(sceneRad, mistRad, 1.0 - exp(-max(tauMist, 0.0)));
        }

        float seaSprayW = state11.a;
        if (seaSprayW > 0.002) {
            float clampLen = min(spanLim, 1500.0);
            float altDecay = exp(-max(cameraPosition.y + worldDir.y * clampLen * 0.50 - 63.0, 0.0) * (1.0 / 30.0));
            float tauSpray = seaSprayW * 0.0014 * clampLen * altDecay * (1.0 - 0.50 * rainStrength);
            vec3  sprayRad = getSky(normalize(vec3(worldDir.x, 0.03, worldDir.z)), false, false) * 1.10 * air15.rgb;
            sceneRad       = mix(sceneRad, sprayRad * mix(0.20, 1.0, skyEye), 1.0 - exp(-tauSpray));
        }
    }
#endif

#if defined VOLUMETRIC_CLOUDS && !defined NETHER && !defined END
    if (isEyeInWater == 0 && !isHand) {
        vec4 cloudVol = volumetricClouds(cameraPosition, worldDir, isSky ? 1.0e6 : viewDist, dither, lightDirWorld(), getLightColor() * mix(1.0, 0.35, nightAmount()), skyAmb * 1.15, skyAmb * 0.80);
        sceneRad      = sceneRad * cloudVol.a + cloudVol.rgb;
    }
#endif

#if defined END && defined END_MIST_VOLUME
    if (isEyeInWater == 0) {
        vec4 mistVol = endMistSea(cameraPosition, worldDir, isSky ? 1.0e6 : viewDist, dither);
        sceneRad     = sceneRad * mistVol.a + mistVol.rgb * END_SKY_INTENSITY;
    }
#endif

#if defined NETHER
    if (isEyeInWater == 0) {
    #ifdef NETHER_SMOKE
        vec4 smokeVol = netherSmoke(cameraPosition, worldDir, isSky ? 1.0e6 : viewDist, dither, (isSky || isHand) ? vec3(0.0) : (blockLight(gbuf1.z) * 0.05));
        sceneRad      = sceneRad * smokeVol.a + smokeVol.rgb;
    #endif
    #ifdef NETHER_EMBERS
        if (!isHand) sceneRad += netherEmbers(worldDir, isSky ? 1000.0 : viewDist);
    #endif
    }
#endif

#ifdef VOLUMETRIC_LIGHT
    sceneRad += evalVolumetricShafts(worldDir, isSky ? shadowDistance : viewDist, dither, sunRad);
#endif

#if defined END && defined END_MOTES
    if (isEyeInWater == 0) sceneRad += endMotes(worldDir, isSky ? 1000.0 : viewDist);
#endif

#ifdef REALISTIC_RAIN
    if (isEyeInWater == 0) {
    #if defined DISTANT_RAIN || defined SIMULATED_RAIN
        float activeRain = rainStrength * state10.b;
        float skyOpen    = isSky ? 1.0 : smoothstep(0.50, 0.85, lmSky);
        if (activeRain > 0.01 && skyOpen > 0.0 && !isHand) {
            float stopDist = isSky ? 1.0e5 : viewDist;
            if (hasTransLayer && !isWaterSurf) stopDist = (depthOpaque >= 1.0) ? 1.0e5 : length(viewPosOpaque);
            float hazeExt = (0.0009 + rainStrength * 0.0032 * RAIN_MIST) * FOG_DENSITY;
        #ifdef SIMULATED_RAIN
            vec2 rainHit = simulatedRain(cameraPosition, worldDir, stopDist, hazeExt, smoothstep(0.55, 0.92, float(eyeBrightnessSmooth.y) * (1.0 / 240.0)));
        #else
            vec2 rainHit = distantRain(worldDir, stopDist, hazeExt);
        #endif
            float gain  = 0.42 * RAIN_OPACITY * activeRain * skyOpen;
            float dropA = min(rainHit.x * gain, 0.80);
            sceneRad    = sceneRad * (1.0 - dropA) + rainRadiance(worldDir, skyAmb, 1.0) * dropA + blockLight(float(eyeBrightnessSmooth.x) * (1.0 / 240.0)) * (0.45 * min(rainHit.y * gain, 0.80));
        }
    #endif
        vec4 weatherLayer = texture2D(colortex12, sampleUV);
        sceneRad = sceneRad * (1.0 - weatherLayer.a) + weatherLayer.rgb;
    }
#endif

    if (blindness > 0.0) sceneRad *= exp(-viewDist * blindness * 0.50);
    gl_FragData[0] = vec4(finiteColor(sceneRad), 1.0);
}
#endif

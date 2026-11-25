// Mifjpn-PT | Warped Shadow Map Sampling, Colored Transmittance & Water Path
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_SHADOW_GLSL
#define MIFJPN_PT_SHADOW_GLSL

vec3 shadowClip(vec3 playerPos) {
    return (shadowProjection * (shadowModelView * vec4(playerPos, 1.0))).xyz;
}

vec3 distortShadow(vec3 clipPos) {
    float radial = length(clipPos.xy) * 0.9 + 0.1;
    return vec3(clipPos.xy / radial, clipPos.z * 0.2);
}

#ifdef FSH
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

vec3 evalSingleShadowTap(vec3 uvz, out float tapWaterCol) {
    tapWaterCol = 0.0;
    float dOpaque = texture2D(shadowtex1, uvz.xy).r;
    if (uvz.z > dOpaque) return vec3(0.0);

#ifdef COLORED_SHADOWS
    float dAll = texture2D(shadowtex0, uvz.xy).r;
    if (uvz.z > dAll) {
        vec4 caster = texture2D(shadowcolor0, uvz.xy);
        if (distance(caster.rgb, WATER_TAG) < 0.06) {
            float zSpan = (uvz.z - dAll) / max(0.10 * abs(shadowProjection[2][2]), 1e-4);
            tapWaterCol = clamp(zSpan, 0.0, 48.0);
            return exp(-waterAbsorption(WATER_DEFAULT_TINT) * (tapWaterCol * 0.65));
        }
        return mix(vec3(1.0), toLinear(caster.rgb), caster.a);
    }
#endif
    return vec3(1.0);
}

vec3 getShadowFast(vec3 playerPos, vec3 worldN, float skyLM) {
#if defined NETHER
    return vec3(0.0);
#elif defined END && !defined END_SHADOWS
    return vec3(1.0);
#else
    float distFade = smoothstep(shadowDistance * 0.88, shadowDistance * 0.98, length(playerPos.xz));
    if (distFade >= 1.0) return vec3(unshadowedLight(skyLM));

    vec3 baseClip = shadowClip(playerPos);
    float radial  = length(baseClip.xy) * 0.9 + 0.1;
    float biasLen = (0.04 + 0.18 * radial) * (2048.0 / float(shadowMapResolution));
    vec3 sc       = distortShadow(shadowClip(playerPos + worldN * biasLen)) * 0.5 + 0.5;
    sc.z         -= 0.00035;

    if (sc.x <= 0.001 || sc.x >= 0.999 || sc.y <= 0.001 || sc.y >= 0.999 || sc.z >= 1.0) {
        return vec3(unshadowedLight(skyLM));
    }
    float unusedW;
    vec3 sh = evalSingleShadowTap(sc, unusedW);
    return mix(sh, vec3(unshadowedLight(skyLM)), distFade);
#endif
}

vec3 getShadow(vec3 playerPos, vec3 worldN, float dither, float skyLM, out float waterPath) {
    waterPath = 0.0;
#if defined NETHER
    return vec3(0.0);
#elif defined END && !defined END_SHADOWS
    return vec3(1.0);
#else
    float distFade = smoothstep(shadowDistance * 0.88, shadowDistance * 0.98, length(playerPos.xz));
    if (distFade >= 1.0) return vec3(unshadowedLight(skyLM));

    vec3 baseClip = shadowClip(playerPos);
    float radial  = length(baseClip.xy) * 0.9 + 0.1;
    float biasLen = (0.045 + 0.22 * radial) * (2048.0 / float(shadowMapResolution));
    vec3 biasedC  = shadowClip(playerPos + worldN * biasLen);

    float filterR = (0.0014 * SHADOW_FILTER_SIZE) / radial;
    float rotPhi  = dither * TAU;
    vec3  sumSh   = vec3(0.0);
    float sumW    = 0.0;

    for (int i = 0; i < SHADOW_SAMPLES; ++i) {
        vec2 off = vogelDisk(i, SHADOW_SAMPLES, rotPhi) * filterR;
        vec3 sc  = distortShadow(vec3(biasedC.xy + off * radial, biasedC.z)) * 0.5 + 0.5;
        sc.z    -= 0.00035;

        if (sc.x <= 0.001 || sc.x >= 0.999 || sc.y <= 0.001 || sc.y >= 0.999) {
            sumSh += vec3(unshadowedLight(skyLM));
        } else {
            float tapW;
            sumSh += evalSingleShadowTap(sc, tapW);
            sumW  += tapW;
        }
    }

    float invN = 1.0 / float(max(SHADOW_SAMPLES, 1));
    waterPath  = (sumW * invN) * (1.0 - distFade);
    return mix(sumSh * invN, vec3(unshadowedLight(skyLM)), distFade);
#endif
}
#endif

#endif

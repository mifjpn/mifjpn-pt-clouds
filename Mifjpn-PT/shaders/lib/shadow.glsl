// Mifjpn-PT | Warped Shadow Map Sampling, Contact Shadows & Colored Transmittance
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_SHADOW_GLSL
#define MIFJPN_PT_SHADOW_GLSL

vec3 shadowClip(vec3 playerPos) {
    return (shadowProjection * (shadowModelView * vec4(playerPos, 1.0))).xyz;
}

vec3 distortShadow(vec3 clipPos) {
    float radial = length(clipPos.xy) * 0.9 + 0.1;
    return vec3(clipPos.xy / radial, clipPos.z * 0.5);
}

#ifdef FSH
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

vec3 evalSingleShadowTap(vec3 uvz, out float tapWaterCol) {
    tapWaterCol = 0.0;
    float dOpaque = texture2D(shadowtex1, uvz.xy).r;
    if (uvz.z > dOpaque) return vec3(0.0);

    float dAll = texture2D(shadowtex0, uvz.xy).r;
    if (uvz.z > dAll) {
#ifdef COLORED_SHADOWS
        vec4 caster = texture2D(shadowcolor0, uvz.xy);
        if (distance(caster.rgb, WATER_TAG) < 0.06) {
            float zSpan = (uvz.z - dAll) / max(0.25 * abs(shadowProjection[2][2]), 1e-4);
            tapWaterCol = clamp(zSpan, 0.0, 48.0);
            return exp(-waterAbsorption(WATER_DEFAULT_TINT) * (tapWaterCol * 0.65));
        }
        if (caster.a >= 0.90) return vec3(0.0);
        vec3 glassTint = mix(vec3(1.0), toLinear(caster.rgb) * 1.25, caster.a);
        return glassTint * (1.0 - caster.a);
#else
        return vec3(0.0);
#endif
    }
    return vec3(1.0);
}

vec3 getShadowFast(vec3 playerPos, vec3 worldN, float skyLM) {
#if defined NETHER
    return vec3(0.0);
#elif defined END && !defined END_SHADOWS
    return vec3(1.0);
#else
    float orthoHalf = 1.0 / max(abs(shadowProjection[0][0]), 1e-4);
    float maxRange  = min(shadowDistance, orthoHalf);
    float distFade  = smoothstep(maxRange * 0.88, maxRange * 0.98, length(playerPos.xz));
    if (distFade >= 1.0) return vec3(unshadowedLight(skyLM));

    vec3  baseClip = shadowClip(playerPos);
    float radial   = length(baseClip.xy) * 0.9 + 0.1;
    float slope    = 1.25 - 0.50 * saturate(dot(worldN, lightDirWorld()));
    float biasLen  = (0.015 + 0.11 * radial) * slope * (2048.0 / float(shadowMapResolution)) * (orthoHalf / 160.0);
    vec3  sc       = distortShadow(shadowClip(playerPos + worldN * biasLen)) * 0.5 + 0.5;
    sc.z          -= 0.00008;

    if (sc.x <= 0.001 || sc.x >= 0.999 || sc.y <= 0.001 || sc.y >= 0.999 || sc.z >= 1.0 || sc.z <= 0.0) {
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
    float orthoHalf = 1.0 / max(abs(shadowProjection[0][0]), 1e-4);
    float maxRange  = min(shadowDistance, orthoHalf);
    float distFade  = smoothstep(maxRange * 0.88, maxRange * 0.98, length(playerPos.xz));
    if (distFade >= 1.0) return vec3(unshadowedLight(skyLM));

    vec3  baseClip = shadowClip(playerPos);
    float radial   = length(baseClip.xy) * 0.9 + 0.1;
    float slope    = 1.25 - 0.50 * saturate(dot(worldN, lightDirWorld()));
    float biasLen  = (0.015 + 0.11 * radial) * slope * (2048.0 / float(shadowMapResolution)) * (orthoHalf / 160.0);
    vec3  biasedC  = shadowClip(playerPos + worldN * biasLen);

    float clipRad = 0.040 * SHADOW_FILTER_SIZE * abs(shadowProjection[0][0]);
    float rotPhi  = dither * TAU;
    vec3  sumSh   = vec3(0.0);
    float sumW    = 0.0;

    for (int i = 0; i < SHADOW_SAMPLES; ++i) {
        vec2 off = vogelDisk(i, SHADOW_SAMPLES, rotPhi) * clipRad;
        vec3 sc  = distortShadow(vec3(biasedC.xy + off, biasedC.z)) * 0.5 + 0.5;
        sc.z    -= 0.00008;

        if (sc.x <= 0.001 || sc.x >= 0.999 || sc.y <= 0.001 || sc.y >= 0.999 || sc.z >= 1.0 || sc.z <= 0.0) {
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

float traceContactShadow(sampler2D depthTex, vec3 viewPos, vec3 viewL, vec3 viewN, float dither) {
#if defined NETHER
    return 1.0;
#else
    float camDist = -viewPos.z;
    if (camDist < 0.55) return 1.0;

    float maxReach = clamp(0.18 + camDist * 0.045, 0.20, 12.0);
    float dt       = maxReach * (1.0 / 10.0);
    vec3  origin   = viewPos + viewN * (0.006 + camDist * 0.0012);
    vec3  curr     = origin + viewL * (dt * (0.25 + 0.75 * dither));

    for (int i = 0; i < 10; ++i) {
        if (curr.z > -near) break;
        vec3 scr = viewToScreen(curr);
        if (scr.x <= 0.002 || scr.x >= 0.998 || scr.y <= 0.002 || scr.y >= 0.998) break;

        float rawZ = texture2D(depthTex, scr.xy).r;
        if (rawZ > 0.56 && rawZ < 1.0) {
            float surfZ = linearDepth(rawZ);
            float rayZ  = -curr.z;
            float diff  = rayZ - surfZ;
            float thick = max(dt * 2.6, 0.06 + camDist * 0.012);
            if (diff > 0.004 + camDist * 0.0006 && diff < thick) {
                vec2 edge = smoothstep(0.0, 0.04, scr.xy) * smoothstep(0.0, 0.04, 1.0 - scr.xy);
                return 1.0 - edge.x * edge.y;
            }
        }
        curr += viewL * dt;
        dt   *= 1.14;
    }
    return 1.0;
#endif
}
#endif

#endif

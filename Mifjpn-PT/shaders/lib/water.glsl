// Mifjpn-PT | Advected Multi-Band Ocean Spectrum, Exact Dielectric Fresnel & Slab Optics
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_WATER_GLSL
#define MIFJPN_PT_WATER_GLSL

#include "/lib/wetness.glsl"

const float WATER_IOR          = 1.333;
const vec3  WATER_DEFAULT_TINT = vec3(0.247, 0.463, 0.894);
const float PEAK_WAVE_OFFSET   = 0.4658;

#define WAVE_ITERATIONS 28
#define WAVE_WIND_ANGLE 0.55

void evalWaveBand(int bandIdx, out vec2 waveDir, out float waveNum, out float angFreq, out float amplitude, out float steepness, out float advectDist) {
    float fb         = float(bandIdx);
    float waveLength = (84.0 * pow(0.822, fb)) / max(WAVE_SCALE, 0.05);
    waveNum          = TAU / waveLength;

    float quasi  = fract(fb * 0.6180339887 + 0.31);
    float fanArc = mix(0.45, 2.40, smoothstep(0.0, 10.0, fb));
    float theta  = WAVE_WIND_ANGLE + (quasi * 2.0 - 1.0) * fanArc;
    if (bandIdx == 1) theta = WAVE_WIND_ANGLE + 1.20;

    waveDir    = vec2(cos(theta), sin(theta));
    angFreq    = sqrt(9.81 * waveNum) * (0.65 * WAVE_SPEED);
    float env  = mix(0.32, 1.0, smoothstep(0.0, 6.0, fb)) * pow(0.982, fb);
    steepness  = 0.074 * env * WAVE_HEIGHT * (1.0 + 0.80 * rainStrength);
    amplitude  = steepness / waveNum;
    advectDist = (0.32 * pow(0.962, fb)) / waveNum;
}

float c2ValueNoise(vec2 p, out vec2 grad, out vec3 hess) {
    vec2 cell = floor(p);
    vec2 f    = p - cell;
    vec2 u    = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du   = 30.0 * f * f * (f - 1.0) * (f - 1.0);
    vec2 ddu  = 60.0 * f * (f - 1.0) * (2.0 * f - 1.0);

    float n00 = hash12(cell);
    float n10 = hash12(cell + vec2(1.0, 0.0));
    float n01 = hash12(cell + vec2(0.0, 1.0));
    float n11 = hash12(cell + vec2(1.0, 1.0));

    float dx = n10 - n00, dz = n01 - n00, dxz = n00 - n10 - n01 + n11;
    grad = vec2(du.x * (dx + dxz * u.y), du.y * (dz + dxz * u.x));
    hess = vec3(ddu.x * (dx + dxz * u.y), du.x * du.y * dxz, ddu.y * (dz + dxz * u.x));
    return n00 + dx * u.x + dz * u.y + dxz * u.x * u.y;
}

vec2 evalSeaEnvelope(vec2 worldXZ) {
    vec2  windDir  = vec2(cos(WAVE_WIND_ANGLE), sin(WAVE_WIND_ANGLE));
    float t        = frameTimeCounter;
    float varAmt   = min(WAVE_VARIATION, 1.0);
    float swellSet = noise2D((worldXZ - windDir * (t * 2.5)) * (1.0 / 95.0) + vec2(3.1, 7.7));
    vec2  gustUV   = worldXZ - windDir * (t * 1.8);
    float gustMap  = noise2D(gustUV * (1.0 / 75.0) + vec2(31.7, 8.3)) * 0.70 + noise2D(gustUV * (1.0 / 24.0) + vec2(5.2, 1.9)) * 0.30;
    return vec2(mix(1.0, 0.45 + 1.10 * swellSet, 0.85 * varAmt), mix(1.0, mix(mix(0.25, 0.85, rainStrength), 1.35, smoothstep(0.32, 0.68, gustMap)), varAmt));
}

float integrateOceanSpectrum(vec2 worldXZ, float pxFootprint, int bandLimit, out vec2 outGrad, out vec3 outHess, out float outCrest, out float outSlopeVar) {
    float safeFP   = max(pxFootprint, 1e-3);
    vec2  bandGain = evalSeaEnvelope(worldXZ);
    float warpAmp  = 9.0 * WAVE_VARIATION;
    vec2  g1, g2; vec3 unusedH;
    float w1 = c2ValueNoise(worldXZ * (1.0 / 61.0) + vec2(13.1,  2.7), g1, unusedH);
    float w2 = c2ValueNoise(worldXZ * (1.0 / 53.0) + vec2( 4.4, 19.3), g2, unusedH);

    vec2  advPos    = worldXZ + warpAmp * vec2(w1 - 0.5, w2 - 0.5);
    mat2  jac       = mat2(1.0) + warpAmp * mat2(g1.x / 61.0, g2.x / 53.0, g1.y / 61.0, g2.y / 53.0);
    float heightSum = 0.0;
    outGrad = vec2(0.0); outHess = vec3(0.0); outCrest = 0.0; outSlopeVar = 0.0;
    float nowT = frameTimeCounter;

    for (int i = 0; i < WAVE_ITERATIONS; ++i) {
        vec2 wDir; float k, omega, amp, steep, drag;
        evalWaveBand(i, wDir, k, omega, amp, steep, drag);
        float nyquist = (i < bandLimit) ? smoothstep(3.0, 8.0, TAU / (k * safeFP)) : 0.0;
        float envGain = mix(bandGain.x, bandGain.y, smoothstep(4.0, 12.0, float(i)));
        outSlopeVar  += (steep * steep) * (envGain * envGain) * 0.50 * (1.0 - nyquist);
        if (nyquist < 1e-3) continue;

        float activeGain = envGain * nyquist;
        float phase      = k * dot(wDir, advPos) - omega * nowT + float(i) * GOLDEN_ANGLE;
        float sinP = sin(phase), cosP = cos(phase);
        float peakExp = exp(sinP - 1.0);
        vec2  dPhase  = k * (wDir * jac);
        float bandAmp = amp * activeGain;

        heightSum += bandAmp * (peakExp - PEAK_WAVE_OFFSET);
        outGrad   += (bandAmp * peakExp * cosP) * dPhase;
        outHess   += (bandAmp * peakExp * (cosP * cosP - sinP)) * vec3(dPhase.x * dPhase.x, dPhase.x * dPhase.y, dPhase.y * dPhase.y);
        if (i >= 3) outCrest += steep * activeGain * (peakExp - PEAK_WAVE_OFFSET);

        float pull = drag * activeGain;
        advPos -= wDir * (peakExp * cosP * pull);
        jac    -= (peakExp * (cosP * cosP - sinP) * pull) * mat2(wDir * dPhase.x, wDir * dPhase.y);
    }
    return heightSum;
}

vec4 waveField(vec2 worldXZ, float pxFootprint) {
    vec2 grad; vec3 hess; float crest, slopeVar;
    integrateOceanSpectrum(worldXZ, pxFootprint, WAVE_ITERATIONS, grad, hess, crest, slopeVar);
    return vec4(crest, grad, slopeVar);
}

float waveHeightLF(vec2 worldXZ) {
    vec2 grad; vec3 hess; float crest, slopeVar;
    return clamp(integrateOceanSpectrum(worldXZ, 0.50, 7, grad, hess, crest, slopeVar) * 0.25, -0.12, 0.12);
}

vec3 waveHessian(vec2 worldXZ, float pxFootprint) {
    vec2 grad; vec3 hess; float crest, slopeVar;
    integrateOceanSpectrum(worldXZ, pxFootprint, WAVE_ITERATIONS, grad, hess, crest, slopeVar);
    return hess;
}

vec3 waterRayHit(vec3 eyeWorld, vec3 planeHit) {
    vec3  delta = planeHit - eyeWorld;
    float dist  = max(length(delta), 1e-4);
    vec3  ray   = delta / dist;
    float safeY = abs(ray.y) < 0.04 ? (ray.y < 0.0 ? -0.04 : 0.04) : ray.y;
    float t     = dist;
    for (int iter = 0; iter < 4; ++iter) {
        vec3 cur = eyeWorld + ray * t;
        t += (planeHit.y + waveHeightLF(cur.xz) - cur.y) / safeY;
    }
    return eyeWorld + ray * clamp(t, dist - 4.0, dist + 4.0);
}

vec3 waterNormalWorld(vec2 worldXZ, float pxFootprint, float rainRate, out float crestOut, out float roughOut) {
    vec4 wf   = waveField(worldXZ, pxFootprint);
    vec2 grad = wf.yz;
#ifdef RAIN_RIPPLES
    grad += rippleGradient(worldXZ, pxFootprint, rainRate) * 1.60;
#endif
    float stormBreak = 1.0 + 0.55 * rainStrength;
    crestOut = smoothstep(0.05 * stormBreak, 0.14 * stormBreak, wf.x);
    roughOut = clamp(sqrt(wf.w) * 0.90, 0.0, 0.45);
    return normalize(vec3(-grad.x, 1.0, -grad.y));
}

float fresnelDielectric(float cosInc, float n1, float n2) {
    float ci    = clamp(cosInc, 5e-4, 1.0);
    float eta   = n1 / n2;
    float sinT2 = eta * eta * (1.0 - ci * ci);
    if (sinT2 >= 1.0) return 1.0;
    float ct = sqrt(1.0 - sinT2);
    float rs = (n1 * ci - n2 * ct) / (n1 * ci + n2 * ct);
    float rp = (n1 * ct - n2 * ci) / (n1 * ct + n2 * ci);
    return 0.5 * (rs * rs + rp * rp);
}

vec3 biomeWaterColor() {
    vec3 col = WATER_DEFAULT_TINT;
#ifdef BIOME_WARM_OCEAN
    if (biome == BIOME_WARM_OCEAN) col = vec3(0.263, 0.835, 0.933);
#endif
#ifdef BIOME_LUKEWARM_OCEAN
    if (biome == BIOME_LUKEWARM_OCEAN) col = vec3(0.271, 0.678, 0.949);
#endif
#ifdef BIOME_DEEP_LUKEWARM_OCEAN
    if (biome == BIOME_DEEP_LUKEWARM_OCEAN) col = vec3(0.271, 0.678, 0.949);
#endif
#ifdef BIOME_COLD_OCEAN
    if (biome == BIOME_COLD_OCEAN) col = vec3(0.239, 0.341, 0.839);
#endif
#ifdef BIOME_DEEP_COLD_OCEAN
    if (biome == BIOME_DEEP_COLD_OCEAN) col = vec3(0.239, 0.341, 0.839);
#endif
#ifdef BIOME_FROZEN_OCEAN
    if (biome == BIOME_FROZEN_OCEAN) col = vec3(0.224, 0.220, 0.788);
#endif
#ifdef BIOME_DEEP_FROZEN_OCEAN
    if (biome == BIOME_DEEP_FROZEN_OCEAN) col = vec3(0.224, 0.220, 0.788);
#endif
#ifdef BIOME_FROZEN_RIVER
    if (biome == BIOME_FROZEN_RIVER) col = vec3(0.224, 0.220, 0.788);
#endif
#ifdef BIOME_SWAMP
    if (biome == BIOME_SWAMP) col = vec3(0.380, 0.482, 0.392);
#endif
#ifdef BIOME_MANGROVE_SWAMP
    if (biome == BIOME_MANGROVE_SWAMP) col = vec3(0.227, 0.478, 0.416);
#endif
#ifdef BIOME_MEADOW
    if (biome == BIOME_MEADOW) col = vec3(0.055, 0.306, 0.812);
#endif
#ifdef BIOME_CHERRY_GROVE
    if (biome == BIOME_CHERRY_GROVE) col = vec3(0.365, 0.718, 0.937);
#endif
    return col;
}

float waterMurk(vec3 rawTint) {
    vec3 normCol = rawTint / max(max(rawTint.r, max(rawTint.g, rawTint.b)), 1e-3);
    return 1.0 - saturate(((1.0 - min(normCol.r, min(normCol.g, normCol.b))) - 0.20) * 2.50);
}

vec3 waterTintFor(vec3 biomeTint) {
#if WATER_COLOR_MODE == 1
    return vec3(0.20, 0.45, 0.95);
#elif WATER_COLOR_MODE == 2
    return vec3(0.04, 0.80, 0.82);
#elif WATER_COLOR_MODE == 3
    return vec3(0.40, 0.50, 0.28);
#elif WATER_COLOR_MODE == 4
    return vec3(0.78, 0.93, 1.00);
#elif WATER_COLOR_MODE == 5
    return vec3(WATER_CUSTOM_R, WATER_CUSTOM_G, WATER_CUSTOM_B);
#elif WATER_COLOR_MODE == 6
    return vec3(0.05, 0.36, 0.40);
#else
    return biomeTint;
#endif
}

vec3 waterAbsorption(vec3 biomeTint) {
    vec3 selTint = waterTintFor(biomeTint);
#if WATER_COLOR_MODE == 0
    selTint /= max(max(selTint.r, max(selTint.g, selTint.b)), 1e-3);
    float dyeStrength = 0.12 * WATER_BIOME_TINT;
#elif WATER_COLOR_MODE == 6
    float dyeStrength = 0.12;
#else
    float dyeStrength = 0.30;
#endif
    vec3 pureH2O = vec3(0.40, 0.050, 0.030);
#if WATER_COLOR_MODE == 4
    pureH2O *= 0.45;
#endif
    vec3 solute = (vec3(1.0) - selTint) * dyeStrength;
#if WATER_COLOR_MODE == 0
    solute += vec3(0.26, 0.26, 0.68) * (waterMurk(biomeTint) * min(WATER_BIOME_TINT, 1.5));
#endif
    return (pureH2O + solute) / max(WATER_CLARITY, 0.05);
}

vec3 waterScattering() {
#if WATER_COLOR_MODE == 2
    return vec3(0.0035, 0.0150, 0.0150);
#elif WATER_COLOR_MODE == 3
    return vec3(0.0100, 0.0170, 0.0090);
#elif WATER_COLOR_MODE == 4
    return vec3(0.0020, 0.0070, 0.0100);
#elif WATER_COLOR_MODE == 6
    return vec3(0.0012, 0.0070, 0.0085);
#elif WATER_COLOR_MODE == 5
    return vec3(0.0030, 0.0110, 0.0130) * 0.35 + vec3(WATER_CUSTOM_R, WATER_CUSTOM_G, WATER_CUSTOM_B) * 0.020;
#else
    return vec3(0.0030, 0.0110, 0.0130);
#endif
}

float waterVariation(vec2 worldXZ) {
    float drift = frameTimeCounter * 0.004;
    return noise2D(worldXZ * 0.021 + vec2(drift, -drift * 0.7)) * 0.65 + noise2D(worldXZ * 0.067 + vec2(-drift * 1.3, drift)) * 0.35 - 0.5;
}

vec3 applyWaterVariation(vec3 baseScat, float patchVal) {
    float pv = patchVal * WATER_VARIATION;
    return baseScat * vec3(1.0 + 0.45 * pv, 1.0 + 1.10 * pv, 1.0 - 0.55 * pv);
}

vec3 waterInscatter(vec3 sunIrrad, vec3 skyIrrad, vec3 sigmaA, vec3 sigmaS, float rayPath, float cosView, float cosLight, float phaseVal) {
    vec3  sigmaT   = max(sigmaA + sigmaS, vec3(1e-4));
    float vertSpan = rayPath * cosView;
    vec3  extSun   = sigmaT * (1.0 / max(cosLight, 0.05) + 1.0 / max(cosView, 0.05));
    vec3  extSky   = sigmaT * (1.0 / max(cosView, 0.05) + 1.10);
    return sigmaS * (sunIrrad * phaseVal * (1.0 - exp(-extSun * vertSpan)) / extSun + skyIrrad * (1.0 - exp(-extSky * vertSpan)) / extSky);
}

vec3 refractedLight(vec3 sunUpDir) { return refract(-sunUpDir, vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR); }

float waterCaustics(vec2 worldXZ, float depthM, vec3 sunUpDir, float pxFootprint) {
    vec3  subRay    = refractedLight(sunUpDir);
    float cosSub    = max(-subRay.y, 0.20);
    vec2  entryXZ   = worldXZ - (subRay.xz / cosSub) * depthM;
    vec3  surfHess  = waveHessian(entryXZ, max(pxFootprint, (0.014 * depthM) / cosSub));
    float lensPower = ((1.0 - 1.0 / WATER_IOR) * depthM) / cosSub;
    float jacDet    = (1.0 + lensPower * surfHess.x) * (1.0 + lensPower * surfHess.z) - (lensPower * lensPower) * (surfHess.y * surfHess.y);
    return mix(clamp(1.0 / (abs(jacDet) + 0.10), 0.0, 6.0), 1.0, (1.0 - exp(-depthM * 0.22)) * 0.70);
}

#endif

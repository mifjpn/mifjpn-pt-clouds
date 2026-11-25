// Mifjpn-PT | Rain Wetness, Porous Darkening, Basin Puddles, Ripples & Wall Rivulets
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_WETNESS_GLSL
#define MIFJPN_PT_WETNESS_GLSL

#include "/lib/sky.glsl"
#include "/lib/rain.glsl"

struct WetSurface {
    float wet;
    float film;
    float puddle;
    float splash;
    vec2  ripple;
};

float wetCurve() {
    float w = saturate(wetness);
    return pow(w, 0.40) * smoothstep(0.0, 0.015, w);
}

vec2 evalRippleCell(vec2 worldXZ, float timeSec, float gridScale, float layerSeed, float activeProb) {
    vec2  scaled   = worldXZ / gridScale;
    vec2  cellID   = floor(scaled) + layerSeed;
    float dropLive = step(hash12(cellID * 1.37 + 11.0), activeProb);
    if (dropLive < 0.5) return vec2(0.0);

    vec2  local  = fract(scaled);
    vec2  center = 0.30 + 0.40 * hash22(cellID);
    float period = 0.90 + 0.70 * hash12(cellID + 3.1);
    float phase  = fract(timeSec / period + hash12(cellID + 5.7));
    vec2  delta  = local - center;
    float dist   = length(delta) + 1e-4;
    float waveX  = dist - phase * 0.30;

    const float INV_SIGMA2 = 400.0;
    const float WAVE_NUM   = 62.831853;
    float gauss = exp(-waveX * waveX * INV_SIGMA2);
    float dWave = (WAVE_NUM * cos(WAVE_NUM * waveX) - 2.0 * waveX * INV_SIGMA2 * sin(WAVE_NUM * waveX)) * gauss;
    float decay = (1.0 - phase) * (1.0 - phase) * smoothstep(0.0, 0.06, phase);
    return (delta / dist) * (dWave * decay * (0.0048 / gridScale));
}

vec2 rippleGradient(vec2 worldXZ, float pxFootprint, float rainRate) {
#ifdef RAIN_RIPPLES
    if (rainRate <= 0.01) return vec2(0.0);
    float mipFade = 1.0 - smoothstep(0.016, 0.055, pxFootprint);
    if (mipFade <= 0.0) return vec2(0.0);
    float t = frameTimeCounter;
    return (evalRippleCell(worldXZ, t, 0.62, 0.0, rainRate)
          + evalRippleCell(worldXZ + 17.3, t * 0.93, 0.91, 41.0, rainRate * 0.85)) * (mipFade * RIPPLE_STRENGTH);
#else
    return vec2(0.0);
#endif
}

float evalSplashCell(vec2 worldXZ, float timeSec, float gridScale, float layerSeed, float activeProb, float pxFootprint) {
    vec2 scaled = worldXZ / gridScale;
    vec2 cellID = floor(scaled) + layerSeed;
    if (hash12(cellID * 1.37 + 11.0) > activeProb) return 0.0;

    vec2  rnd    = hash22(cellID);
    float period = 0.90 + 0.70 * hash12(cellID + 3.1);
    float phase  = fract(timeSec / period + hash12(cellID + 5.7));
    float normT  = (phase * period) * (1.0 / 0.13);
    if (normT >= 1.0) return 0.0;

    vec2  delta  = fract(scaled) - (0.30 + 0.40 * rnd);
    float distM  = length(delta) * gridScale;
    float rimW   = max(0.008, pxFootprint * 1.2);
    float rimArg = (distM - (0.008 + 0.036 * sqrt(normT))) / rimW;
    float lobes  = 7.0 + floor(rnd.x * 5.0);
    float crown  = exp(-rimArg * rimArg) * mix(1.0, 0.5 + 0.5 * sin(atan(delta.y, delta.x + 1e-5) * lobes + rnd.y * TAU), smoothstep(0.15, 0.60, normT));
    float column = exp(-(distM * distM) / (rimW * rimW)) * (1.0 - normT);
    return (crown * 0.60 + column * 0.80) * (1.0 - normT * normT);
}

float rainSplash(vec2 worldXZ, float pxFootprint, float rainRate) {
#ifdef RAIN_SPLASHES
    if (rainRate <= 0.01) return 0.0;
    float mipFade = 1.0 - smoothstep(0.010, 0.032, pxFootprint);
    if (mipFade <= 0.0) return 0.0;
    float t = frameTimeCounter;
    float s = evalSplashCell(worldXZ, t, 0.62, 0.0, rainRate, pxFootprint)
            + evalSplashCell(worldXZ + 17.3, t * 0.93, 0.91, 41.0, rainRate * 0.85, pxFootprint)
            + evalSplashCell(worldXZ + 5.9,  t * 1.11, 0.37, 83.0, rainRate * 0.65, pxFootprint);
    return saturate(s) * mipFade;
#else
    return 0.0;
#endif
}

float wallRivulets(float wallCoordX, float worldY, float pxFootprint) {
#ifdef RAIN_WALL_STREAKS
    float mipFade = 1.0 - smoothstep(0.03, 0.10, pxFootprint);
    if (mipFade <= 0.0) return 0.0;
    float t       = frameTimeCounter;
    float channel = noise2D(vec2(wallCoordX * 10.0, worldY * 0.35 + 3.0));
    float droplet = noise2D(vec2(wallCoordX * 10.0 + 11.0, worldY * 1.6 + t * 1.3));
    float micro   = noise2D(vec2(wallCoordX * 23.0 + 5.0,  worldY * 0.9 + t * 0.6));
    float streak  = smoothstep(0.58, 0.74, channel) * (0.55 + 0.45 * droplet) + smoothstep(0.72, 0.88, micro) * 0.35;
    return saturate(streak) * mipFade * mix(0.30, 1.0, rainStrength);
#else
    return 0.0;
#endif
}

WetSurface evalWetSurface(vec3 worldPos, vec3 worldN, float skyLM, float pxFootprint) {
    WetSurface surf;
    surf.wet = 0.0; surf.film = 0.0; surf.puddle = 0.0; surf.splash = 0.0; surf.ripple = vec2(0.0);

    float skyReach = smoothstep(0.80, 0.96, skyLM);
    if (skyReach <= 0.001) return surf;

    float topMask    = smoothstep(0.80, 0.95, worldN.y);
    float activeRain = rainStrength * skyReach;
    vec2  ringGrad   = rippleGradient(worldPos.xz, pxFootprint, activeRain);
    surf.ripple      = ringGrad * (0.40 * topMask);

    float baseWet = wetCurve();
    if (baseWet <= 0.001) return surf;

    float sunDry   = smoothstep(0.0, 0.35, sunDirWorld().y) * (1.0 - rainStrength);
    float localWet = saturate(baseWet - sunDry * noise2D(worldPos.xz * 0.55 + 7.0) * (0.55 * SURFACE_DRYING)) * skyReach;
    if (localWet <= 0.001) return surf;

    float wallMask  = 1.0 - smoothstep(0.25, 0.60, abs(worldN.y));
    float ceilMask  = 1.0 - smoothstep(-0.60, -0.25, worldN.y);
    float basinMap  = fbm(worldPos.xz * 0.21 + 3.7) + (noise2D(worldPos.xz * 2.3) - 0.5) * 0.09;
    float waterLine = (0.17 + 0.24 * pow(localWet, 0.80)) * PUDDLE_COVERAGE;
    float rampIn    = smoothstep(0.03, 0.30, localWet);

    surf.puddle     = (1.0 - smoothstep(waterLine - 0.045, waterLine + 0.005, basinMap)) * rampIn * topMask;
    float marginWet = (1.0 - smoothstep(waterLine, waterLine + 0.10, basinMap)) * rampIn;
    float dampness  = smoothstep(0.0, 0.35, localWet) * 0.75;
    float waterFilm = (1.0 - smoothstep(waterLine, waterLine + 0.26, basinMap)) * rampIn * topMask;

    if (wallMask > 0.001) {
        vec2  horizN   = worldN.xz / max(length(worldN.xz), 1e-4);
        float windHit  = saturate(-dot(horizN, rainWindDir()));
        float tangentX = worldPos.x * worldN.z - worldPos.z * worldN.x;
        float streaks  = wallRivulets(tangentX, worldPos.y, pxFootprint) * smoothstep(0.05, 0.40, localWet);
        dampness       = mix(dampness, min(dampness * mix(0.40, 0.75, windHit) + 0.60 * streaks, 1.0), wallMask);
        waterFilm      = mix(waterFilm, streaks, wallMask);
    }

    dampness  *= (1.0 - 0.75 * ceilMask);
    waterFilm *= (1.0 - ceilMask);

    surf.wet    = max(dampness, marginWet * topMask);
    surf.film   = waterFilm;
    surf.ripple = ringGrad * max(max(surf.puddle, surf.film * topMask * 0.75), 0.40 * topMask);
    surf.splash = rainSplash(worldPos.xz, pxFootprint, activeRain) * topMask;
    return surf;
}

#endif

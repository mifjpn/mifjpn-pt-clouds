// Mifjpn-PT Clouds Edition | Celestial Dome & Gossamer Cirrostratus/Cirrocumulus Veil
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_SKY_GLSL
#define MIFJPN_PT_SKY_GLSL

vec3  sunDirWorld()   { return normalize(mat3(gbufferModelViewInverse) * sunPosition); }
vec3  lightDirWorld() { return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); }
float dayAmount()     { return smoothstep(-0.14, 0.10, sunDirWorld().y); }

#include "/lib/atmosphere.glsl"
#include "/lib/clouds.glsl"

vec3 keyBlend(float elev, vec3 kNight, vec3 kTwi, vec3 kDawn, vec3 kMorn, vec3 kNoon) {
    vec3 res = mix(kNight, kTwi,  smoothstep(-0.22, -0.06, elev));
    res      = mix(res,    kDawn, smoothstep(-0.06,  0.05, elev));
    res      = mix(res,    kMorn, smoothstep( 0.05,  0.25, elev));
    return     mix(res,    kNoon, smoothstep( 0.25,  0.65, elev));
}

vec3 sunColorAt(float sinElev) {
#if defined PHYSICAL_SKY && !defined NETHER && !defined END
    return vec3(1.00, 0.93, 0.82) * atmSunTint(max(sinElev, -0.02)) * smoothstep(-0.05, 0.05, sinElev);
#else
    vec3 lowCol = mix(vec3(1.00, 0.36, 0.10), vec3(1.00, 0.74, 0.46), smoothstep(0.0, 0.14, sinElev));
    return mix(lowCol, vec3(1.00, 0.93, 0.82), smoothstep(0.10, 0.50, sinElev)) * smoothstep(-0.05, 0.05, sinElev);
#endif
}

#include "/lib/end.glsl"
#include "/lib/nether.glsl"

float unshadowedLight(float skyLM) {
#if defined END
    return 1.0;
#else
    float s2 = skyLM * skyLM;
    return s2 * s2 * s2;
#endif
}

vec3 getLightColor() {
#if defined NETHER
    return vec3(0.0);
#elif defined END
    return endLightColor();
#else
    float elev    = sunDirWorld().y;
    vec3  sunRad  = sunColorAt(elev) * (4.6 * SUN_BRIGHTNESS * (0.35 + 0.65 * smoothstep(0.0, 0.42, elev)));
    vec3  moonRad = vec3(0.55, 0.68, 1.00) * (0.44 * MOON_BRIGHTNESS * smoothstep(-0.05, 0.12, -elev));
    return (sunRad + moonRad) * (1.0 - rainStrength * 0.80);
#endif
}

#ifdef FSH
float skyPixelDither() { return ign(gl_FragCoord.xy, 0.0); }
#else
float skyPixelDither() { return 0.5; }
#endif

float nightAmount() { return 1.0 - smoothstep(-0.30, -0.05, sunDirWorld().y); }

vec3 starField(vec3 rayDir, int octaveCount) {
    vec3  absD = abs(rayDir);
    vec2  faceUV;
    float faceID;
    if      (absD.y >= absD.x && absD.y >= absD.z) { faceUV = rayDir.xz / max(absD.y, 1e-4); faceID = rayDir.y > 0.0 ? 1.0 : 2.0; }
    else if (absD.x >= absD.z)                     { faceUV = rayDir.yz / max(absD.x, 1e-4); faceID = rayDir.x > 0.0 ? 3.0 : 4.0; }
    else                                           { faceUV = rayDir.xy / max(absD.z, 1e-4); faceID = rayDir.z > 0.0 ? 5.0 : 6.0; }

    vec3 accum = vec3(0.0);
    for (int band = 0; band < 3; ++band) {
        if (band >= octaveCount) break;
        float gridFreq = (band == 0) ? 60.0 : ((band == 1) ? 120.0 : 240.0);
        float thresh   = (band == 0) ? 0.955 : ((band == 1) ? 0.972 : 0.984);
        float baseRad  = (band == 0) ? 0.130 : ((band == 1) ? 0.100 : 0.080);
        float lumGain  = (band == 0) ? 2.20  : ((band == 1) ? 1.20  : 0.80);

        vec2  scaled = faceUV * gridFreq;
        vec2  cell   = floor(scaled);
        vec2  local  = fract(scaled) - 0.5;
        float bf     = float(band);
        float seed   = hash12(cell + faceID * 17.31 + bf * 37.7);
        if (seed < thresh) continue;

        vec2  jitter  = (hash22(cell + faceID * 5.1 + bf * 13.0) - 0.5) * 0.60;
        float radius  = baseRad * (0.55 + 0.90 * hash12(cell + 91.7));
        float core    = smoothstep(radius, 0.0, length(local - jitter));
        float twinkle = 0.78 + 0.22 * sin(frameTimeCounter * (1.5 + seed * 4.0) + seed * 60.0);
        vec3  tempCol = mix(vec3(1.00, 0.82, 0.62), vec3(0.68, 0.80, 1.00), hash12(cell + 7.3));
        accum += tempCol * (core * twinkle * lumGain);
    }
    return accum;
}

vec3 milkyWay(vec3 rayDir) {
    vec3  galNormal = normalize(vec3(0.35, 0.80, -0.50));
    float galLat    = dot(rayDir, galNormal);
    float envelope  = exp(-(galLat * galLat) * 62.5);
    if (envelope < 0.02) return vec3(0.0);

    vec3  axisU     = normalize(cross(galNormal, vec3(0.0, 1.0, 0.0)));
    vec3  axisV     = cross(galNormal, axisU);
    float galLon    = atan(dot(rayDir, axisV), dot(rayDir, axisU));
    vec2  galUV     = vec2(galLon * 2.6, galLat * 10.0);
    float starCloud = fbm(galUV * 1.4 + 3.0) * 0.65 + fbm(galUV * 4.2 + 17.0) * 0.35;
    float darkRift  = smoothstep(0.48, 0.64, fbm(galUV * 2.8 + 11.0));
    float bulge     = 0.45 + 0.55 * exp(-((galLon - 0.9) * (galLon - 0.9)) * 0.9);
    vec3  tint      = mix(vec3(0.62, 0.68, 0.90), vec3(1.00, 0.88, 0.72), bulge * 0.55);
    return tint * (envelope * (0.15 + 1.10 * starCloud) * bulge * (1.0 - 0.80 * darkRift * envelope));
}

vec3 auroraPalette(float normH) {
#if AURORA_PRESET == 0
    return mix(vec3(0.10, 1.00, 0.35), vec3(0.20, 0.85, 0.55), normH);
#elif AURORA_PRESET == 2
    return mix(vec3(0.05, 0.95, 0.80), vec3(0.20, 0.45, 1.00), normH);
#elif AURORA_PRESET == 3
    return mix(vec3(1.00, 0.20, 0.30), vec3(0.95, 0.35, 0.90), normH);
#elif AURORA_PRESET == 4
    return 0.5 + 0.5 * cos(TAU * (normH * 0.85 + vec3(0.0, 0.33, 0.67)));
#else
    vec3 lower = mix(vec3(0.10, 1.00, 0.38), vec3(0.15, 0.85, 0.68), smoothstep(0.0, 0.5, normH));
    return mix(lower, vec3(0.62, 0.25, 0.95), smoothstep(0.45, 1.0, normH));
#endif
}

vec3 aurora(vec3 rayDir, int stepCount, float jitter) {
    if (rayDir.y < 0.02) return vec3(0.0);
    float animT    = frameTimeCounter * AURORA_SPEED;
    vec2  domeUV   = rayDir.xz / (rayDir.y * 1.6 + 0.35);
    float azimuth  = atan(domeUV.y, domeUV.x);
    float elevBias = smoothstep(0.08, 0.85, rayDir.y);
    float invSteps = 1.0 / float(max(stepCount, 1));

    vec3 accum = vec3(0.0);
    for (int i = 0; i < 16; ++i) {
        if (i >= stepCount) break;
        float hFrac   = (float(i) + jitter) * invSteps;
        vec2  pos     = domeUV * mix(0.82, 1.22, hFrac);
        float meander = 2.2 * noise2D(vec2(pos.x * 0.55 + animT * 0.020, pos.y * 0.25 + 4.0))
                      + 0.9 * noise2D(vec2(pos.x * 1.40 + 3.0, pos.y * 0.50 + animT * 0.05));
        float phase   = pos.y * 0.85 + meander;
        float dBand   = (fract(phase) - 0.5) * 5.2;
        float curtain = exp(-dBand * dBand);
        float patchW  = smoothstep(0.40, 0.74, noise2D(pos * 0.42 + 9.0 + animT * 0.006));
        float striae  = 0.45 + 0.55 * noise2D(vec2(azimuth * 9.0, animT * 0.30 + phase * 0.3));
        float vShape  = pow(1.0 - hFrac, 1.3) * smoothstep(0.0, 0.08, hFrac);
        accum += auroraPalette(saturate(hFrac * 0.55 + elevBias * 0.55)) * (curtain * patchW * striae * vShape);
    }
    return accum * (2.0 * invSteps * smoothstep(0.02, 0.22, rayDir.y) * (1.0 - 0.55 * smoothstep(0.55, 1.0, rayDir.y)));
}

float auroraBiome = 0.0;

vec3 auroraStorm(vec3 rayDir, int stepCount, float jitter) {
    if (rayDir.y < 0.015) return vec3(0.0);
    float animT    = frameTimeCounter * AURORA_SPEED;
    float invSteps = 1.0 / float(max(stepCount, 1));
    float invY     = 1.0 / rayDir.y;
    vec3  accum    = vec3(0.0);

    for (int i = 0; i < 32; ++i) {
        if (i >= stepCount) break;
        float hFrac   = (float(i) + jitter) * invSteps;
        vec2  planeP  = rayDir.xz * ((1.0 + 2.4 * hFrac) * invY);
        float fold    = 1.9 * noise2D(vec2(planeP.x * 0.16 + animT * 0.012, planeP.y * 0.10 - animT * 0.008))
                      + 0.7 * noise2D(planeP * 0.45 + vec2(animT * 0.035, 2.0));
        float off     = abs(fract(planeP.y * 0.42 + planeP.x * 0.10 + fold) - 0.5);
        float ribbon  = exp(-off * off * 85.0) * 1.30 + 0.06 * exp(-off * off * 12.0);
        float tangent = planeP.x * 1.3 - planeP.y * 0.4 + fold * 2.0;
        float pillars = noise2D(vec2(tangent * 6.0 + animT * 0.20, animT * 0.25)) * 0.6
                      + noise2D(vec2(tangent * 17.0 - animT * 0.50, 3.0)) * 0.4;
        pillars = 0.20 + 1.25 * pillars * pillars;
        float activity = smoothstep(0.42, 0.75, noise2D(planeP * 0.075 + vec2(animT * 0.006, -animT * 0.004) + 4.0));
        float altEnv   = smoothstep(0.0, 0.05, hFrac) * exp(-hFrac * 2.4);
        vec3  oxyCol   = mix(vec3(0.42, 1.00, 0.08), vec3(0.05, 1.00, 0.14), smoothstep(0.0, 0.22, hFrac));
        oxyCol         = mix(oxyCol, auroraPalette(1.0), smoothstep(0.60, 1.0, hFrac) * 0.45);
        accum         += oxyCol * (ribbon * pillars * activity * altEnv);
    }
    return accum * (4.5 * invSteps * smoothstep(0.015, 0.16, rayDir.y));
}

vec3 auroraGroundGlow() {
#if defined SNOWY_AURORA && !defined NETHER && !defined END
    float visNight = AURORA_ALWAYS_ON > 0 ? (1.0 - smoothstep(-0.05, 0.16, sunDirWorld().y)) : nightAmount();
    float weight   = auroraBiome * visNight * (1.0 - rainStrength);
    if (weight < 0.002) return vec3(0.0);
    vec3 tapSum = auroraStorm(normalize(vec3( 0.35, 0.80,  0.20)), 6, 0.5)
                + auroraStorm(normalize(vec3(-0.45, 0.70, -0.30)), 6, 0.5)
                + auroraStorm(normalize(vec3( 0.10, 0.75, -0.55)), 6, 0.5);
    return tapSum * (0.0045 * SNOWY_AURORA_INTENSITY * weight);
#else
    return vec3(0.0);
#endif
}

#ifdef CLOUDS
float cloudCoverage() { return mix(CLOUD_COVERAGE, 0.90, rainStrength); }

float cloudDensityHi(vec2 uv) {
    vec2 warp = vec2(noise2D(uv * 0.6 + 4.0), noise2D(uv * 0.6 + 9.0)) * 0.70 - 0.35;
    float cov = cloudCoverage();
    return smoothstep(1.0 - cov, 1.0 - cov + 0.28, fbm(uv + warp));
}

float cloudDensityLo(vec2 uv) {
    float acc = 0.0, amp = 0.5;
    for (int i = 0; i < 3; ++i) { acc += amp * noise2D(uv); uv = uv * 2.03 + vec2(1.7, 9.2); amp *= 0.5; }
    float cov = cloudCoverage();
    return smoothstep(1.0 - cov, 1.0 - cov + 0.28, acc * (1.0 / 0.875));
}

vec4 cloudCumulus(vec3 rayDir, vec3 sunRad, vec3 lightDir, vec3 ambRad, bool fastMode) {
    if (rayDir.y <= 0.01) return vec4(0.0);
    vec2  uv   = (rayDir.xz / (rayDir.y + 0.12)) * 1.35 + vec2(0.0060, 0.0022) * (frameTimeCounter * CLOUD_SPEED);
    float dens = fastMode ? cloudDensityLo(uv) : cloudDensityHi(uv);
    if (dens <= 1e-3) return vec4(0.0);

    float selfTrans = 0.60;
    if (!fastMode) {
        vec2 sunStep = (lightDir.xz / (max(lightDir.y, 0.15) + 0.12)) * 0.10;
        selfTrans    = exp(-(cloudDensityHi(uv + sunStep) * 0.55 + cloudDensityHi(uv + sunStep * 2.2) * 0.45) * 2.6);
    }
    float rim    = pow(max(dot(rayDir, lightDir), 0.0), 6.0) * (1.0 - dens * 0.70);
    vec3  litCol = ambRad * (0.55 + 0.35 * (1.0 - dens)) + sunRad * ((0.30 + 0.85 * selfTrans + 0.90 * rim) * CLOUD_BRIGHTNESS);
    litCol  = mix(litCol, vec3(luma(litCol)) * 0.62, rainStrength * 0.70) * (1.0 - 0.40 * rainStrength);
    return vec4(litCol, dens * smoothstep(0.01, 0.20, rayDir.y) * 0.96);
}

float worleyFloccus2D(vec2 p) {
    vec2  base  = floor(p - 0.5);
    float minD2 = 4.0;
    for (int dy = 0; dy <= 1; ++dy) {
        for (int dx = 0; dx <= 1; ++dx) {
            vec2 cell = base + vec2(float(dx), float(dy));
            vec2 d    = (cell + 0.5 + (hash22(cell) - 0.5) * 0.78) - p;
            minD2     = min(minD2, dot(d, d));
        }
    }
    return 1.0 - saturate(sqrt(minD2) * 1.15);
}

// Gossamer Cirrostratus sheet + fine dappled Cirrocumulus ripples that preserve open blue sky
float evalHighCloudOpticalDepth(vec2 skyXZ, bool fastMode) {
    float hiCov = saturate(CLOUD_HIGH_COVERAGE);
    if (hiCov <= 0.005) return 0.0;

    float drift = frameTimeCounter * CLOUD_SPEED;
    vec2  uv    = skyXZ * (1.0 / 5200.0) + vec2(0.00085, 0.00032) * drift;

    vec2 jetWarp = vec2(
        fbm(uv * 0.80 + vec2(3.1, 7.4)),
        fbm(uv * 0.80 + vec2(12.8, 1.9))
    ) - 0.5;

    // Regional sky clearing so broad swaths of pure cobalt sky remain open
    float airMassWindow = smoothstep(0.96 - hiCov * 0.68, 1.32 - hiCov * 0.44, fbm(uv * 0.58 + jetWarp * 0.40 + 5.3));
    if (airMassWindow <= 0.002) return 0.0;

    // 1. Silky fibrous Cirrostratus veil (巻層雲)
    vec2  jetAx     = vec2(0.906, 0.423);
    vec2  sheared   = uv + jetWarp * 0.75;
    vec2  anisoSheet = vec2(dot(sheared, jetAx) * 0.62, dot(sheared, vec2(-jetAx.y, jetAx.x)) * 2.85);
    float csFibers  = fbm(anisoSheet * 1.35 + 11.0) * 0.68 + noise2D(anisoSheet * 3.80 + 23.0) * 0.32;
    float csVeil    = airMassWindow * smoothstep(0.32, 0.86, csFibers) * 0.38;

    if (fastMode) {
        return csVeil * CLOUD_HIGH_DENSITY;
    }

    // 2. Fine-grained dappled Cirrocumulus ripples (細かなうろこ雲の斑模様)
    float dappleZone = airMassWindow * smoothstep(0.42, 0.80, fbm(uv * 1.35 - jetWarp * 0.30 + 37.0));
    float ccDapple   = 0.0;
    if (dappleZone > 0.005) {
        vec2  cellUV = (uv + jetWarp * 0.18) * 31.0;
        float grains = worleyFloccus2D(cellUV) * 0.62 + worleyFloccus2D(cellUV * 2.15 + 7.1) * 0.38;
        ccDapple = dappleZone * smoothstep(0.30, 0.82, grains) * 0.44;
    }

    return (csVeil + ccDapple) * CLOUD_HIGH_DENSITY;
}

vec4 cloudCirrus(vec3 rayDir, vec3 sunDir, vec3 lightDir, vec3 ambRad, bool fastMode) {
    if (rayDir.y <= -0.015 || CLOUD_HIGH_COVERAGE <= 0.005) return vec4(0.0);

    const float R_EARTH = 68000.0;
    const float H_HIGH  = 2400.0;
    float r0   = R_EARTH + clamp(cameraPosition.y, -64.0, 1800.0);
    float rTop = R_EARTH + H_HIGH;
    float b    = r0 * rayDir.y;
    float disc = b * b - (r0 * r0 - rTop * rTop);
    if (disc <= 0.0) return vec4(0.0);

    float tHit = -b + sqrt(disc);
    vec2  skyP = cameraPosition.xz + rayDir.xz * tHit;
    float tau  = evalHighCloudOpticalDepth(skyP, fastMode);
    if (tau <= 0.002) return vec4(0.0);

    float hiSunElev = sunDir.y + 0.065;
    vec3  hiSunRad  = sunColorAt(hiSunElev) * (3.1 * SUN_BRIGHTNESS * smoothstep(-0.04, 0.14, hiSunElev));
    vec3  hiMoonRad = vec3(0.58, 0.72, 1.00) * (0.32 * MOON_BRIGHTNESS * smoothstep(-0.02, 0.14, -sunDir.y));
    vec3  hiDirect  = (hiSunRad + hiMoonRad) * (1.0 - rainStrength * 0.75);

    float cosTheta = dot(rayDir, lightDir);
    float icePhase = phaseHGn(cosTheta, 0.82) * 0.55 + phaseHGn(cosTheta, 0.35) * 0.45;
    float transSun = exp(-tau * 0.65);

    // Pure luminous ice-crystal scattering that blends gently with sky blue
    vec3 iceLit = ambRad * 1.08 + hiDirect * ((0.46 + 0.58 * icePhase) * transSun * CLOUD_BRIGHTNESS);

    float opacity   = (1.0 - exp(-tau * 0.92)) * (1.0 - 0.70 * rainStrength);
    float horizFade = smoothstep(-0.012, 0.055, rayDir.y) * exp(-tHit * 0.000028);
    return vec4(iceLit, saturate(opacity * horizFade));
}
#endif

vec3 skyZenith(float sinElev) {
#if defined PHYSICAL_SKY && !defined NETHER && !defined END
    return atmSky(vec3(0.0, 1.0, 0.0), 6);
#else
    return keyBlend(sinElev, vec3(0.005, 0.009, 0.028), vec3(0.030, 0.050, 0.170), vec3(0.100, 0.170, 0.420), vec3(0.120, 0.290, 0.800), vec3(0.100, 0.300, 0.940));
#endif
}

vec3 skyHorizon(float sinElev) {
#if defined PHYSICAL_SKY && !defined NETHER && !defined END
    vec3 sDir  = sunDirWorld();
    vec2 azVec = length(sDir.xz) > 0.01 ? normalize(sDir.xz) : vec2(1.0, 0.0);
    return atmSky(normalize(vec3(-azVec.y, 0.02, azVec.x)), 6);
#else
    return keyBlend(sinElev, vec3(0.014, 0.020, 0.046), vec3(0.150, 0.080, 0.150), vec3(0.900, 0.480, 0.280), vec3(0.640, 0.770, 0.980), vec3(0.700, 0.850, 1.000));
#endif
}

vec3 getSkyQ(vec3 rayDir, bool renderDisc, int qualityTier) {
#if defined NETHER
    return netherSky(rayDir, qualityTier >= 1);
#elif defined END
    return endSky(rayDir, qualityTier);
#else
    vec3  sunDir   = sunDirWorld();
    float elev     = sunDir.y;
    float nightFac = nightAmount();
    float clampedY = max(rayDir.y, 0.0);

#ifdef PHYSICAL_SKY
    int  scatSteps = (qualityTier >= 2) ? 12 : ((qualityTier == 1) ? 8 : 6);
    vec3 skyRad    = atmSky(rayDir, scatSteps);
    vec3 zenCol    = skyZenith(elev);
    vec3 horCol    = skyHorizon(elev);
#else
    vec3 zenCol = skyZenith(elev);
    vec3 horCol = skyHorizon(elev);
    vec3 skyRad = mix(zenCol, horCol, pow(1.0 - clampedY, 3.6));
    float twiAmt = (elev > 0.0 ? (1.0 - smoothstep(0.0, 0.34, elev)) : pow(1.0 - smoothstep(0.0, 0.18, -elev), 2.0)) * SUNSET_STRENGTH * (1.0 - 0.92 * rainStrength);
    if (twiAmt > 1e-3) {
        float cosAz   = dot(normalize(rayDir.xz + 1e-5), normalize(sunDir.xz + 1e-5));
        float sunBand = exp(-pow(rayDir.y / (0.10 + 0.20 * max(cosAz, 0.0)), 2.0));
        skyRad += vec3(1.00, 0.46, 0.16) * pow(max(cosAz, 0.0), 2.2) * sunBand * (twiAmt * 1.50);
        skyRad += vec3(0.85, 0.40, 0.62) * pow(max(-cosAz, 0.0), 1.5) * exp(-pow(rayDir.y / 0.16, 2.0)) * (twiAmt * 0.30);
        skyRad += vec3(0.55, 0.28, 0.55) * max(cosAz, 0.0) * exp(-pow((rayDir.y - 0.18) / 0.18, 2.0)) * (twiAmt * 0.20);
    }
#endif

    float cosSun   = max(dot(rayDir, sunDir), 0.0);
    vec3  sunTint  = sunColorAt(elev);
    float stormDim = 1.0 - rainStrength * 0.75;
#ifdef PHYSICAL_SKY
    const float HALO_SCALE = 0.40;
#else
    const float HALO_SCALE = 1.00;
#endif
    float sunAureole = pow(cosSun, 5.0) * 0.14 + pow(cosSun, 18.0) * (0.42 * (1.0 - smoothstep(0.0, 0.45, elev))) + pow(cosSun, 40.0) * 0.52 + pow(cosSun, 400.0) * 1.20;
    skyRad += sunTint * (sunAureole * SUN_GLOW * stormDim * HALO_SCALE);

    float cosMoon = max(dot(rayDir, -sunDir), 0.0);
    skyRad += vec3(0.52, 0.66, 1.00) * ((pow(cosMoon, 12.0) * 0.05 + pow(cosMoon, 160.0) * 0.22) * MOON_BRIGHTNESS * smoothstep(-0.05, 0.10, -elev) * (1.0 - rainStrength));

    skyRad = mix(vec3(luma(skyRad)), skyRad, SKY_SATURATION) * SKY_BRIGHTNESS;
    skyRad = mix(skyRad, vec3(luma(skyRad)) * 0.72, rainStrength * 0.85);
    skyRad = mix(skyRad, vec3(luma(mix(zenCol, horCol, 0.30))) * (0.72 * SKY_BRIGHTNESS), rainStrength * 0.75);

    vec3 celestialAdd = vec3(0.0);
    if (nightFac > 0.01 && qualityTier >= 1) {
        float clearSky = 1.0 - rainStrength;
        float elevMask = smoothstep(-0.02, 0.18, rayDir.y);
        celestialAdd  += starField(rayDir, qualityTier >= 2 ? 3 : 1) * (STAR_BRIGHTNESS * 0.90 * nightFac * clearSky * elevMask);
    #ifdef MILKY_WAY
        if (qualityTier >= 2) celestialAdd += milkyWay(rayDir) * (0.11 * STAR_BRIGHTNESS * nightFac * clearSky * elevMask);
    #endif
    }

#if defined AURORA || defined SNOWY_AURORA
    float auVis = AURORA_ALWAYS_ON > 0 ? (1.0 - smoothstep(-0.05, 0.16, elev)) : nightFac;
    if (auVis > 0.01 && qualityTier >= 1 && rayDir.y > 0.015) {
        float dither = (qualityTier >= 2) ? skyPixelDither() : 0.5;
        vec3  auEmit = vec3(0.0);
    #ifdef SNOWY_AURORA
        float snowZone = auroraBiome;
    #else
        float snowZone = 0.0;
    #endif
    #ifdef AURORA
        if (snowZone < 0.99) auEmit += aurora(rayDir, qualityTier >= 2 ? 14 : 8, dither) * (AURORA_INTENSITY * (1.0 - snowZone));
    #endif
    #ifdef SNOWY_AURORA
        if (snowZone > 0.01) auEmit += auroraStorm(rayDir, qualityTier >= 2 ? 32 : 10, dither) * (SNOWY_AURORA_INTENSITY * snowZone);
    #endif
        celestialAdd += auEmit * (auVis * (1.0 - rainStrength));
    }
#endif

    if (renderDisc) {
        float angRad = 0.019 * SUN_SIZE;
        skyRad += sunTint * (smoothstep(cos(angRad * 1.15), cos(angRad), dot(rayDir, sunDir)) * 40.0 * stormDim * smoothstep(-0.02, 0.03, elev) * (1.0 - rainStrength) * (1.0 - rainStrength));
    }

#ifdef CLOUDS
    if (qualityTier >= 1) {
        vec3 lDir     = lightDirWorld();
        vec3 cloudSun = getLightColor() * mix(1.0, 0.30, nightFac);
        vec3 cloudAmb = mix(zenCol, horCol, 0.42) * SKY_BRIGHTNESS * 0.92 + vec3(0.003, 0.005, 0.012);

        skyRad += celestialAdd;
    #ifdef CLOUD_CIRRUS
        vec4 hiDeck = cloudCirrus(rayDir, sunDir, lDir, cloudAmb, qualityTier < 2);
        skyRad = mix(skyRad, hiDeck.rgb, hiDeck.a);
    #endif

    #ifdef VOLUMETRIC_CLOUDS
        vec4 lowDeck = (qualityTier >= 2) ? vec4(0.0) : cloudsFlat(rayDir, lDir, cloudSun, cloudAmb);
    #else
        vec4 lowDeck = cloudCumulus(rayDir, cloudSun, lDir, cloudAmb, qualityTier < 2);
    #endif
        skyRad = mix(skyRad, lowDeck.rgb, lowDeck.a);
    } else {
        skyRad += celestialAdd;
    }
#else
    skyRad += celestialAdd;
#endif

    if (rayDir.y < 0.0) skyRad = mix(skyRad, horCol * 0.55, 1.0 - smoothstep(-0.25, 0.0, rayDir.y));
    return skyRad;
#endif
}

vec3 getSky(vec3 rayDir, bool renderDisc, bool renderClouds) { return getSkyQ(rayDir, renderDisc, renderClouds ? 2 : 0); }
vec3 getSkyReflection(vec3 rayDir) { return getSkyQ(rayDir, false, 1); }

#if !defined NETHER && !defined END
vec3 skyLightFrom(vec3 rayDir, vec3 zenCol, vec3 horCol) {
    vec3  sunDir   = sunDirWorld();
    float elev     = sunDir.y;
    float nightFac = nightAmount();

#ifdef PHYSICAL_SKY
    vec3 horTamed = horCol / (1.0 + luma(horCol) * 0.85);
    vec3 dome     = mix(zenCol, horTamed, pow(1.0 - max(rayDir.y, 0.0), 2.8));
    float ambGain = 0.82;
#else
    vec3 dome     = mix(zenCol, horCol, pow(1.0 - max(rayDir.y, 0.0), 2.4));
    float ambGain = 1.15;
#endif
    dome  = mix(vec3(luma(dome)), dome, 0.68);
    dome += sunColorAt(elev) * pow(max(dot(rayDir, sunDir), 0.0), 3.0) * (0.14 * (1.0 - smoothstep(0.0, 0.50, elev)));

    vec3 irrad = dome * (ambGain * AMBIENT_STRENGTH * (1.0 - rainStrength * 0.35));
    irrad     *= mix(vec3(1.0), vec3(0.76, 0.91, 1.22), SHADOW_BLUENESS * 0.78);
    irrad     += vec3(0.012, 0.018, 0.040) * (NIGHT_VISIBILITY * nightFac * AMBIENT_STRENGTH);

    if (rayDir.y < 0.0) {
        float directE = luma(getLightColor()) * max(lightDirWorld().y, 0.05);
        irrad = mix(irrad, vec3(0.28, 0.31, 0.24) * (directE * 0.28 + luma(irrad) * 0.55), 1.0 - smoothstep(-0.35, 0.0, rayDir.y));
    }
    return irrad;
}
#endif

vec3 getSkyLight(vec3 rayDir) {
#if defined NETHER
    vec3 baseTint = netherTint();
    vec3 horiz    = baseTint * 0.090;
    vec3 dirRad   = rayDir.y > 0.0 ? mix(horiz, baseTint * 0.034, rayDir.y) : mix(horiz, mix(baseTint, NTH_GLOW, 0.65) * 0.20, -rayDir.y);
    return dirRad * (AMBIENT_STRENGTH * NETHER_AMBIENT);
#elif defined END
    return endAmbientLight(rayDir);
#else
    float elev = sunDirWorld().y;
    return skyLightFrom(rayDir, skyZenith(elev) * SKY_BRIGHTNESS, skyHorizon(elev) * SKY_BRIGHTNESS);
#endif
}

vec3 getSkyAmbient() {
#if defined NETHER
    return getSkyLight(vec3(0.0, 1.0, 0.0)) * 0.45 + getSkyLight(vec3(0.0, 0.0, 1.0)) * 0.35 + getSkyLight(vec3(0.0, -1.0, 0.0)) * 0.20;
#elif defined END
    return getSkyLight(vec3(0.0, 1.0, 0.0)) * 0.50 + getSkyLight(vec3(0.0, 0.0, 1.0)) * 0.30 + getSkyLight(vec3(0.0, -1.0, 0.0)) * 0.20;
#else
    float elev   = sunDirWorld().y;
    vec3  zenCol = skyZenith(elev)  * SKY_BRIGHTNESS;
    vec3  horCol = skyHorizon(elev) * SKY_BRIGHTNESS;
    return skyLightFrom(vec3(0.0, 1.0, 0.0), zenCol, horCol) * 0.55
         + skyLightFrom(normalize(vec3( 0.80, 0.30,  0.20)), zenCol, horCol) * 0.30
         + skyLightFrom(normalize(vec3(-0.80, 0.30, -0.20)), zenCol, horCol) * 0.15;
#endif
}

float skyOcclusion(float skyLM) {
#if defined NETHER || defined END
    return 1.0;
#else
    return skyLM * skyLM;
#endif
}

#endif

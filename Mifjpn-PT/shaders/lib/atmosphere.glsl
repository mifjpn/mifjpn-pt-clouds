// Mifjpn-PT Clouds Edition | Crisp Cerulean-Cobalt Spherical Atmosphere & Biome Haze
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_ATMOSPHERE_GLSL
#define MIFJPN_PT_ATMOSPHERE_GLSL
#if !defined NETHER && !defined END

const float PLANET_RADIUS_KM = 6360.0;
const float ATMOS_TOP_KM     = 6420.0;
const float SCALE_HEIGHT_R   = 8.2;
const float SCALE_HEIGHT_M   = 1.15;

// Crisp Rayleigh + low clear-air Mie turbidity + enriched Chappuis ozone for vivid sky blue
const vec3  BETA_RAYLEIGH    = vec3(5.600e-3, 13.420e-3, 34.400e-3);
const float BETA_MIE_SCAT    = 2.250e-3;
const float BETA_MIE_EXT     = 2.500e-3;
const vec3  BETA_OZONE       = vec3(0.920e-3, 2.420e-3, 0.105e-3);
const float MIE_ANISOTROPY   = 0.78;

const float SOLAR_IRRADIANCE = 37.0;
const float LUNAR_IRRADIANCE = 1.20;

const int MIFJPN_CAT_TAIGA         = 1;
const int MIFJPN_CAT_EXTREME_HILLS = 2;
const int MIFJPN_CAT_JUNGLE        = 3;
const int MIFJPN_CAT_MESA          = 4;
const int MIFJPN_CAT_PLAINS        = 5;
const int MIFJPN_CAT_ICY           = 7;
const int MIFJPN_CAT_BEACH         = 9;
const int MIFJPN_CAT_FOREST        = 10;
const int MIFJPN_CAT_OCEAN         = 11;
const int MIFJPN_CAT_RIVER         = 13;
const int MIFJPN_CAT_SWAMP         = 14;
const int MIFJPN_CAT_MUSHROOM      = 15;
const int MIFJPN_CAT_MOUNTAIN      = 17;
const int MIFJPN_CAT_DESERT        = 12;

float atmChapman(float rScaled, float hScaled, float cosZenith) {
    float rootR = sqrt(rScaled + hScaled);
    if (cosZenith >= 0.0) return (rootR / (rootR * cosZenith + 1.0)) * exp(-hScaled);
    float sinZenith = sqrt(max(1.0 - cosZenith * cosZenith, 0.0));
    float grazeArg  = sinZenith * (rScaled + hScaled);
    return 2.0 * sqrt(grazeArg) * exp(min(rScaled - grazeArg, 60.0))
         - (rootR / (1.0 - rootR * cosZenith)) * exp(-hScaled);
}

vec3 atmOpticalDepth(float altKm, float cosZenith) {
    float massR = atmChapman(PLANET_RADIUS_KM / SCALE_HEIGHT_R, altKm / SCALE_HEIGHT_R, cosZenith);
    float massM = atmChapman(PLANET_RADIUS_KM / SCALE_HEIGHT_M, altKm / SCALE_HEIGHT_M, cosZenith);
    float massO = altKm < 25.0
                ? atmChapman((PLANET_RADIUS_KM + 25.0) / SCALE_HEIGHT_R, 0.0, cosZenith)
                : massR * exp(altKm / SCALE_HEIGHT_R);
    return BETA_RAYLEIGH * (SCALE_HEIGHT_R * massR)
         + BETA_MIE_EXT  * (SCALE_HEIGHT_M * massM)
         + BETA_OZONE    * (15.0 * massO);
}

vec3  atmTransmittance(float altKm, float cosZenith) { return exp(-atmOpticalDepth(altKm, cosZenith)); }
float atmPhaseR(float cosTheta) { return 0.05968310366 * (1.0 + cosTheta * cosTheta); }

float atmPhaseM(float cosTheta) {
    const float g  = MIE_ANISOTROPY;
    const float g2 = g * g;
    float denom    = max(1.0 + g2 - 2.0 * g * cosTheta, 1e-4);
    return 0.11936620732 * ((1.0 - g2) * (1.0 + cosTheta * cosTheta)) / ((2.0 + g2) * denom * sqrt(denom));
}

float atmEyeHeight() { return 0.2 + clamp((cameraPosition.y - 63.0) * 1e-3, 0.0, 3.0); }

vec3 atmScatter(vec3 viewDir, vec3 lightDir, float eyeKm, int stepCount) {
    vec3  origin = vec3(0.0, PLANET_RADIUS_KM + eyeKm, 0.0);
    float projB  = dot(origin, viewDir);
    float disc   = projB * projB - dot(origin, origin) + ATMOS_TOP_KM * ATMOS_TOP_KM;
    float rayEnd = -projB + sqrt(max(disc, 0.0));
    float cosAng = dot(viewDir, lightDir);

    vec3  integR  = vec3(0.0);
    vec3  integM  = vec3(0.0);
    vec3  tauView = vec3(0.0);
    float prevT   = 0.0;
    float invN    = 1.0 / float(max(stepCount, 1));

    for (int i = 0; i < 16; ++i) {
        if (i >= stepCount) break;
        float u      = float(i + 1) * invN;
        float currT  = rayEnd * (u * u);
        float segLen = currT - prevT;
        vec3  pos    = origin + viewDir * (prevT + 0.5 * segLen);
        prevT        = currT;

        float rad  = length(pos);
        float alt  = max(rad - PLANET_RADIUS_KM, 0.0);
        float rhoR = exp(-alt * (1.0 / SCALE_HEIGHT_R));
        float rhoM = exp(-alt * (1.0 / SCALE_HEIGHT_M));
        float rhoO = max(0.0, 1.0 - abs(alt - 25.0) * (1.0 / 15.0));

        vec3 dTau  = (BETA_RAYLEIGH * rhoR + BETA_MIE_EXT * rhoM + BETA_OZONE * rhoO) * segLen;
        vec3 atten = exp(-(tauView + 0.5 * dTau) - atmOpticalDepth(alt, dot(pos, lightDir) / rad));

        integR  += atten * (rhoR * segLen);
        integM  += atten * (rhoM * segLen);
        tauView += dTau;
    }

    // Gentle horizon airglow lift for clean pale-cyan sea horizon
    float horizLift   = exp(-max(viewDir.y, 0.0) * 14.0) * smoothstep(-0.08, 0.25, lightDir.y);
    vec3  primaryScat = integR * (BETA_RAYLEIGH * atmPhaseR(cosAng))
                      + integM * (BETA_MIE_SCAT * (atmPhaseM(cosAng) + 0.028 * horizLift));
    float multiGain   = mix(0.095, 0.014, smoothstep(-0.10, 0.22, lightDir.y));
    return primaryScat + (integR * BETA_RAYLEIGH + integM * BETA_MIE_SCAT) * multiGain;
}

vec3 atmSky(vec3 rawDir, int stepCount) {
    vec3  sunDir   = sunDirWorld();
    vec3  safeDir  = normalize(vec3(rawDir.x, max(rawDir.y, 0.0) + 0.0015, rawDir.z));
    float eyeKm    = atmEyeHeight();
    vec3  radiance = vec3(0.0);

    if (sunDir.y > -0.30) radiance += atmScatter(safeDir, sunDir, eyeKm, stepCount) * SOLAR_IRRADIANCE;
    if (sunDir.y <  0.12) radiance += atmScatter(safeDir, -sunDir, eyeKm, stepCount) * (vec3(0.80, 0.90, 1.12) * LUNAR_IRRADIANCE * MOON_BRIGHTNESS);
    radiance += vec3(0.0016, 0.0024, 0.0044) * (1.0 - smoothstep(-0.10, 0.05, sunDir.y));
    return radiance;
}

vec3 atmSunTint(float sinElev) {
    float eyeKm = atmEyeHeight();
    return atmTransmittance(eyeKm, sinElev) / max(atmTransmittance(eyeKm, 1.0), vec3(1e-4));
}

void biomeAtmosphereTarget(out vec3 hazeTint, out float hazeDens, out float lowMist, out float heatDistort, out float oceanSpray) {
    int  cat    = biome_category;
    bool isSnow = (biome_precipitation == 2);
    hazeTint = vec3(1.0); hazeDens = 0.85; lowMist = 0.22; heatDistort = 0.0; oceanSpray = 0.0;

    if      (cat == MIFJPN_CAT_SWAMP)  { hazeTint = vec3(0.70, 0.74, 0.50); hazeDens = 2.60; lowMist = 0.95; }
    else if (cat == MIFJPN_CAT_DESERT) { hazeTint = vec3(1.16, 0.94, 0.70); hazeDens = 1.60; lowMist = 0.00; heatDistort = 1.00; }
    else if (cat == MIFJPN_CAT_MESA)   { hazeTint = vec3(1.18, 0.86, 0.64); hazeDens = 1.50; lowMist = 0.00; heatDistort = 0.85; }
    else if (cat == MIFJPN_CAT_JUNGLE) { hazeTint = vec3(0.92, 1.02, 0.90); hazeDens = 1.85; lowMist = 0.80; }
    else if (cat == MIFJPN_CAT_OCEAN || cat == MIFJPN_CAT_RIVER || cat == MIFJPN_CAT_BEACH) {
        hazeTint = vec3(0.92, 0.98, 1.06); hazeDens = 1.05; lowMist = 0.12;
        oceanSpray = (cat == MIFJPN_CAT_RIVER) ? 0.35 : 0.80;
    } else if (cat == MIFJPN_CAT_EXTREME_HILLS || cat == MIFJPN_CAT_MOUNTAIN) {
        hazeTint = vec3(0.94, 0.98, 1.06); hazeDens = 0.42; lowMist = 0.08;
    } else if (cat == MIFJPN_CAT_MUSHROOM) {
        hazeTint = vec3(1.02, 0.92, 1.06); hazeDens = 1.10; lowMist = 0.40;
    } else if (cat == MIFJPN_CAT_PLAINS && biome_precipitation == 0 && temperature > 1.4) {
        hazeTint    = mix(vec3(1.12, 0.98, 0.74), vec3(0.97, 0.99, 1.02), rainStrength);
        hazeDens    = mix(1.15, 1.00, rainStrength);
        lowMist     = mix(0.05, 0.40, rainStrength);
        heatDistort = 0.40 * (1.0 - rainStrength);
    } else if (cat == MIFJPN_CAT_FOREST || cat == MIFJPN_CAT_PLAINS || cat == MIFJPN_CAT_TAIGA) {
        lowMist = 0.38;
    }

    if (isSnow) {
        bool highPeak = (cat == MIFJPN_CAT_MOUNTAIN || cat == MIFJPN_CAT_EXTREME_HILLS);
        hazeTint = vec3(0.80, 0.90, 1.14); hazeDens = highPeak ? 0.50 : 0.88; lowMist = 0.22; heatDistort = 0.0;
    }

    hazeDens *= mix(0.45, 1.0, exp(-max(cameraPosition.y - 90.0, 0.0) * (1.0 / 160.0)));
    float k = BIOME_ATMOSPHERE;
    hazeTint = mix(vec3(1.0), hazeTint, k); hazeDens = mix(1.0, hazeDens, k);
    lowMist *= k; heatDistort *= k; oceanSpray *= k;
}

float groundMistDepth(float yA, float yB, float rayLen, float scaleH) {
    const float SEA_BASE = 63.0;
    const float TAPER_H  = 1.5;
    float loY = min(yA, yB);
    float hiY = max(yA, yB);
    if (hiY <= SEA_BASE) return 0.0;

    float h0   = max(loY - SEA_BASE, 0.0);
    float h1   = hiY - SEA_BASE;
    float span = h1 - h0;
    float dY   = hiY - loY;
    float hMid = 0.5 * (h0 + h1);
    float midD = max(exp(-hMid / scaleH) - exp(-hMid / TAPER_H), 0.0);
    if (dY < 1e-3) return midD * rayLen;

    float colIntegral = span > 0.02
        ? (exp(-h0 / scaleH) - exp(-h1 / scaleH)) * scaleH - (exp(-h0 / TAPER_H) - exp(-h1 / TAPER_H)) * TAPER_H
        : midD * span;
    return max(colIntegral / dY, 0.0) * rayLen;
}

#endif
#endif

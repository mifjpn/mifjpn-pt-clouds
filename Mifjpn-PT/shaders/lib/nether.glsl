// Mifjpn-PT | Nether Realm: Volumetric Soot, Magma Crust, Updraft Embers & Underglow
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_NETHER_GLSL
#define MIFJPN_PT_NETHER_GLSL
#ifdef NETHER

#if NETHER_PALETTE == 1
    #define NTH_AIR   vec3(1.00, 0.40, 0.36)
    #define NTH_GLOW  vec3(0.95, 0.10, 0.05)
    #define NTH_EMBER vec3(1.00, 0.24, 0.08)
    #define NTH_SOOT  vec3(0.055, 0.015, 0.017)
#elif NETHER_PALETTE == 2
    #define NTH_AIR   vec3(0.84, 0.79, 0.76)
    #define NTH_GLOW  vec3(1.00, 0.46, 0.18)
    #define NTH_EMBER vec3(1.00, 0.58, 0.26)
    #define NTH_SOOT  vec3(0.044, 0.041, 0.041)
#elif NETHER_PALETTE == 3
    #define NTH_AIR   vec3(0.52, 0.84, 1.00)
    #define NTH_GLOW  vec3(0.08, 0.72, 0.95)
    #define NTH_EMBER vec3(0.32, 0.92, 1.00)
    #define NTH_SOOT  vec3(0.016, 0.033, 0.044)
#else
    #define NTH_AIR   vec3(1.00, 0.62, 0.45)
    #define NTH_GLOW  vec3(1.00, 0.36, 0.08)
    #define NTH_EMBER vec3(1.00, 0.50, 0.12)
    #define NTH_SOOT  vec3(0.060, 0.030, 0.022)
#endif

const float NETHER_LAVA_SEA = 31.0;

float netherTime() { return frameTimeCounter * NETHER_SPEED; }

vec3 netherTint() {
    vec3 linFog  = toLinear(fogColor);
    vec3 normFog = linFog / max(luma(linFog), 2e-3);
    return mix(NTH_AIR, normFog, 0.30);
}

float evalNetherField3D(vec3 p) {
    vec3 cell = floor(p);
    vec3 frac = p - cell;
    vec3 w    = frac * frac * (3.0 - 2.0 * frac);

    float c000 = hash13(cell);
    float c100 = hash13(cell + vec3(1.0, 0.0, 0.0));
    float c010 = hash13(cell + vec3(0.0, 1.0, 0.0));
    float c110 = hash13(cell + vec3(1.0, 1.0, 0.0));
    float c001 = hash13(cell + vec3(0.0, 0.0, 1.0));
    float c101 = hash13(cell + vec3(1.0, 0.0, 1.0));
    float c011 = hash13(cell + vec3(0.0, 1.0, 1.0));
    float c111 = hash13(cell + vec3(1.0, 1.0, 1.0));

    float z0 = mix(mix(c000, c100, w.x), mix(c010, c110, w.x), w.y);
    float z1 = mix(mix(c001, c101, w.x), mix(c011, c111, w.x), w.y);
    return mix(z0, z1, w.z);
}

float netherLavaLight(float worldY) {
    return exp(-max(worldY - NETHER_LAVA_SEA, 0.0) * (1.0 / 18.0));
}

float netherFlare(vec2 worldXZ) {
    float t     = netherTime();
    float surge = noise2D(worldXZ * 0.018 + vec2(t * 0.035, -t * 0.021));
    return 0.40 + 1.25 * surge * surge;
}

vec3 netherUnderglow(vec3 worldPos, vec3 worldN) {
    float downWeight = 0.55 - 0.45 * worldN.y;
    return NTH_GLOW * (0.24 * NETHER_GLOW * netherLavaLight(worldPos.y) * netherFlare(worldPos.xz) * downWeight);
}

vec3 netherSky(vec3 rayDir, bool withDetail) {
    float nadirBias = 1.0 - smoothstep(-0.60, 0.30, rayDir.y);
    vec3  cavernCol = NTH_SOOT * netherTint() * 0.90 + NTH_GLOW * ((0.012 + 0.050 * nadirBias) * NETHER_GLOW);
    if (withDetail) {
        float t    = netherTime();
        vec3  adv  = rayDir * 2.6 + vec3(t * 0.012, -t * 0.020, 0.0);
        float bill = evalNetherField3D(adv) * 0.60 + evalNetherField3D(adv * 2.9 + 4.0) * 0.40;
        cavernCol *= 0.55 + 0.90 * bill;
    }
    return cavernCol * AMBIENT_STRENGTH;
}

float netherSmokeDensity(vec3 worldPos, float rayDist, out float bankCore) {
    float t   = netherTime();
    vec3  crd = worldPos * vec3(0.060, 0.080, 0.060) + vec3(t * 0.014, -t * 0.030, t * 0.008);
    float f   = evalNetherField3D(crd + evalNetherField3D(crd * 0.5 + 7.0) * 0.80);
    if (rayDist < 64.0) {
        f = f * 0.62 + evalNetherField3D(crd * 2.7 + vec3(3.1, -t * 0.030, 1.7)) * 0.38;
    }
    bankCore = smoothstep(0.50, 0.76, f);
    float seaLayer  = 1.0 - smoothstep(33.0, 64.0, worldPos.y);
    float roofLayer = smoothstep(98.0, 124.0, worldPos.y);
    return (0.0060 + bankCore * (0.050 + 0.045 * seaLayer + 0.020 * roofLayer)) * NETHER_SMOKE_DENSITY * FOG_DENSITY;
}

vec4 netherSmoke(vec3 rayOrigin, vec3 rayDir, float geomDist, float jitter, vec3 hitEmit) {
    const float MARCH_LIMIT = 120.0;
    float marchEnd = min(geomDist, MARCH_LIMIT);
    vec3  ambSoot  = NTH_SOOT * netherTint() * (1.05 * AMBIENT_STRENGTH);
    vec3  accumRad = vec3(0.0);
    float trans    = 1.0;
    float prevT    = 0.0;
    float invSteps = 1.0 / float(max(NETHER_SMOKE_STEPS, 1));

    for (int i = 0; i < 24; ++i) {
        if (i >= NETHER_SMOKE_STEPS) break;
        float nextT = marchEnd * pow(float(i + 1) * invSteps, 1.60);
        float seg   = nextT - prevT;
        float midT  = prevT + seg * jitter;
        vec3  pos   = rayOrigin + rayDir * midT;

        float bankCore;
        float extA      = 1.0 - exp(-netherSmokeDensity(pos, midT, bankCore) * seg);
        float rimExpose = 1.0 - 0.70 * bankCore;
        float magmaIll  = exp(-max(pos.y - NETHER_LAVA_SEA, 0.0) * (1.0 / 11.0)) * netherFlare(pos.xz);

        vec3 stepRad = ambSoot * (1.0 - 0.55 * bankCore)
                     + NTH_GLOW * ((0.010 + 0.15 * magmaIll * rimExpose) * NETHER_GLOW)
                     + hitEmit  * (exp(-(geomDist - midT) * 0.22) * rimExpose);

        accumRad += stepRad * (trans * extA);
        trans    *= (1.0 - extA);
        prevT     = nextT;
        if (trans < 0.02) break;
    }

    if (geomDist > MARCH_LIMIT) {
        float farA = 1.0 - exp(-min(geomDist - MARCH_LIMIT, 400.0) * 0.012 * NETHER_SMOKE_DENSITY * FOG_DENSITY);
        accumRad  += netherSky(rayDir, false) * (trans * farA);
        trans     *= (1.0 - farA);
    }
    return vec4(accumRad, trans);
}

vec3 netherEmbers(vec3 rayDir, float geomDist) {
    const float GRID_SIZE = 2.6;
    const float MAX_SPAN  = 30.0;

    float t        = netherTime();
    vec3  origin   = cameraPosition + vec3(sin(t * 0.23) * 0.50, -t * 0.60, cos(t * 0.19) * 0.50);
    float spanLim  = min(geomDist, MAX_SPAN);
    float pxAngle  = 2.0 / max(gbufferProjection[1][1] * viewHeight, 1.0);
    float spawnCap = min(0.20 * NETHER_EMBER_AMOUNT, 0.85);

    vec3 gridP  = origin * (1.0 / GRID_SIZE);
    vec3 cellID = floor(gridP);
    vec3 stepS  = sign(rayDir);
    vec3 tDelta = 1.0 / max(abs(rayDir), vec3(1e-5));
    vec3 tCross = (cellID + max(stepS, 0.0) - gridP) * stepS * tDelta;
    tCross      = mix(tCross, vec3(1e9), step(abs(rayDir), vec3(1e-5)));

    vec3 accum = vec3(0.0);
    for (int stepIdx = 0; stepIdx < 32; ++stepIdx) {
        float rSpawn = hash13(cellID);
        if (rSpawn < spawnCap) {
            float rTrait = hash13(cellID + 5.5);
            vec3  jitter = vec3(hash13(cellID + 11.3), hash13(cellID + 27.1), hash13(cellID + 53.9)) - 0.5;
            vec3  sparkP = (cellID + 0.5 + jitter * 0.70) * GRID_SIZE;
            sparkP.xz   += vec2(sin(t * (1.3 + rTrait * 5.0) + rTrait * 40.0), cos(t * (1.1 + rTrait * 4.0) + rTrait * 70.0)) * 0.22;

            vec3  rel   = sparkP - origin;
            float projT = dot(rel, rayDir);
            if (projT > 0.5 && projT < spanLim) {
                vec3  miss  = rel - rayDir * projT;
                miss.y     *= 0.50;
                float d2    = dot(miss, miss);
                float r0    = 0.007 + 0.011 * rTrait;
                float rEff  = max(r0, projT * pxAngle * 0.90);
                float rEff2 = rEff * rEff;

                float kernel  = (exp(-d2 / rEff2) + 0.12 * exp(-d2 / (rEff2 * 10.0))) * ((r0 * r0) / rEff2);
                float phase   = fract(t * (0.07 + 0.10 * rTrait) + rTrait * 13.0);
                float lifeEnv = smoothstep(0.0, 0.06, phase) * (1.0 - phase);
                float flicker = 0.70 + 0.30 * sin(t * (9.0 + rTrait * 30.0) + rTrait * 100.0);
                float distEnv = smoothstep(1.0, 4.0, projT) * (1.0 - projT * (1.0 / MAX_SPAN));

                vec3 sparkCol = mix(NTH_EMBER, NTH_EMBER * 0.60 + vec3(0.40, 0.30, 0.12), lifeEnv * lifeEnv);
                accum += sparkCol * (kernel * lifeEnv * flicker * distEnv);
            }
        }
        float nextCellT = min(tCross.x, min(tCross.y, tCross.z));
        if (nextCellT * GRID_SIZE > spanLim) break;
        vec3 advance = step(tCross, vec3(nextCellT));
        cellID += stepS  * advance;
        tCross += tDelta * advance;
    }
    return accum * 4.0;
}

vec2 netherHeat(vec2 screenUV, float geomDist) {
    float t      = netherTime();
    float aspect = viewWidth / max(viewHeight, 1.0);
    vec2  crd    = screenUV * vec2(aspect, 1.0) * 26.0;
    float wA     = noise2D(crd + vec2(0.0, -t * 2.2)) - 0.5;
    float wB     = noise2D(crd * 1.9 + vec2(4.0, -t * 3.1)) - 0.5;
    return vec2(wA + 0.5 * wB, 0.35 * (wB - wA)) * (smoothstep(6.0, 45.0, geomDist) * 0.0030 * NETHER_HEAT);
}

vec4 netherLava(vec3 worldPos, float normalUp, float vanillaLuma, float mipBlur) {
    float t     = netherTime();
    vec2  uv    = (abs(normalUp) > 0.5 ? worldPos.xz : vec2(worldPos.x + worldPos.z, worldPos.y * 0.6 + t * 0.35)) * 0.50;
    vec2  drift = vec2(t * 0.016, t * 0.011);
    vec2  warp  = vec2(noise2D(uv * 0.55 + drift * 2.0 + 3.0), noise2D(uv * 0.55 - drift * 1.5 + 9.0)) - 0.5;
    float octA  = noise2D(uv + warp * 1.3 + drift);
    float octB  = noise2D(uv * 2.4 - warp * 0.9 - drift * 1.7 + 5.0);

    float crustField = octA * 0.62 + octB * 0.38;
    float fissure    = pow(1.0 - abs(crustField * 2.0 - 1.0), 7.0);
    float openMelt   = smoothstep(0.55, 0.76, noise2D(uv * 0.42 - drift * 0.8 + 21.0) * 0.70 + octB * 0.30);
    float throb      = 0.85 + 0.15 * sin(t * 0.70 + octA * 9.0);

    float temp = mix(saturate(max(openMelt * (0.45 + 0.45 * octB), fissure * 0.90) * throb + (vanillaLuma - 0.5) * 0.25), 0.30, mipBlur);
    vec3  col  = mix(vec3(0.150, 0.055, 0.040), vec3(0.86, 0.11, 0.02), smoothstep(0.05, 0.35, temp));
    col        = mix(col, vec3(1.00, 0.44, 0.06), smoothstep(0.30, 0.65, temp));
    col        = mix(col, vec3(1.00, 0.86, 0.48), smoothstep(0.80, 1.00, temp));
    return vec4(col, mix(0.035, 1.0, smoothstep(0.05, 0.60, temp)));
}

#endif
#endif

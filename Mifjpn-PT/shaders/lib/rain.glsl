// Mifjpn-PT | Wind-Sheared 3D DDA Rain Simulation, Cylindrical Shells & Drop Glint
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_RAIN_GLSL
#define MIFJPN_PT_RAIN_GLSL

#include "/lib/sky.glsl"

const float RAIN_FALL_SPEED        = 9.0;
const float RAIN_WIND_ANGLE        = 0.55;
const float RAIN_STREAK_HALF_WIDTH = 0.0045;
const float RAIN_CELL_HEIGHT       = 1.7;

vec2 rainWindDir() { return vec2(cos(RAIN_WIND_ANGLE), sin(RAIN_WIND_ANGLE)); }

vec2 rainWind() {
    float t    = frameTimeCounter;
    float gust = 0.62 + 0.30 * sin(t * 0.19) * sin(t * 0.071 + 1.7) + 0.16 * sin(t * 0.83 + 0.6) * sin(t * 0.37);
    return rainWindDir() * (0.17 * RAIN_WIND * gust * (0.35 + 0.65 * rainStrength));
}

float rainStreak(vec2 cellUV, vec2 cellID, float colWidth, float pxWorld, float occupancy) {
    vec2 seedA = hash22(cellID);
    if (seedA.x > occupancy) return 0.0;
    vec2  seedB    = hash22(cellID + 17.17);
    float normLen  = (0.45 + 0.60 * seedB.x) * (1.0 / RAIN_CELL_HEIGHT);
    float centerX  = 0.15 + 0.70 * seedA.y;
    float centerY  = 0.50 * normLen + (1.0 - normLen) * seedB.y;
    float effHalfW = max(RAIN_STREAK_HALF_WIDTH, pxWorld * 0.75);
    float across   = 1.0 - smoothstep(effHalfW * 0.35, effHalfW * 1.50, abs(cellUV.x - centerX) * colWidth);
    float along    = 1.0 - smoothstep(0.45, 1.0, abs(cellUV.y - centerY) / (0.50 * normLen));
    return across * along * (0.45 + 0.55 * hash12(cellID + 5.31)) * pow(RAIN_STREAK_HALF_WIDTH / effHalfW, 0.60);
}

float rainQuadStreaks(vec2 quadUV, float pxWidth, float occupancy) {
    const float NUM_LANES = 6.0;
    float lanePos = quadUV.x * NUM_LANES;
    float laneIdx = floor(lanePos);
    float fallPos = quadUV.y * (4.0 / RAIN_CELL_HEIGHT) + hash11(laneIdx + 0.5) * 23.0;
    float rowIdx  = floor(fallPos);
    return rainStreak(vec2(lanePos - laneIdx, fallPos - rowIdx), vec2(laneIdx, rowIdx), 1.0 / NUM_LANES, pxWidth, occupancy);
}

float rainShell(float azim, float tanElev, float horizLen, float radius, float shellSeed, float windSkew, float occupancy) {
    float laneCount = floor((TAU * radius) / (0.12 + 0.008 * radius) + 0.5);
    float colWidth  = (TAU * radius) / laneCount;
    float hitY      = tanElev * radius;
    float uCoord    = (azim * (1.0 / TAU) + 0.5) * laneCount + (windSkew * hitY) / colWidth;
    float laneIdx   = floor(uCoord);
    float fracX     = uCoord - laneIdx;
    laneIdx         = mod(laneIdx, laneCount);
    float laneRand  = hash12(vec2(laneIdx, shellSeed) + 0.37);
    float vCoord    = (hitY + cameraPosition.y + RAIN_FALL_SPEED * (0.85 + 0.30 * laneRand) * frameTimeCounter) * (1.0 / RAIN_CELL_HEIGHT) + laneRand * 31.0;
    float rowIdx    = floor(vCoord);
    float pxWorld   = ((radius / horizLen) * 2.0) / max(gbufferProjection[1][1] * viewHeight, 1.0);
    return rainStreak(vec2(fracX, vCoord - rowIdx), vec2(laneIdx + shellSeed * 53.0, rowIdx), colWidth, pxWorld, occupancy);
}

vec2 distantRain(vec3 worldDir, float geomDist, float hazeExt) {
    float pitchFade = 1.0 - smoothstep(0.38, 0.78, abs(worldDir.y));
    if (pitchFade <= 0.0) return vec2(0.0);

    float horizLen  = max(length(worldDir.xz), 1e-4);
    float azim      = atan(worldDir.z, worldDir.x);
    float tanElev   = worldDir.y / horizLen;
    float windSkew  = dot(rainWind(), vec2(-worldDir.z, worldDir.x)) / horizLen;
    float occupancy = saturate(0.55 * RAIN_AMOUNT * (0.40 + 0.60 * rainStrength));
    vec2  accum     = vec2(0.0);
    float shellR    = 2.9;

    for (int s = 0; s < 10; ++s) {
        float hitDist = shellR / horizLen;
        float unocc   = smoothstep(hitDist, hitDist * 1.12 + 0.75, geomDist);
        if (unocc > 0.0) {
            float op = rainShell(azim, tanElev, horizLen, shellR, float(s + 1), windSkew, occupancy) * unocc * exp(-hitDist * hazeExt);
            accum += op * vec2(1.0, exp(-shellR * 0.16));
        }
        shellR *= 1.42;
    }
    return accum * pitchFade;
}

vec2 rainGrid(vec3 rayOrigin, vec3 rayDir, vec2 windSlant, float tStart, float tEnd, float geomDist, float hazeExt, float cellWidth, float dropPeriod, float gridSeed, float occupancy, float pxAngle, float shelterVis) {
    float maxT = min(tEnd, geomDist);
    if (maxT <= tStart) return vec2(0.0);

    vec2  shearO = rayOrigin.xz + windSlant * rayOrigin.y;
    vec2  shearD = rayDir.xz    + windSlant * rayDir.y;
    float dLen2  = dot(shearD, shearD);
    float dLen   = sqrt(dLen2);

    vec2 gridPos = (shearO + shearD * tStart) / cellWidth;
    vec2 cellID  = floor(gridPos);
    vec2 stepDir = sign(shearD);
    vec2 tDelta  = cellWidth / max(abs(shearD), vec2(1e-5));
    vec2 tCross  = mix(tStart + (cellID + max(stepDir, 0.0) - gridPos) * stepDir * tDelta, vec2(1e9), step(abs(shearD), vec2(1e-5)));

    vec2 accum = vec2(0.0);
    for (int stepIdx = 0; stepIdx < 20; ++stepIdx) {
        vec2  colHash  = hash22(cellID + gridSeed);
        vec2  laneXZ   = (cellID + 0.15 + 0.70 * colHash) * cellWidth;
        float tClose   = dLen2 > 1e-6 ? clamp(dot(laneXZ - shearO, shearD) / dLen2, tStart, maxT) : tStart;
        float effHalfW = max(RAIN_STREAK_HALF_WIDTH, tClose * pxAngle * 0.75);
        float coreMask = 1.0 - smoothstep(effHalfW * 0.35, effHalfW * 1.50, length(shearO + shearD * tClose - laneXZ));

        if (coreMask > 0.0) {
            vec2  velHash = hash22(cellID + gridSeed + 31.7);
            float fallVel = RAIN_FALL_SPEED * (0.85 + 0.30 * velHash.x);
            float vSpace  = dropPeriod * (0.75 + 0.50 * velHash.y);
            float phaseY  = (rayOrigin.y + rayDir.y * tClose + fallVel * frameTimeCounter) / vSpace + colHash.x * 17.0;
            float dropIdx = floor(phaseY);
            vec2  dropRnd = hash22(vec2(cellID.x + dropIdx * 7.13, cellID.y - dropIdx * 3.71) + gridSeed);

            if (dropRnd.x < occupancy) {
                float streakLen = 0.45 + 0.60 * dropRnd.y;
                float halfSpan  = 0.50 * streakLen + min((effHalfW * abs(rayDir.y)) / max(dLen, 0.02), 0.50 * vSpace);
                float vProfile  = 1.0 - smoothstep(0.45, 1.0, (abs(phaseY - dropIdx - 0.5) * vSpace) / halfSpan);
                float energy    = ((0.45 + 0.55 * dropRnd.y) * streakLen) / (2.0 * halfSpan);
                float alpha     = coreMask * vProfile * energy * pow(RAIN_STREAK_HALF_WIDTH / effHalfW, 0.60);
                alpha *= smoothstep(tClose, tClose * 1.08 + 0.40, geomDist) * exp(-tClose * hazeExt);
                alpha *= smoothstep(0.30, 1.50, tClose) * (0.35 + 0.65 * smoothstep(1.0, 5.0, tClose));
                alpha *= mix(shelterVis, 1.0, smoothstep(3.0, 10.0, tClose));
                accum += alpha * vec2(1.0, exp(-tClose * 0.16));
            }
        }
        float nextT = min(tCross.x, tCross.y);
        if (nextT > maxT) break;
        vec2 advance = step(tCross, vec2(nextT));
        cellID += stepDir * advance;
        tCross += tDelta  * advance;
    }
    return accum;
}

vec2 simulatedRain(vec3 rayOrigin, vec3 rayDir, float geomDist, float hazeExt, float shelterVis) {
    rayOrigin.xz    = mod(rayOrigin.xz, 1024.0);
    vec2  windSlant = rainWind();
    float occupancy = saturate(0.55 * RAIN_AMOUNT * (0.40 + 0.60 * rainStrength));
    float pxAngle   = 2.0 / max(gbufferProjection[1][1] * viewHeight, 1.0);

    vec2 total = rainGrid(rayOrigin, rayDir, windSlant, 0.35,  6.5, geomDist, hazeExt, 0.50, 3.6, 1.0, occupancy, pxAngle, shelterVis);
    total     += rainGrid(rayOrigin, rayDir, windSlant, 6.50, 20.0, geomDist, hazeExt, 1.10, 2.8, 2.0, occupancy, pxAngle, shelterVis);
    total     += rainGrid(rayOrigin, rayDir, windSlant, 20.0, 58.0, geomDist, hazeExt, 3.00, 2.0, 3.0, occupancy, pxAngle, shelterVis);
    return total;
}

float rainCurtains(vec3 worldDir) {
    vec2 sheetUV = (worldDir.xz / max(length(worldDir.xz), 0.20)) * 2.4 + rainWindDir() * (frameTimeCounter * 0.035);
    return noise2D(sheetUV + 5.0) * 0.65 + noise2D(sheetUV * 2.7 + 9.0) * 0.35;
}

vec3 rainRadiance(vec3 worldDir, vec3 skyAmb, float skyVis) {
    float cosFwd = max(dot(worldDir, lightDirWorld()), 0.0);
    float c2     = cosFwd * cosFwd;
    vec3  lit    = skyAmb * 1.50 + getLightColor() * (0.08 + 0.50 * c2 * c2 + 2.20 * pow(cosFwd, 24.0));
    return mix(vec3(luma(lit)), lit, 0.40) * skyVis;
}

#endif

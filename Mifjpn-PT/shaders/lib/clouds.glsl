// Mifjpn-PT Clouds Edition | Wide-Vista Fair-Weather Cumulus (22km Spherical Shell)
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_CLOUDS_GLSL
#define MIFJPN_PT_CLOUDS_GLSL
#if defined VOLUMETRIC_CLOUDS && !defined NETHER && !defined END

const float CLOUD_SIGMA_EXT    = 0.068;
const float CLOUD_MAX_DIST     = 22000.0;
const float CLOUD_SHELL_RADIUS = 68000.0;

vec2 cloudEntry = vec2(-100.0, 0.0);

float cloudBase() { return CLOUD_ALTITUDE; }
float cloudTop()  { return CLOUD_ALTITUDE + CLOUD_THICKNESS; }

vec2 cloudWind() {
    return vec2(0.851, 0.525) * (frameTimeCounter * 2.6 * CLOUD_SPEED);
}

float cloudCoverAmount() {
    return mix(CLOUD_COVERAGE, 0.92, rainStrength);
}

float valueNoise3D(vec3 p) {
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

float worleyBillow3D(vec3 p) {
    vec3  base  = floor(p - 0.5);
    float minD2 = 4.0;
    for (int dz = 0; dz <= 1; ++dz) {
        for (int dy = 0; dy <= 1; ++dy) {
            for (int dx = 0; dx <= 1; ++dx) {
                vec3 cell = base + vec3(float(dx), float(dy), float(dz));
                vec3 jit  = vec3(
                    hash13(cell),
                    hash13(cell + vec3(19.1, 7.7, 3.3)),
                    hash13(cell + vec3(5.3, 29.9, 13.7))
                ) - 0.5;
                vec3 d = (cell + 0.5 + jit * 0.74) - p;
                minD2  = min(minD2, dot(d, d));
            }
        }
    }
    return 1.0 - saturate(sqrt(minD2) * 1.06);
}

// Weather field creating distinct, well-spaced fair-weather cumulus islands with wide sky corridors
vec2 cloudWeatherField(vec2 worldXZ) {
    vec2  wind    = cloudWind();
    vec2  uvMacro = (worldXZ + wind) * (1.0 / 1180.0);
    vec2  wAx     = vec2(0.851, 0.525);
    vec2  streetP = vec2(dot(uvMacro, wAx) * 0.82, dot(uvMacro, vec2(-wAx.y, wAx.x)) * 1.18);

    float macro = noise2D(streetP) * 0.50
                + noise2D(uvMacro * 2.35 + 7.3) * 0.33
                + noise2D(uvMacro * 5.10 + 2.1) * 0.17;

    float cv    = cloudCoverAmount();
    float cover = smoothstep(1.03 - cv * 1.05, 1.24 - cv * 0.65, macro);

    float cells = noise2D((worldXZ + wind * 0.80) * (1.0 / 620.0) + 19.7);
    float tower = saturate(mix(0.32, 0.96, smoothstep(0.10, 0.80, cover) * (0.42 + 0.58 * cells) + rainStrength * 0.35));
    return vec2(cover, tower);
}

float cloudCoverageMap(vec2 worldXZ) {
    return cloudWeatherField(worldXZ).x;
}

float evalCumulusDensityAtHeight(vec3 worldPos, float normH, float mipLod) {
    if (normH <= 0.0 || normH >= 1.0) return 0.0;

    vec2  weather = cloudWeatherField(worldPos.xz);
    float cover   = weather.x;
    if (cover <= 0.002) return 0.0;

    float topH     = weather.y;
    float baseRamp = smoothstep(0.0, 0.09, normH);
    float topRamp  = 1.0 - smoothstep(topH * 0.48, topH, normH);
    float profile  = cover * baseRamp * topRamp;
    if (profile <= 0.002) return 0.0;

    vec2 drift = cloudWind();
    vec2 shear = vec2(0.851, 0.525) * (normH * 22.0);
    vec3 shpP  = vec3(
        worldPos.x + drift.x * 1.08 - shear.x,
        worldPos.y - frameTimeCounter * 0.20 * CLOUD_SPEED,
        worldPos.z + drift.y * 1.08 - shear.y
    );

    float fbmLow  = valueNoise3D(shpP * (1.0 / 96.0)) * 0.64 + valueNoise3D(shpP * (1.0 / 42.0) + 5.7) * 0.36;
    float worlLow = worleyBillow3D(shpP * (1.0 / 74.0)) * 0.64 + worleyBillow3D(shpP * (1.0 / 32.0) + 2.3) * 0.36;
    float pwShape = mix(fbmLow, worlLow, 0.58);

    float thresh    = 1.0 - profile * 0.92;
    float baseCloud = saturate((pwShape - thresh) / max(1.0 - thresh, 0.12));
    if (baseCloud <= 0.001) return 0.0;

    if (mipLod < 0.5 && baseCloud < 0.75) {
        vec3 warp = vec3(
            valueNoise3D(shpP * (1.0 / 28.0) + vec3(0.0, 4.1, 8.3)),
            valueNoise3D(shpP * (1.0 / 28.0) + vec3(9.2, 1.7, 3.4)),
            valueNoise3D(shpP * (1.0 / 28.0) + vec3(4.5, 8.8, 1.9))
        ) - 0.5;
        vec3  detP  = shpP * (1.0 / 20.0) + warp * 0.80;
        float wDet  = worleyBillow3D(detP) * 0.62 + worleyBillow3D(detP * 2.20 + 6.1) * 0.38;
        float erode = mix(wDet, 1.0 - wDet, saturate(normH * 1.40));
        baseCloud   = saturate((baseCloud - erode * 0.34 * (1.0 - baseCloud * 0.75)) / 0.76);
    }

    float lwc = mix(0.70, 1.25, saturate(normH * 1.5));
    return saturate(baseCloud * lwc * 1.75);
}

float cloudDensity(vec3 worldPos, float mipLod) {
    float normH = (worldPos.y - cloudBase()) * (1.0 / CLOUD_THICKNESS);
    return evalCumulusDensityAtHeight(worldPos, normH, mipLod);
}

#ifdef CLOUD_INTERACTION
bool isCameraNearCloudDeck() {
    return (cameraPosition.y > cloudBase() - 24.0) && (cameraPosition.y < cloudTop() + 24.0);
}

float evalCloudWake(vec3 worldPos, out vec3 vortexShift) {
    vortexShift = vec3(0.0);
    vec3  rel   = worldPos - cameraPosition;
    float dist  = length(rel);
    if (dist > 40.0) return 1.0;

    float t     = frameTimeCounter;
    vec3  vel   = (cameraPosition - previousCameraPosition) / max(frameTime, 1e-3);
    float speed = length(vel);
    if (speed > 120.0) { vel = vec3(0.0); speed = 0.0; }

    float flutter  = valueNoise3D(rel * 0.35 + vec3(t * 0.7, t * 1.1, t * 0.5));
    float cavityR  = (2.6 + 0.08 * speed) * (0.75 + 0.50 * flutter);
    float maskKeep = smoothstep(cavityR * 0.55, cavityR * 1.45, dist);

    if (speed > 1.5) {
        vec3  trailDir = -vel / speed;
        float trailPos = dot(rel, trailDir);
        float trailLen = min(speed * 1.2, 30.0);
        if (trailPos > 0.0 && trailPos < trailLen) {
            float radialOff = length(rel - trailDir * trailPos);
            float coneR     = cavityR * (1.0 - 0.75 * (trailPos / trailLen));
            maskKeep       *= smoothstep(coneR * 0.40, coneR * 1.30, radialOff);
        }
    }

    float nearFalloff = exp(-dist * (1.0 / 7.0));
    vec3  turb = vec3(
        valueNoise3D(rel * 0.20 + t * 0.9),
        valueNoise3D(rel * 0.20 + 7.0 - t * 0.8),
        valueNoise3D(rel * 0.20 + 13.0 + t * 0.7)
    ) - 0.5;
    vortexShift = turb * (12.0 * nearFalloff * (0.6 + 0.02 * speed));

    float elapsed = t - cloudEntry.x;
    if (elapsed < 0.0) elapsed += 3600.0;
    float impact = abs(cloudEntry.y);
    if (impact > 0.01 && elapsed < 4.0) {
        float ringR = 2.0 + 7.0 * sqrt(elapsed);
        float dRing = (dist - ringR) * (1.0 / 2.2);
        maskKeep   += exp(-dRing * dRing) * impact * exp(-elapsed * 0.769) * 1.4;
    }
    return maskKeep;
}
#endif

float evalSphericalCloudHeight(vec3 rayOrigin, vec3 worldPos) {
    vec2  dXZ = worldPos.xz - rayOrigin.xz;
    float rY  = worldPos.y + CLOUD_SHELL_RADIUS;
    return sqrt(dot(dXZ, dXZ) + rY * rY) - CLOUD_SHELL_RADIUS;
}

float cloudShellDensityAt(vec3 rayOrigin, vec3 worldPos, float mipLod) {
    float shellY = evalSphericalCloudHeight(rayOrigin, worldPos);
    float normH  = (shellY - cloudBase()) * (1.0 / CLOUD_THICKNESS);
#ifdef CLOUD_INTERACTION
    if (isCameraNearCloudDeck()) {
        vec3  vortexShift;
        float wakeGain = evalCloudWake(worldPos, vortexShift);
        return saturate(evalCumulusDensityAtHeight(worldPos + vortexShift, normH, mipLod) * wakeGain);
    }
#endif
    return evalCumulusDensityAtHeight(worldPos, normH, mipLod);
}

bool intersectCloudShell(vec3 rayOrigin, vec3 rayDir, out float tEnter, out float tExit) {
    float r0   = rayOrigin.y + CLOUD_SHELL_RADIUS;
    float rBot = CLOUD_SHELL_RADIUS + cloudBase();
    float rTop = CLOUD_SHELL_RADIUS + cloudTop();
    float b    = r0 * rayDir.y;

    float cTop = r0 * r0 - rTop * rTop;
    float dTop = b * b - cTop;
    if (dTop <= 0.0) { tEnter = 0.0; tExit = 0.0; return false; }
    float sTop = sqrt(dTop);

    float cBot = r0 * r0 - rBot * rBot;
    float dBot = b * b - cBot;
    float sBot = dBot > 0.0 ? sqrt(dBot) : 0.0;

    if (r0 < rBot) {
        if (rayDir.y < -0.025) { tEnter = 0.0; tExit = 0.0; return false; }
        tEnter = max(-b + sBot, 0.0);
        tExit  = -b + sTop;
    } else if (r0 <= rTop) {
        tEnter = 0.0;
        float hitInner = (dBot > 0.0) ? (-b - sBot) : -1.0;
        tExit = (hitInner > 0.0) ? hitInner : (-b + sTop);
    } else {
        float hitTop = -b - sTop;
        if (hitTop < 0.0) { tEnter = 0.0; tExit = 0.0; return false; }
        tEnter = hitTop;
        tExit  = (dBot > 0.0 && (-b - sBot) > hitTop) ? (-b - sBot) : (-b + sTop);
    }
    return tExit > tEnter;
}

float dualLobeCloudPhase(float cosTheta, float lobeScale) {
    return phaseHGn(cosTheta,  0.80 * lobeScale) * 0.72
         + phaseHGn(cosTheta, -0.32 * lobeScale) * 0.28;
}

vec4 volumetricClouds(
    vec3  rayOrigin,
    vec3  rayDir,
    float geomDist,
    float jitter,
    vec3  lightDir,
    vec3  lightRad,
    vec3  zenithAmb,
    vec3  horizAmb
) {
    float tEnter, tExit;
    if (!intersectCloudShell(rayOrigin, rayDir, tEnter, tExit)) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    if (tEnter >= CLOUD_MAX_DIST || tEnter >= geomDist) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Allow long grazing marches near the horizon so distant cloud streets recede to 22 km
    float maxSlabSpan = mix(9500.0, 2600.0, saturate(abs(rayDir.y) * 3.2));
    tExit = min(min(tExit, geomDist), min(tEnter + maxSlabSpan, CLOUD_MAX_DIST));
    if (tExit <= tEnter) return vec4(0.0, 0.0, 0.0, 1.0);

    float yBot      = cloudBase();
    float yTop      = cloudTop();
    bool  inDeck    = (rayOrigin.y > yBot && rayOrigin.y < yTop);
    int   stepCount = CLOUD_STEPS;
    float stepLen   = (tExit - tEnter) / float(stepCount);
    float stepGrow  = 1.0;
    if (inDeck) {
        stepLen  = min(stepLen, 3.5);
        stepGrow = 1.22;
    }

    float currT    = tEnter + stepLen * jitter;
    float cosTheta = dot(rayDir, lightDir);
    float extCoeff = CLOUD_SIGMA_EXT * CLOUD_DENSITY;
    float stormDim = (1.0 - 0.50 * rainStrength) * CLOUD_BRIGHTNESS;

    float lowSun   = (1.0 - smoothstep(0.0, 0.28, abs(lightDir.y))) * step(-0.06, lightDir.y);
    vec3  cloudSun = lightRad * mix(vec3(1.0), vec3(1.20, 0.96, 0.82), lowSun * 0.60);

    float ph0 = dualLobeCloudPhase(cosTheta, 1.00);
    float ph1 = dualLobeCloudPhase(cosTheta, 0.50);
    float ph2 = dualLobeCloudPhase(cosTheta, 0.22);

    vec3  accumRad  = vec3(0.0);
    float trans     = 1.0;
    float firstHitT = -1.0;

    for (int i = 0; i < 64; ++i) {
        if (i >= stepCount || currT > tExit) break;

        vec3  samplePos = rayOrigin + rayDir * currT;
        float lod       = currT > 4800.0 ? 1.0 : 0.0;
        float dens      = cloudShellDensityAt(rayOrigin, samplePos, lod);

        if (dens > 0.003) {
            if (firstHitT < 0.0) firstHitT = currT;
            float shellH = evalSphericalCloudHeight(rayOrigin, samplePos);
            float relH   = saturate((shellH - yBot) * (1.0 / CLOUD_THICKNESS));

            float sunTau = (cloudShellDensityAt(rayOrigin, samplePos + lightDir * 6.0,  1.0) * 8.0
                          + cloudShellDensityAt(rayOrigin, samplePos + lightDir * 24.0, 1.0) * 21.0
                          + cloudShellDensityAt(rayOrigin, samplePos + lightDir * 68.0, 1.0) * 48.0) * extCoeff;

            // Clean alabaster multi-scattering without muddy edge darkening
            float multScat = exp(-sunTau)        * ph0
                           + exp(-sunTau * 0.36) * ph1 * 0.58
                           + exp(-sunTau * 0.13) * ph2 * 0.34;
            float silverRim = 1.0 + 0.30 * exp(-sunTau * 2.2) * max(cosTheta, 0.0);

            // Airy cerulean-tinted shadow base + crisp bright sunlit crown
            vec3 baseShadow = mix(zenithAmb * 0.62 + horizAmb * 0.36, zenithAmb * 1.18, smoothstep(0.05, 0.82, relH));
            vec3 warmUnder  = cloudSun * (max(lightDir.y, 0.0) * 0.055 * (1.0 - relH));
            vec3 inScat     = (cloudSun * (multScat * silverRim * 0.64) + baseShadow + warmUnder) * stormDim;

            float stepTrans = exp(-extCoeff * dens * stepLen);
            accumRad += trans * inScat * (1.0 - stepTrans);
            trans    *= stepTrans;
            if (trans < 0.01) break;
        }

        currT   += stepLen;
        stepLen *= stepGrow;
    }

    if (firstHitT < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    // Subtle aerial perspective so clouds 8-20 km away melt softly into the pale blue horizon
    float cloudAlpha = 1.0 - trans;
    float airMix     = 1.0 - exp(-firstHitT * 0.000085);
    vec3  aerialCol  = mix(horizAmb * 0.96, zenithAmb * 0.78, saturate(rayDir.y * 3.0))
                     + cloudSun * (phaseHGn(cosTheta, 0.74) * 0.06);
    accumRad         = mix(accumRad, aerialCol * cloudAlpha, airMix * 0.72);

    float farFade  = 1.0 - smoothstep(14500.0, CLOUD_MAX_DIST, firstHitT);
    float limbFade = inDeck ? 1.0 : smoothstep(-0.015, 0.032, rayDir.y);
    float visW     = farFade * limbFade;
    return vec4(accumRad * visW, mix(1.0, trans, visW));
}

vec4 cloudsFlat(vec3 rayDir, vec3 lightDir, vec3 lightRad, vec3 zenithAmb) {
    float tEnter, tExit;
    if (!intersectCloudShell(cameraPosition, rayDir, tEnter, tExit)) return vec4(0.0);
    float tMid = mix(tEnter, tExit, 0.35);
    if (tMid > CLOUD_MAX_DIST) return vec4(0.0);

    vec2  hitXZ   = cameraPosition.xz + rayDir.xz * tMid;
    float cover   = cloudCoverageMap(hitXZ);
    float opacity = smoothstep(0.05, 0.48, cover) * smoothstep(-0.01, 0.12, rayDir.y) * (1.0 - smoothstep(12000.0, CLOUD_MAX_DIST, tMid)) * 0.90;
    float lining  = pow(max(dot(rayDir, lightDir), 0.0), 6.0);

    vec3 col = zenithAmb * 0.92 + lightRad * (0.32 + 0.46 * (1.0 - cover) + 0.58 * lining);
    col     *= (1.0 - 0.50 * rainStrength) * CLOUD_BRIGHTNESS;
    return vec4(col, opacity);
}

float cloudShadow(vec3 worldPos, vec3 lightDir) {
    if (lightDir.y < 0.03) return 1.0;
    float planeY = cloudBase() + CLOUD_THICKNESS * 0.28;
    if (worldPos.y > planeY) return 1.0;

    vec2  projXZ = worldPos.xz + lightDir.xz * ((planeY - worldPos.y) / lightDir.y);
    float cover  = cloudCoverageMap(projXZ);
    return 1.0 - 0.68 * CLOUD_SHADOW_STRENGTH * smoothstep(0.28, 0.75, cover);
}

#endif
#endif

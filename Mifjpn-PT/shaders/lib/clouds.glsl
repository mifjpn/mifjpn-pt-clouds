// Mifjpn-PT Clouds Edition | Spherical Perlin-Worley Low Cumulus, Curl Erosion & Aerial Perspective
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_CLOUDS_GLSL
#define MIFJPN_PT_CLOUDS_GLSL
#if defined VOLUMETRIC_CLOUDS && !defined NETHER && !defined END

const float CLOUD_SIGMA_EXT    = 0.072;
const float CLOUD_MAX_DIST     = 14000.0;
const float CLOUD_SHELL_RADIUS = 42000.0;

vec2 cloudEntry = vec2(-100.0, 0.0);

float cloudBase() { return CLOUD_ALTITUDE; }
float cloudTop()  { return CLOUD_ALTITUDE + CLOUD_THICKNESS; }

vec2 cloudWind() {
    return vec2(0.851, 0.525) * (frameTimeCounter * 2.8 * CLOUD_SPEED);
}

float cloudCoverAmount() {
    return mix(CLOUD_COVERAGE, 0.94, rainStrength);
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

// Fast 8-tap (2x2x2) 3D inverted cellular Worley for crisp cauliflower cumulus lobes
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
                vec3 d = (cell + 0.5 + jit * 0.72) - p;
                minD2  = min(minD2, dot(d, d));
            }
        }
    }
    return 1.0 - saturate(sqrt(minD2) * 1.08);
}

// Weather map: x = horizontal cloud coverage, y = convective tower height (humilis -> congestus)
vec2 cloudWeatherField(vec2 worldXZ) {
    vec2  wind    = cloudWind();
    vec2  uvMacro = (worldXZ + wind) * (1.0 / 920.0);
    // Slight wind-aligned cloud street anisotropy
    vec2  wAx     = vec2(0.851, 0.525);
    vec2  streetP = vec2(dot(uvMacro, wAx) * 0.78, dot(uvMacro, vec2(-wAx.y, wAx.x)) * 1.25);

    float macro = noise2D(streetP) * 0.54
                + noise2D(uvMacro * 2.15 + 7.3) * 0.30
                + noise2D(uvMacro * 4.65 + 2.1) * 0.16;

    float cv    = cloudCoverAmount();
    float cover = smoothstep(1.0 - cv - 0.08, 1.0 - cv + 0.32, macro);

    float cells = noise2D((worldXZ + wind * 0.75) * (1.0 / 540.0) + 19.7);
    float tower = saturate(mix(0.28, 1.0, smoothstep(0.15, 0.85, cover) * (0.45 + 0.55 * cells) + rainStrength * 0.35));
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

    // Flat condensation base (LCL) + rounded convective dome up to tower height
    float topH     = weather.y;
    float baseRamp = smoothstep(0.0, 0.085, normH);
    float topRamp  = 1.0 - smoothstep(topH * 0.52, topH, normH);
    float gradH    = baseRamp * topRamp;
    float profile  = cover * gradH;
    if (profile <= 0.002) return 0.0;

    vec2 drift = cloudWind();
    // Subtle wind shear tilts towering tops downwind
    vec2 shear = vec2(0.851, 0.525) * (normH * 28.0);
    vec3 shpP  = vec3(
        worldPos.x + drift.x * 1.10 - shear.x,
        worldPos.y - frameTimeCounter * 0.22 * CLOUD_SPEED,
        worldPos.z + drift.y * 1.10 - shear.y
    );

    // Perlin-Worley base shape (Schneider remap preserves cauliflower domes)
    float fbmLow  = valueNoise3D(shpP * (1.0 / 88.0)) * 0.65 + valueNoise3D(shpP * (1.0 / 38.0) + 5.7) * 0.35;
    float worlLow = worleyBillow3D(shpP * (1.0 / 68.0)) * 0.64 + worleyBillow3D(shpP * (1.0 / 29.0) + 2.3) * 0.36;
    float pwShape = mix(fbmLow, worlLow, 0.54);

    float thresh    = 1.0 - profile;
    float baseCloud = saturate((pwShape - thresh) / max(1.0 - thresh, 0.10));
    if (baseCloud <= 0.001) return 0.0;

    if (mipLod < 0.5 && baseCloud < 0.72) {
        // Curl-like domain warp + altitude-dependent Worley erosion (wispy bases, crisp turrets)
        vec3 warp = vec3(
            valueNoise3D(shpP * (1.0 / 26.0) + vec3(0.0, 4.1, 8.3)),
            valueNoise3D(shpP * (1.0 / 26.0) + vec3(9.2, 1.7, 3.4)),
            valueNoise3D(shpP * (1.0 / 26.0) + vec3(4.5, 8.8, 1.9))
        ) - 0.5;
        vec3  detP  = shpP * (1.0 / 19.0) + warp * 0.85;
        float wDet  = worleyBillow3D(detP) * 0.62 + worleyBillow3D(detP * 2.25 + 6.1) * 0.38;
        float erode = mix(wDet, 1.0 - wDet, saturate(normH * 1.45));
        baseCloud   = saturate((baseCloud - erode * 0.36 * (1.0 - baseCloud * 0.75)) / 0.76);
    }

    float lwc = mix(0.65, 1.30, saturate(normH * 1.6));
    return saturate(baseCloud * lwc * 1.85);
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

// Concentric spherical shell ray intersection around planet curvature CLOUD_SHELL_RADIUS
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
        // Camera below cloud deck: block rays dipping below curved horizon
        if (rayDir.y < -0.035) { tEnter = 0.0; tExit = 0.0; return false; }
        tEnter = max(-b + sBot, 0.0);
        tExit  = -b + sTop;
    } else if (r0 <= rTop) {
        // Camera inside cloud deck
        tEnter = 0.0;
        float hitInner = (dBot > 0.0) ? (-b - sBot) : -1.0;
        tExit = (hitInner > 0.0) ? hitInner : (-b + sTop);
    } else {
        // Camera above cloud deck looking down into top of shell
        float hitTop = -b - sTop;
        if (hitTop < 0.0) { tEnter = 0.0; tExit = 0.0; return false; }
        tEnter = hitTop;
        tExit  = (dBot > 0.0 && (-b - sBot) > hitTop) ? (-b - sBot) : (-b + sTop);
    }
    return tExit > tEnter;
}

float dualLobeCloudPhase(float cosTheta, float lobeScale) {
    return phaseHGn(cosTheta,  0.82 * lobeScale) * 0.74
         + phaseHGn(cosTheta, -0.30 * lobeScale) * 0.26;
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

    tExit = min(min(tExit, geomDist), min(tEnter + 2800.0, CLOUD_MAX_DIST));
    if (tExit <= tEnter) return vec4(0.0, 0.0, 0.0, 1.0);

    float yBot      = cloudBase();
    float yTop      = cloudTop();
    bool  inDeck    = (rayOrigin.y > yBot && rayOrigin.y < yTop);
    int   stepCount = CLOUD_STEPS;
    float stepLen   = (tExit - tEnter) / float(stepCount);
    float stepGrow  = 1.0;
    if (inDeck) {
        stepLen  = min(stepLen, 3.2);
        stepGrow = 1.22;
    }

    float currT    = tEnter + stepLen * jitter;
    float cosTheta = dot(rayDir, lightDir);
    float extCoeff = CLOUD_SIGMA_EXT * CLOUD_DENSITY;
    float stormDim = (1.0 - 0.52 * rainStrength) * CLOUD_BRIGHTNESS;

    // Sunset warmth boost at cloud altitude (clouds catch less-extinguished low sun)
    float lowSun   = (1.0 - smoothstep(0.0, 0.28, abs(lightDir.y))) * step(-0.06, lightDir.y);
    vec3  cloudSun = lightRad * mix(vec3(1.0), vec3(1.22, 0.96, 0.80), lowSun * 0.65);

    float ph0 = dualLobeCloudPhase(cosTheta, 1.00);
    float ph1 = dualLobeCloudPhase(cosTheta, 0.52);
    float ph2 = dualLobeCloudPhase(cosTheta, 0.24);

    vec3  accumRad  = vec3(0.0);
    float trans     = 1.0;
    float firstHitT = -1.0;

    for (int i = 0; i < 64; ++i) {
        if (i >= stepCount || currT > tExit) break;

        vec3  samplePos = rayOrigin + rayDir * currT;
        float lod       = currT > 4200.0 ? 1.0 : 0.0;
        float dens      = cloudShellDensityAt(rayOrigin, samplePos, lod);

        if (dens > 0.003) {
            if (firstHitT < 0.0) firstHitT = currT;
            float shellH = evalSphericalCloudHeight(rayOrigin, samplePos);
            float relH   = saturate((shellH - yBot) * (1.0 / CLOUD_THICKNESS));

            float sunTau = (cloudShellDensityAt(rayOrigin, samplePos + lightDir * 5.0,  1.0) * 8.0
                          + cloudShellDensityAt(rayOrigin, samplePos + lightDir * 21.0, 1.0) * 22.0
                          + cloudShellDensityAt(rayOrigin, samplePos + lightDir * 62.0, 1.0) * 52.0) * extCoeff;

            // 3-octave multiple scattering + silver-lining powder envelope
            float multScat = exp(-sunTau)        * ph0
                           + exp(-sunTau * 0.38) * ph1 * 0.54
                           + exp(-sunTau * 0.14) * ph2 * 0.28;

            float powder = mix(1.0 - 0.68 * exp(-dens * extCoeff * 22.0), 1.0, saturate(cosTheta * 0.5 + 0.5) * 0.65);

            // Sky dome ambient + warm ground/horizon bounce on cloud undersides
            vec3 skyFill    = zenithAmb * (mix(0.26, 1.05, relH) * 0.88);
            vec3 baseBounce = (horizAmb * 0.34 + cloudSun * (max(lightDir.y, 0.0) * 0.065)) * (1.0 - relH) * exp(-dens * 1.4);
            vec3 inScat     = (cloudSun * (multScat * powder * 0.58) + skyFill + baseBounce) * stormDim;

            float stepTrans = exp(-extCoeff * dens * stepLen);
            accumRad += trans * inScat * (1.0 - stepTrans);
            trans    *= stepTrans;
            if (trans < 0.01) break;
        }

        currT   += stepLen;
        stepLen *= stepGrow;
    }

    if (firstHitT < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    // Rayleigh/Mie aerial perspective on distant cloud banks before horizon fade
    float cloudAlpha = 1.0 - trans;
    float airMix     = 1.0 - exp(-firstHitT * 0.00018);
    float mieFwd     = phaseHGn(cosTheta, 0.72) * 0.08;
    vec3  aerialCol  = mix(horizAmb * 0.92, zenithAmb * 0.72, saturate(rayDir.y * 2.5)) + cloudSun * mieFwd;
    accumRad         = mix(accumRad, aerialCol * cloudAlpha, airMix * 0.78);

    float farFade  = 1.0 - smoothstep(9500.0, CLOUD_MAX_DIST, firstHitT);
    float limbFade = inDeck ? 1.0 : smoothstep(-0.025, 0.045, rayDir.y);
    float visW     = farFade * limbFade;
    return vec4(accumRad * visW, mix(1.0, trans, visW));
}

// Fast low-cloud proxy for reflections (qualityTier == 1); PT GI stays unburdened
vec4 cloudsFlat(vec3 rayDir, vec3 lightDir, vec3 lightRad, vec3 zenithAmb) {
    float tEnter, tExit;
    if (!intersectCloudShell(cameraPosition, rayDir, tEnter, tExit)) return vec4(0.0);
    float tMid = mix(tEnter, tExit, 0.35);
    if (tMid > CLOUD_MAX_DIST) return vec4(0.0);

    vec2  hitXZ   = cameraPosition.xz + rayDir.xz * tMid;
    float cover   = cloudCoverageMap(hitXZ);
    float opacity = smoothstep(0.05, 0.48, cover) * smoothstep(-0.01, 0.14, rayDir.y) * (1.0 - smoothstep(8000.0, CLOUD_MAX_DIST, tMid)) * 0.92;
    float lining  = pow(max(dot(rayDir, lightDir), 0.0), 6.0);

    vec3 col = zenithAmb * 0.90 + lightRad * (0.30 + 0.45 * (1.0 - cover) + 0.60 * lining);
    col     *= (1.0 - 0.52 * rainStrength) * CLOUD_BRIGHTNESS;
    return vec4(col, opacity);
}

float cloudShadow(vec3 worldPos, vec3 lightDir) {
    if (lightDir.y < 0.03) return 1.0;
    float planeY = cloudBase() + CLOUD_THICKNESS * 0.28;
    if (worldPos.y > planeY) return 1.0;

    vec2  projXZ = worldPos.xz + lightDir.xz * ((planeY - worldPos.y) / lightDir.y);
    float cover  = cloudCoverageMap(projXZ);
    return 1.0 - 0.78 * CLOUD_SHADOW_STRENGTH * smoothstep(0.06, 0.58, cover);
}

#endif
#endif

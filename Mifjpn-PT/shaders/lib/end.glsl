// Mifjpn-PT | The End: Domain-Warped Nebula, Solar Eclipse, Mist Sea & Spirit Motes
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_END_GLSL
#define MIFJPN_PT_END_GLSL
#ifdef END

#if END_PALETTE == 1
    #define END_DEEP  vec3(0.003, 0.012, 0.011)
    #define END_NEB_A vec3(0.08, 0.95, 0.42)
    #define END_NEB_B vec3(0.95, 0.80, 0.22)
    #define END_NEB_C vec3(0.70, 1.00, 0.85)
    #define END_MIST  vec3(0.12, 1.00, 0.55)
    #define END_LIGHT vec3(0.78, 1.00, 0.84)
#elif END_PALETTE == 2
    #define END_DEEP  vec3(0.018, 0.007, 0.016)
    #define END_NEB_A vec3(1.00, 0.28, 0.48)
    #define END_NEB_B vec3(1.00, 0.66, 0.22)
    #define END_NEB_C vec3(0.80, 0.62, 1.00)
    #define END_MIST  vec3(1.00, 0.52, 0.58)
    #define END_LIGHT vec3(1.00, 0.84, 0.74)
#elif END_PALETTE == 3
    #define END_DEEP  vec3(0.004, 0.009, 0.026)
    #define END_NEB_A vec3(0.22, 0.46, 1.00)
    #define END_NEB_B vec3(0.55, 0.95, 1.00)
    #define END_NEB_C vec3(0.95, 0.92, 1.00)
    #define END_MIST  vec3(0.42, 0.74, 1.00)
    #define END_LIGHT vec3(0.78, 0.88, 1.00)
#else
    #define END_DEEP  vec3(0.010, 0.005, 0.026)
    #define END_NEB_A vec3(0.82, 0.14, 0.95)
    #define END_NEB_B vec3(0.06, 0.72, 0.95)
    #define END_NEB_C vec3(1.00, 0.66, 0.50)
    #define END_MIST  vec3(0.10, 0.82, 0.92)
    #define END_LIGHT vec3(0.86, 0.70, 1.00)
#endif

const float END_MIST_TOP   = 4.0;
const float END_MIST_BASE  = -10.0;
const float END_MIST_RISE  = 12.0;
const float END_MIST_LEVEL = END_MIST_TOP;

vec4 endSplash = vec4(0.0);
vec3 starField(vec3 rayDir, int octaveCount);

float evalVoidNoise3D(vec3 p) {
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

float evalVoidFbm3D(vec3 p, int octaves) {
    float sum = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; ++i) {
        if (i >= octaves) break;
        sum += amp * evalVoidNoise3D(p);
        p    = p * 2.03 + vec3(17.1, 3.3, 9.7);
        amp *= 0.5;
    }
    return sum;
}

vec3 renderAstralNebula(vec3 rayDir, bool highQuality) {
    float drift = frameTimeCounter * 0.0035 * END_SKY_SPEED;
    vec3  baseP = rayDir * 2.1;
    vec3  flow  = vec3(0.0);
    if (highQuality) {
        flow = vec3(
            evalVoidFbm3D(baseP * 1.3 + vec3( 0.0, drift, 4.0), 3),
            evalVoidFbm3D(baseP * 1.3 + vec3( 5.2, 1.3, -drift), 3),
            evalVoidFbm3D(baseP * 1.3 + vec3(-3.1, 7.7 + drift, 2.4), 3)
        ) - 0.47;
    }
    int   octs  = highQuality ? 5 : 3;
    float lobeA = evalVoidFbm3D(baseP + flow * 2.1 + vec3(drift * 0.6, 0.0, 0.0), octs);
    float lobeB = evalVoidFbm3D(baseP * 1.6 - flow * 1.7 + vec3(11.0, 4.0 - drift * 0.5, 7.0), octs);

    float galBand = dot(rayDir, normalize(vec3(0.45, 0.62, -0.64))) * (1.0 / 0.34);
    float region  = saturate(exp(-(galBand * galBand)) * 0.95 + smoothstep(0.52, 0.80, evalVoidNoise3D(rayDir * 1.25 + vec3(3.0, 8.0, 1.0))) * 0.80);
    float densA   = smoothstep(0.46, 0.80, lobeA) * region;
    float densB   = smoothstep(0.50, 0.84, lobeB) * region;

    vec3 nebRGB = END_NEB_A * (densA * (0.20 + 0.80 * lobeA))
                + END_NEB_B * (densB * (0.18 + 0.70 * lobeB))
                + END_NEB_C * (densA * densB * 0.90)
                + mix(END_NEB_A, END_NEB_B, 0.50) * (region * 0.035);
    if (highQuality) {
        nebRGB *= (1.0 - 0.80 * smoothstep(0.48, 0.70, evalVoidFbm3D(baseP * 2.7 + flow + 23.0, 4)));
    }
    return nebRGB;
}

vec3 renderEclipseCorona(vec3 rayDir, vec3 eclipseDir, bool highQuality, out float discMask) {
    discMask = 0.0;
    float cosAng = dot(rayDir, eclipseDir);
    if (cosAng < 0.30) return vec3(0.0);

    float normRad = acos(clamp(cosAng, -1.0, 1.0)) / max(0.100 * END_ECLIPSE_SIZE, 1e-3);
    discMask      = 1.0 - smoothstep(0.93, 1.0, normRad);

    float s = eclipseDir.z >= 0.0 ? 1.0 : -1.0;
    float a = -1.0 / (s + eclipseDir.z);
    float b = eclipseDir.x * eclipseDir.y * a;
    vec3  uAxis = vec3(1.0 + s * eclipseDir.x * eclipseDir.x * a, s * b, -s * eclipseDir.x);
    vec3  vAxis = vec3(b, s + eclipseDir.y * eclipseDir.y * a, -eclipseDir.y);

    vec2  azDir  = normalize(vec2(dot(rayDir, uAxis), dot(rayDir, vAxis)) + 1e-6);
    float t      = frameTimeCounter * END_SKY_SPEED;
    float plumes = highQuality
                 ? (noise2D(azDir * 2.6 + vec2(t * 0.015, 7.0)) * 0.55 + noise2D(azDir * 8.0 + vec2(3.0, -t * 0.040)) * 0.45)
                 : 0.50;

    float extMask  = smoothstep(0.95, 1.03, normRad);
    float corona   = pow(max(normRad, 1.0), -2.4) * (0.30 + 2.20 * plumes * plumes) * extMask;
    float limbRing = exp(-pow((normRad - 1.0) * 13.0, 2.0));
    float diamond  = exp(-pow((normRad - 1.0) * 9.0, 2.0)) * pow(max(dot(azDir, vec2(0.80, 0.60)), 0.0), 60.0);
    float wideHalo = exp(-normRad * 0.42) * 0.16 * extMask;

    return vec3(1.0, 0.96, 1.0) * (limbRing * 7.0 + diamond * 40.0)
         + mix(END_LIGHT, END_NEB_A, 0.35) * (corona * 2.6)
         + END_LIGHT * wideHalo;
}

float evalMeteorStreak(vec3 rayDir, float cycleSec, float streamSeed) {
    float clock = frameTimeCounter / cycleSec + streamSeed;
    float idx   = floor(clock);
    float phase = fract(clock) * (1.0 / 0.16);
    if (phase > 1.0) return 0.0;

    vec2  rnd     = hash22(vec2(idx, streamSeed * 31.7));
    float azim    = rnd.x * TAU;
    float elev    = 0.30 + 0.75 * rnd.y;
    vec3  origin  = vec3(cos(azim) * cos(elev), sin(elev), sin(azim) * cos(elev));
    vec3  tangent = normalize(cross(origin, vec3(0.0, 1.0, 0.0)));
    vec3  descent = normalize(vec3(0.0, -1.0, 0.0) + origin * origin.y);
    float rake    = (hash11(idx * 7.3 + streamSeed) - 0.5) * 2.0;
    vec3  motion  = normalize(tangent * sin(rake) + descent * cos(rake));

    vec3  bolide = normalize(origin + motion * (phase * 0.50));
    vec3  delta  = rayDir - bolide;
    float trail  = dot(delta, -motion);
    float ortho  = length(delta + motion * trail);

    float wake = exp(-(ortho * ortho) * 2.0e5) * step(0.0, trail) * (1.0 - smoothstep(0.0, 0.22, trail));
    float head = exp(-dot(delta, delta) * 3.33e4);
    return (wake * 1.40 + head * 2.50) * sin(phase * PI);
}

vec3 endHorizon() { return mix(END_MIST, END_NEB_A, 0.38) * 0.070; }

vec3 endVoid(vec3 rayDir, bool highQuality) {
    vec3 horSeam = endHorizon() * (1.0 + 1.30 * exp(rayDir.y * 16.0));
    vec3 avgMist = mix(END_DEEP * 2.0, END_MIST * 0.11, 0.55);
#ifdef END_MIST_VOLUME
    if (highQuality || cameraPosition.y < END_MIST_BASE) {
        return mix(horSeam, END_DEEP * 0.50, smoothstep(0.0, -0.40, rayDir.y));
    }
    return mix(horSeam, avgMist, smoothstep(0.0, -0.45, rayDir.y));
#else
    float altAbove = cameraPosition.y - END_MIST_LEVEL;
    if (!highQuality || altAbove < 2.0) return mix(horSeam, avgMist, smoothstep(0.0, -0.45, rayDir.y));

    float hitT   = altAbove / max(-rayDir.y, 2e-3);
    vec2  uv     = (cameraPosition.xz + rayDir.xz * hitT) * 0.0050;
    float t      = frameTimeCounter * END_SKY_SPEED;
    float curlA  = fbm(uv + vec2(t * 0.004, -t * 0.003));
    float curlB  = fbm(uv * 0.6 + vec2(40.0 - t * 0.002, 12.0));
    vec2  advect = (vec2(curlA, curlB) - 0.5) * 3.2;
    float field  = fbm(uv * 1.6 + advect + vec2(-t * 0.006, t * 0.003)) * 0.72
                 + fbm(uv * 5.5 + advect * 2.0 + vec2(t * 0.010, 3.0)) * 0.28;
    float cover  = smoothstep(0.34, 0.66, field);

    vec3 deckCol = mix(END_DEEP * 0.90, END_MIST * 0.085, cover)
                 + END_MIST  * (0.13 * smoothstep(0.60, 0.82, field))
                 + END_NEB_A * (0.070 * smoothstep(0.50, 0.75, curlA) * (1.0 - cover * 0.60))
                 + END_NEB_C * (0.090 * smoothstep(0.74, 0.90, field));
    return mix(horSeam, deckCol, exp(-hitT * 0.0024));
#endif
}

vec3 endSky(vec3 rayDir, int qualityTier) {
    vec3  eclipseDir = lightDirWorld();
    float fwdGlow    = pow(max(dot(rayDir, eclipseDir), 0.0), 6.0);
    if (rayDir.y < 0.0) {
        return (endVoid(rayDir, qualityTier >= 2) + END_LIGHT * (fwdGlow * 0.02)) * END_SKY_INTENSITY;
    }

    float zenY   = rayDir.y;
    vec3  skyCol = mix(endHorizon(), END_DEEP, pow(zenY, 0.42))
                 + endHorizon() * (exp(-zenY * 16.0) * 1.30)
                 + END_LIGHT * (fwdGlow * 0.030);
    if (qualityTier == 0) {
        return (skyCol + (END_NEB_A * 0.55 + END_NEB_B * 0.45) * (0.045 * (0.35 + 0.65 * zenY))) * END_SKY_INTENSITY;
    }

    float discMask = 0.0;
    vec3  corona   = renderEclipseCorona(rayDir, eclipseDir, qualityTier >= 2, discMask);
    float skyOpen  = 1.0 - discMask;
    if (skyOpen > 0.01) {
        float horFade = smoothstep(0.0, 0.09, zenY);
        skyCol += renderAstralNebula(rayDir, qualityTier >= 2) * (0.55 * END_NEBULA * horFade * skyOpen);
        skyCol += starField(rayDir, qualityTier >= 2 ? 3 : 1) * (1.50 * horFade * skyOpen);
        if (qualityTier >= 2) {
            skyCol += vec3(0.80, 0.92, 1.00) * ((evalMeteorStreak(rayDir, 7.3, 0.37) + evalMeteorStreak(rayDir, 11.9, 5.11)) * skyOpen);
        }
    }
    return (mix(skyCol, END_DEEP * 0.25, discMask) + corona) * END_SKY_INTENSITY;
}

vec3 endLightColor() { return END_LIGHT * (0.78 * END_LIGHT_STRENGTH); }

vec3 endAmbientLight(vec3 rayDir) {
    vec3 zenAmb   = (END_NEB_A * 0.55 + END_NEB_B * 0.45) * 0.230;
    vec3 horAmb   = mix(END_MIST, END_NEB_A, 0.40) * 0.190;
    vec3 nadirAmb = END_MIST * 0.260;
    vec3 hemi     = rayDir.y > 0.0 ? mix(horAmb, zenAmb, rayDir.y) : mix(horAmb, nadirAmb, -rayDir.y);
    return hemi * (AMBIENT_STRENGTH * END_SKY_INTENSITY);
}

#ifdef END_MIST_VOLUME
float evalSplashElapsed() {
    float dt = frameTimeCounter - endSplash.z;
    return dt < 0.0 ? (dt + 3600.0) : dt;
}

float evalMistGradNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f    = p - cell;
    vec2 w    = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float g00 = dot(hash22(cell) * 2.0 - 1.0, f);
    float g10 = dot(hash22(cell + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
    float g01 = dot(hash22(cell + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
    float g11 = dot(hash22(cell + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
    return saturate(0.50 + 1.15 * mix(mix(g00, g10, w.x), mix(g01, g11, w.x), w.y));
}

vec2 evalMistLargeCurl(vec2 worldXZ) {
    float t  = frameTimeCounter * END_SKY_SPEED;
    vec2  uv = worldXZ * 0.0050;
    return vec2(evalMistGradNoise(uv + vec2(t * 0.007, 3.0)), evalMistGradNoise(uv.yx * 1.1 + vec2(11.0, -t * 0.006))) - 0.5;
}

vec2 evalMistLodWeights(float rayDist) {
    return vec2(1.0 - smoothstep(900.0, 1800.0, rayDist), 1.0 - smoothstep(90.0, 220.0, rayDist));
}

vec3 evalMistEnvelope(vec2 worldXZ, vec2 curlVec, vec2 lodW, bool evalBottom) {
    float t       = frameTimeCounter * END_SKY_SPEED;
    float bankOct = evalMistGradNoise(worldXZ * 0.0090 + curlVec * 1.5 - vec2(0.80, 0.60) * (t * 0.016));
    vec2  rot1    = vec2(worldXZ.x * 0.796 - worldXZ.y * 0.605, worldXZ.x * 0.605 + worldXZ.y * 0.796);
    float billOct = evalMistGradNoise(rot1 * 0.028 + curlVec * 2.6 - vec2(0.45, 0.89) * (t * 0.065));

    float puffOct = 0.50;
    if (lodW.x > 0.01) {
        vec2  rot2  = vec2(worldXZ.x * 0.219 - worldXZ.y * 0.976, worldXZ.x * 0.976 + worldXZ.y * 0.219);
        float pRaw  = evalMistGradNoise(rot2 * 0.085 + curlVec * 4.0 + vec2(t * 0.15, -t * 0.10));
        float lobe  = sqrt((pRaw * 2.0 - 1.0) * (pRaw * 2.0 - 1.0) + 0.03) * 1.70;
        puffOct     = mix(0.50, mix(pRaw, lobe, 0.45), lodW.x);
        vec2  rot5  = vec2(worldXZ.x * 0.891 + worldXZ.y * 0.454, -worldXZ.x * 0.454 + worldXZ.y * 0.891);
        puffOct    += (evalMistGradNoise(rot5 * 0.185 - curlVec * 5.0 + vec2(-t * 0.19, t * 0.13)) - 0.5) * 0.55 * lodW.x;
    }

    float ripOct = 0.50;
    if (lodW.y > 0.01) {
        vec2 rot3 = vec2(-worldXZ.x * 0.588 - worldXZ.y * 0.809, worldXZ.x * 0.809 - worldXZ.y * 0.588);
        ripOct    = mix(0.50, evalMistGradNoise(rot3 * 0.29 + vec2(-t * 0.22, t * 0.31)), lodW.y);
    }

    float heightMix = bankOct * 0.47 + billOct * 0.31 + puffOct * 0.16 + ripOct * 0.06;
    float yCrest    = END_MIST_TOP + END_MIST_RISE * (smoothstep(0.24, 0.76, heightMix) - 0.25);
    float density   = mix(0.45, 1.0, smoothstep(0.25, 0.50, bankOct * 0.60 + billOct * 0.40));

    float yFloor = END_MIST_BASE;
    if (evalBottom) {
        vec2  rot4  = vec2(worldXZ.x * 0.454 + worldXZ.y * 0.891, -worldXZ.x * 0.891 + worldXZ.y * 0.454);
        float pouch = evalMistGradNoise(rot4 * 0.060 + curlVec * 2.0 + vec2(t * 0.030, t * 0.022));
        float rift  = evalMistGradNoise(rot1.yx * 0.021 + curlVec * 1.5 - vec2(t * 0.012, 0.0));
        yFloor += 5.5 - 9.0 * smoothstep(0.30, 0.68, pouch) - 4.5 * smoothstep(0.35, 0.75, rift) + 1.5 * (puffOct - 0.5);
    }

#ifdef END_MIST_SPLASH
    float impMag = abs(endSplash.w);
    if (impMag > 0.01) {
        float age   = evalSplashElapsed();
        vec2  delta = worldXZ - endSplash.xy;
        float dist  = length(delta);
        if (age < 10.0 && dist < 6.0 + 4.0 * age) {
            dist *= 1.0 + 0.20 * (evalMistGradNoise(delta * 0.7 + endSplash.z) - 0.5);
            float boreR = 1.3 + 1.1 * sqrt(age);
            float crown = exp(-pow((dist - boreR - 0.7) / 0.9, 2.0)) * 4.4 * (age / 0.3) * exp(1.0 - age / 0.3);
            float wave1 = exp(-pow((dist - 3.4 * age) / (1.0 + 0.35 * age), 2.0)) * 3.0 * exp(-age / 2.6);
            float wave2 = exp(-pow((dist - 2.0 * age) / (0.8 + 0.25 * age), 2.0)) * 1.5 * exp(-age / 1.9) * smoothstep(0.3, 1.0, age);
            float wake  = exp(-pow(dist / (boreR * 1.6), 2.0)) * 8.0 * exp(-age / 1.2);
            yCrest += (crown + wave1 + wave2) * impMag;
            if (endSplash.w > 0.0) yFloor -= wake * impMag;
            else                   yCrest += wake * impMag;
            density *= 1.0 - min(impMag * 1.2, 1.0) * exp(-age / 3.2) * exp(-pow(dist / boreR, 4.0));
        }
    }
#endif
    return vec3(yCrest, yFloor, density);
}

bool isInsideMistSlab(vec3 env, float worldY, float pad) {
    return (worldY - pad < env.x) && (worldY + pad > env.y) && (env.z > 0.08);
}

vec3 shadeMistSample(float depthFromTop, float slopeRake, float crestNorm, float fwdPhase, vec3 eclipseRad, float viewBelow, float slabThick, float pouchDepth) {
    float skyOpen  = mix(0.25, 1.0, crestNorm);
    float rakeTerm = clamp(0.70 - slopeRake * 0.55, 0.32, 1.08);
    vec3  upperRad = (END_MIST * 0.31 + eclipseRad * 0.17) * (rakeTerm * skyOpen * exp(-depthFromTop * 0.11) * fwdPhase)
                   + END_MIST * (0.060 * exp(-depthFromTop * 0.16) * skyOpen)
                   + (END_MIST * 0.080 + eclipseRad * 0.028) * (exp(-depthFromTop * 0.045) * mix(0.55, 1.0, crestNorm))
                   + END_NEB_A * (0.022 * (1.0 - skyOpen) * exp(-depthFromTop * 0.05));
    vec3  lowerRad = (END_MIST * 0.60 + eclipseRad * 0.34) * (exp(-slabThick * 0.15) * 1.60 * fwdPhase)
                   + END_MIST  * (0.050 * (1.0 - 0.65 * pouchDepth))
                   + END_NEB_A * (0.040 * pouchDepth);
    return mix(upperRad, lowerRad, viewBelow) + END_DEEP * 0.35;
}

vec4 endMistSea(vec3 rayOrigin, vec3 rayDir, float geomDist, float jitter) {
    float boundHi = END_MIST_TOP + END_MIST_RISE * 0.75 + 0.5;
    float boundLo = END_MIST_BASE - 10.5;
    float padHi = 0.0, padLo = 0.0;

#ifdef END_MIST_SPLASH
    float impAge = evalSplashElapsed();
    if (abs(endSplash.w) > 0.01 && impAge < 10.0) {
        vec2  toImp   = endSplash.xy - rayOrigin.xz;
        float projXZ  = dot(toImp, rayDir.xz) / max(dot(rayDir.xz, rayDir.xz), 1e-6);
        vec2  closest = toImp - rayDir.xz * max(projXZ, 0.0);
        float maxR    = 7.0 + 4.0 * impAge;
        float prox    = (1.0 - smoothstep(maxR * 0.55, maxR, length(closest))) * exp(-impAge * 0.40);
        padHi = prox * (endSplash.w < 0.0 ? 9.0 : 5.0);
        padLo = prox * (endSplash.w > 0.0 ? 6.0 : 0.0);
    }
#endif

    float layerVis = END_MIST_DENSITY > 0.0 ? 1.0 : 0.0;
#ifndef END_MIST_UNDERSIDE
    layerVis *= smoothstep(END_MIST_BASE - 8.0, END_MIST_BASE, rayOrigin.y);
#endif
    if (layerVis <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    float tEnter = 0.0, tExit = geomDist, tSlabEx = geomDist;
    if (abs(rayDir.y) > 1e-4) {
        float invDy = 1.0 / rayDir.y;
        float p0 = (boundHi + padHi - rayOrigin.y) * invDy;
        float p1 = (boundLo - padLo - rayOrigin.y) * invDy;
        tEnter   = max(min(p0, p1), 0.0);
        tExit    = min(max(p0, p1), geomDist);
        tSlabEx  = min(max((boundHi - rayOrigin.y) * invDy, (boundLo - rayOrigin.y) * invDy), geomDist);
    } else if (rayOrigin.y > boundHi + padHi || rayOrigin.y < boundLo - padLo) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    if (tExit <= tEnter) return vec4(0.0, 0.0, 0.0, 1.0);

    vec3  eclipseDir = lightDirWorld();
    vec3  eclipseRad = endLightColor();
    vec2  rakeDir    = dot(eclipseDir.xz, eclipseDir.xz) > 1e-4 ? normalize(eclipseDir.xz) : vec2(1.0, 0.0);
    float fwdPhase   = 0.62 + 0.38 * pow(max(dot(rayDir, eclipseDir), 0.0), 3.0);
    bool  camAbove   = (rayOrigin.y > END_MIST_TOP);
    bool  needBottom = (rayOrigin.y < END_MIST_TOP + 3.0);
    float viewBelow  = camAbove ? 0.0 : (1.0 - smoothstep(END_MIST_BASE - 6.0, END_MIST_BASE + 4.0, rayOrigin.y));
    vec3  avgRad     = shadeMistSample(camAbove ? 2.0 : 9.0, 0.0, camAbove ? 0.5 : 0.3, fwdPhase, eclipseRad, viewBelow, 20.0, 0.5);
    float extSigma   = 0.34 * END_MIST_DENSITY;

    vec3  accumRad = vec3(0.0);
    float trans    = 1.0;
    float farBlend = smoothstep(1500.0, 2400.0, tEnter);

    if (farBlend < 1.0) {
        float invSteps = 1.0 / float(max(END_MIST_STEPS, 1));
        vec2  curlVec  = evalMistLargeCurl((rayOrigin + rayDir * (tEnter + min(tExit - tEnter, 80.0) * 0.5)).xz);
        float segStart = tEnter, segEnd = tEnter;
        bool  foundHit = false, inCore = false;

        for (int attempt = 0; attempt < 2; ++attempt) {
            float searchLen = min(tExit - segStart, 320.0);
            if (searchLen <= 0.0) break;
            float expCurve = mix(1.0, 2.0, smoothstep(50.0, 150.0, searchLen));
            vec3  pos      = rayOrigin + rayDir * segStart;
            vec3  env      = evalMistEnvelope(pos.xz, curlVec, evalMistLodWeights(segStart), needBottom);
            foundHit       = isInsideMistSlab(env, pos.y, 0.0);
            float loT = segStart, hiT = segStart;

            if (!foundHit) {
                float pad = 0.0;
                for (int s = 0; s < END_MIST_STEPS; ++s) {
                    float probeT = segStart + searchLen * pow((float(s) + jitter) * invSteps, expCurve);
                    pad = clamp((probeT - loT) * 0.12, 0.0, 2.5);
                    pos = rayOrigin + rayDir * probeT;
                    env = evalMistEnvelope(pos.xz, curlVec, evalMistLodWeights(probeT), needBottom);
                    hiT = probeT;
                    if (isInsideMistSlab(env, pos.y, pad)) { foundHit = true; break; }
                    loT = probeT;
                }
                if (foundHit) {
                    for (int b = 0; b < 4; ++b) {
                        float midT = 0.5 * (loT + hiT);
                        pos = rayOrigin + rayDir * midT;
                        env = evalMistEnvelope(pos.xz, curlVec, evalMistLodWeights(midT), needBottom);
                        if (isInsideMistSlab(env, pos.y, pad)) hiT = midT; else loT = midT;
                    }
                }
            }
            segEnd = segStart + searchLen;
            if (!foundHit) break;

            vec2  lodW  = evalMistLodWeights(hiT);
            pos         = rayOrigin + rayDir * hiT;
            env         = evalMistEnvelope(pos.xz, curlVec, lodW, needBottom);
            float slope = (evalMistEnvelope(pos.xz + rakeDir * 2.5, curlVec, lodW, false).x - env.x) * 0.40;
            float fuzz  = 2.2 + hiT * 0.0025;
            float wispW = 1.0 - smoothstep(22.0, 60.0, hiT);
            float currT = hiT, ds = 0.45;

            for (int k = 0; k < 7; ++k) {
                pos = rayOrigin + rayDir * (currT + ds * 0.5);
                env = evalMistEnvelope(pos.xz, curlVec, lodW, needBottom);
                float subDepth = env.x - pos.y;
                float dens     = smoothstep(0.0, fuzz, subDepth) * smoothstep(0.0, fuzz * 1.3, pos.y - env.y) * env.z;
                inCore         = (dens > 0.30);
                if (dens > 0.002) {
                    if (wispW > 0.01) {
                        float tw   = frameTimeCounter * END_SKY_SPEED;
                        float wisp = evalVoidNoise3D(pos * 0.28 + vec3(tw * 0.11, -tw * 0.07, tw * 0.08));
                        dens *= mix(1.0, smoothstep(0.12, 0.72, wisp) * 1.40, wispW * (1.0 - smoothstep(0.0, 6.0, subDepth)));
                    }
                    float stepA     = 1.0 - exp(-dens * extSigma * ds);
                    float crestNorm = saturate((pos.y - (END_MIST_TOP - 3.0)) * (1.0 / END_MIST_RISE));
                    float pouchD    = saturate((END_MIST_BASE + 1.0 - env.y) * 0.125);
                    accumRad += trans * stepA * shadeMistSample(max(subDepth, 0.0), slope, crestNorm, fwdPhase, eclipseRad, viewBelow, env.x - env.y, pouchD);
                    trans    *= (1.0 - stepA);
                    if (trans < 0.02) break;
                }
                currT += ds;
                ds    *= 1.55;
                if (currT > tExit) break;
            }
            segEnd = currT;
            if (trans < 0.05 || inCore) break;
            segStart = segEnd;
        }

        if (trans > 0.02 && (!foundHit || inCore || rayDir.y < 0.0 || viewBelow > 0.5)) {
            float tailLen = tSlabEx - segEnd;
            if (tailLen > 0.0) {
                float tailA = 1.0 - exp(-tailLen * (foundHit ? 0.20 : 0.035) * END_MIST_DENSITY);
                accumRad += trans * tailA * avgRad;
                trans    *= (1.0 - tailA);
            }
        }
    }

    if (farBlend > 0.0) {
        float refY    = camAbove ? (END_MIST_TOP + 3.0) : (END_MIST_BASE - 2.0);
        float planeT  = abs(rayDir.y) > 1e-4 ? ((refY - rayOrigin.y) / rayDir.y) : tEnter;
        vec2  farXZ   = (rayOrigin + rayDir * max(planeT, tEnter)).xz;
        vec2  curlVec = evalMistLargeCurl(farXZ);
        vec3  env     = evalMistEnvelope(farXZ, curlVec, vec2(0.0), needBottom);
        float slope   = (evalMistEnvelope(farXZ + rakeDir * 5.0, curlVec, vec2(0.0), false).x - env.x) * 0.20;
        vec3  farRad  = shadeMistSample(camAbove ? 0.6 : 3.0, slope, saturate((env.x - (END_MIST_TOP - 3.0)) / END_MIST_RISE), fwdPhase, eclipseRad, viewBelow, env.x - env.y, saturate((END_MIST_BASE + 1.0 - env.y) * 0.125));
        float farMask = (tExit - tEnter > 1.0) ? 1.0 : 0.0;
        accumRad = mix(accumRad, farRad * farMask, farBlend);
        trans    = mix(trans, 1.0 - farMask, farBlend);
    }

    trans    = saturate((trans - 0.02) * (1.0 / 0.98));
    accumRad = mix(endHorizon() * (1.0 + 1.30 * exp(-abs(rayDir.y) * 16.0)) * (1.0 - trans), accumRad, exp(-tEnter * 0.0016));
    return vec4(accumRad * layerVis, mix(1.0, trans, layerVis));
}
#endif

vec3 endMotes(vec3 rayDir, float geomDist) {
    const float VOXEL_SIZE = 3.0;
    float t       = frameTimeCounter;
    vec3  origin  = cameraPosition + vec3(sin(t * 0.11) * 0.70, -t * 0.22, cos(t * 0.13) * 0.70);
    float spanLim = min(geomDist, 34.0);

    vec3 gridP  = origin * (1.0 / VOXEL_SIZE);
    vec3 cellID = floor(gridP);
    vec3 stepS  = sign(rayDir);
    vec3 tDelta = 1.0 / max(abs(rayDir), vec3(1e-5));
    vec3 tCross = mix((cellID + max(stepS, 0.0) - gridP) * stepS * tDelta, vec3(1e9), step(abs(rayDir), vec3(1e-5)));

    vec3 accum = vec3(0.0);
    for (int i = 0; i < 30; ++i) {
        float seed = hash13(cellID);
        if (seed < 0.24) {
            vec3 jitter = vec3(hash13(cellID + 11.3), hash13(cellID + 27.1), hash13(cellID + 53.9)) - 0.5;
            vec3 rel    = (cellID + 0.5 + jitter * 0.70) * VOXEL_SIZE - origin;
            float projT = dot(rel, rayDir);
            if (projT > 0.6 && projT < spanLim) {
                float d2   = max(dot(rel, rel) - projT * projT, 0.0);
                float rad  = 0.014 + 0.022 * hash13(cellID + 5.5);
                float rad2 = rad * rad;
                float halo = exp(-d2 / rad2) + 0.16 * exp(-d2 / (rad2 * 9.0));
                float pulse = 0.55 + 0.45 * sin(t * (0.7 + seed * 18.0) + seed * 240.0);
                accum += mix(END_MIST, END_NEB_C, fract(seed * 47.0)) * (halo * pulse * smoothstep(1.5, 4.5, projT) * (1.0 - projT / 34.0));
            }
        }
        float nextT = min(tCross.x, min(tCross.y, tCross.z));
        if (nextT * VOXEL_SIZE > spanLim) break;
        vec3 advance = step(tCross, vec3(nextT));
        cellID += stepS  * advance;
        tCross += tDelta * advance;
    }
    return accum * (1.5 * END_MOTE_BRIGHTNESS);
}

#endif
#endif

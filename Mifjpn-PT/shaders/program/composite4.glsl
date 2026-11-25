// Mifjpn-PT | Composite Pass 4: Auto-Exposure Metering & Temporal Biome State
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"

varying vec2 texcoord;

#ifdef VSH
void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    texcoord    = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex8;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex15;
uniform sampler2D depthtex0;

#if defined NETHER
const float METER_KEY      = 0.150;
const float METER_EXP      = 0.42;
const float EXPOSURE_FLOOR = 0.95;
const float EXPOSURE_CEIL  = 1.30;
#elif defined END
const float METER_KEY      = 0.135;
const float METER_EXP      = 0.45;
const float EXPOSURE_FLOOR = 0.60;
const float EXPOSURE_CEIL  = 2.40;
#else
const float METER_KEY      = 0.215;
const float METER_EXP      = 0.54;
const float EXPOSURE_FLOOR = 0.45;
const float EXPOSURE_CEIL  = 7.00;
#endif

float fallbackExposure() {
#if defined NETHER || defined END
    return 1.5;
#else
    float dayFac = dayAmount();
    float skyEye = float(eyeBrightnessSmooth.y) * (1.0 / 240.0);
    return mix(3.4, mix(3.0, 0.95, dayFac), skyEye);
#endif
}

float evalSnowyLowland() {
    bool isColdSnow = (biome_precipitation == 2) && (temperature < 0.3);
    bool isPeak     = (biome_category == 2 || biome_category == 17);
    return ((isColdSnow && !isPeak) ? 1.0 : 0.0) * (1.0 - smoothstep(118.0, 145.0, cameraPosition.y));
}

float evalRainBiome() {
    if (biome_precipitation == 2) return 0.0;
    if (biome_category == 12 || biome_category == 4) return 0.0;
    return 1.0;
}

/* RENDERTARGETS: 10,11,15 */
void main() {
    vec4  prevState = texture2D(colortex10, vec2(0.5));
    float prevExp   = prevState.r;
    float snowEase  = mix(prevState.g, evalSnowyLowland(), 1.0 - exp(-frameTime * (1.0 / 3.0)));
    float rainEase  = mix(prevState.b, evalRainBiome(),    1.0 - exp(-frameTime * 0.25));
    float nextExp   = fallbackExposure();

#ifdef AUTO_EXPOSURE
    float logSum = 0.0;
    float wSum   = 0.0;
    for (int gy = 0; gy < 5; ++gy) {
        for (int gx = 0; gx < 7; ++gx) {
            vec2  sampleUV = (vec2(float(gx), float(gy)) + 0.5) * vec2(1.0 / 7.0, 1.0 / 5.0);
            vec2  rel      = sampleUV - 0.5;
            float w        = exp(-dot(rel, rel) * 5.0) * (texture2D(depthtex0, sampleUV).r < 1.0 ? 1.0 : 0.35);
            logSum += w * log(min(luma(texture2D(colortex8, sampleUV).rgb), 6.0) + 0.02);
            wSum   += w;
        }
    }
    float geomMean  = exp(logSum / max(wSum, 1e-4)) - 0.02;
    float activeKey = METER_KEY;
    #if !defined NETHER && !defined END
    if (biome_precipitation == 2) activeKey *= 1.38;
    #endif

    nextExp = pow(activeKey / max(geomMean, 0.004), METER_EXP);
    #if !defined NETHER && !defined END
    nextExp *= mix(1.0, NIGHT_VISIBILITY, nightAmount());
    #endif
    nextExp = clamp(nextExp, EXPOSURE_FLOOR, EXPOSURE_CEIL);

    if (prevExp > 1e-4) {
        float adaptRate = (nextExp < prevExp ? 0.8 : 2.4) / max(EXPOSURE_SPEED, 0.05);
        nextExp = mix(prevExp, nextExp, 1.0 - exp(-frameTime / adaptRate));
    }
#endif

    vec4  airState = texture2D(colortex15, vec2(0.5));
    float mistEase = prevState.a;
    vec4  auxState = texture2D(colortex11, vec2(0.5));

#if !defined NETHER && !defined END
    vec3  tgtTint; float tgtDens, tgtMist, tgtHeat, tgtSpray;
    biomeAtmosphereTarget(tgtTint, tgtDens, tgtMist, tgtHeat, tgtSpray);
    float borderAlpha = 1.0 - exp(-frameTime * 0.2);
    if (airState.a < 1e-3) { airState = vec4(tgtTint, tgtDens); mistEase = tgtMist; auxState.ba = vec2(tgtHeat, tgtSpray); }
    airState    = mix(airState, vec4(tgtTint, tgtDens), borderAlpha);
    mistEase    = mix(mistEase, tgtMist, borderAlpha);
    auxState.ba = mix(auxState.ba, vec2(tgtHeat, tgtSpray), borderAlpha);
#endif

    gl_FragData[0] = vec4(nextExp, saturate(snowEase), saturate(rainEase), saturate(mistEase));
    gl_FragData[2] = airState;

    vec4 impulseState = texture2D(colortex11, vec2(0.5));
#if defined END && defined END_MIST_VOLUME && defined END_MIST_SPLASH
    float mistSurface = END_MIST_TOP + 4.0;
    float deltaY      = previousCameraPosition.y - cameraPosition.y;
    if ((previousCameraPosition.y - mistSurface) * (cameraPosition.y - mistSurface) < 0.0 && abs(deltaY) < 30.0) {
        float vel = abs(deltaY) / max(frameTime, 1e-3);
        impulseState = vec4(cameraPosition.xz, frameTimeCounter, sign(deltaY) * clamp(vel / 22.0, 0.5, 1.0));
    }
#elif !defined NETHER && !defined END
    impulseState = auxState;
    #if defined VOLUMETRIC_CLOUDS && defined CLOUD_INTERACTION
    vec3 camDelta = cameraPosition - previousCameraPosition;
    if (length(camDelta) < 30.0) {
        cloudEntry     = auxState.rg;
        float prevDens = cloudDensity(previousCameraPosition, 0.0);
        float currDens = cloudDensity(cameraPosition, 0.0);
        if (prevDens < 0.12 && currDens >= 0.12) {
            float speed = length(camDelta) / max(frameTime, 1e-3);
            impulseState.rg = vec2(frameTimeCounter, (camDelta.y <= 0.0 ? 1.0 : -1.0) * clamp(speed / 18.0, 0.35, 1.0));
        }
    }
    #endif
#else
    impulseState = vec4(0.0);
#endif
    gl_FragData[1] = impulseState;
}
#endif

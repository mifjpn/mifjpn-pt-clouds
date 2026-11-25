// Mifjpn-PT | Deferred Pass 0: Screen-Space Path-Traced Global Illumination
// SPDX-License-Identifier: MIT

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA8;
const int colortex7Format = R8;
const int colortex8Format = RGBA16F;
const int colortex9Format = RGBA16F;
const int colortex10Format = RGBA16F;
const int colortex11Format = RGBA32F;
const int colortex12Format = RGBA16F;
const int colortex13Format = R8;
const int colortex14Format = RGBA8;
const int colortex15Format = RGBA16F;
const int shadowcolor0Format = RGBA8;
*/

const bool colortex4Clear  = false;
const bool colortex7Clear  = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
const bool colortex15Clear = false;

const vec4 colortex0ClearColor  = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex3ClearColor  = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex6ClearColor  = vec4(1.0, 0.0, 0.0, 0.0);
const vec4 colortex12ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex13ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex14ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/gi.glsl"
#include "/lib/sky.glsl"
#include "/lib/water.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"
#include "/lib/raytrace.glsl"

varying vec2 texcoord;

#ifdef VSH
void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    texcoord    = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

vec3 evaluateBounceHit(vec2 hitUV, vec3 sunRad, vec3 viewL, vec3 skyAmb) {
    vec2 tc      = snapToTexel(hitUV, fullRes());
    vec3 surfCol = toLinear(texture2D(colortex0, tc).rgb);
    vec4 gbuf1   = texture2D(colortex1, tc);
    vec3 hitN    = decodeNormal(gbuf1.xy);
    float emiss  = texture2D(colortex2, tc).b;

    vec3 irrad = blockLight(gbuf1.z) + skyAmb * (skyOcclusion(gbuf1.w) * 0.5);
    float nl   = dot(hitN, viewL);
    if (nl > 0.0) {
    #ifdef SHADOWS
        float hitD   = texture2D(depthtex0, tc).r;
        vec3  hitRel = viewToPlayer(screenToView(vec3(tc, hitD)));
        vec3  worldN = mat3(gbufferModelViewInverse) * hitN;
        irrad += sunRad * nl * getShadowFast(hitRel, worldN, gbuf1.w);
    #else
        irrad += sunRad * nl * unshadowedLight(gbuf1.w);
    #endif
    }

    vec3 outRad = surfCol * (irrad + emiss * (EMISSION_STRENGTH * 0.5));
    return outRad / (1.0 + luma(outRad) * 0.52);
}

/* DRAWBUFFERS:3 */
void main() {
    vec2  sampleUV = giSampleUV(floor(gl_FragCoord.xy));
    float rawZ     = texture2D(depthtex0, sampleUV).r;

#ifdef PATH_TRACING
    if (rawZ >= 1.0 || rawZ < 0.56) {
        gl_FragData[0] = vec4(0.0);
        return;
    }

    vec3 viewPos  = screenToView(vec3(sampleUV, rawZ));
    vec4 gbuf1    = texture2D(colortex1, snapToTexel(sampleUV, fullRes()));
    vec3 viewN    = decodeNormal(gbuf1.xy);
    float skyVis  = skyOcclusion(gbuf1.w);
    vec3 sunRad   = getLightColor();
    vec3 viewL    = normalize(shadowLightPosition);
    vec3 skyAmb   = getSkyAmbient();

    float viewDist  = -viewPos.z;
    vec2  pixCoord  = sampleUV * fullRes();
    float fIdx      = float(frameCounter);
    float baseNoise = ign(pixCoord, fIdx);
    vec2  cpShift   = vec2(baseNoise, hash12(pixCoord * 0.41 + mod(fIdx, 256.0) * 1.3247));
    vec3  rayOrigin = viewPos + viewN * (0.02 + viewDist * 0.002);
    float startStep = 0.08 + viewDist * 0.012;

    vec3 accumGI = vec3(0.0);
    for (int r = 0; r < PT_RAYS; ++r) {
        float rf     = float(r);
        vec2  xi     = fract(cpShift + rf * vec2(0.75487767, 0.56984029));
        vec3  rayDir = cosineHemisphere(viewN, xi);
        float jitter = fract(baseNoise + rf * 0.38196601);

        vec2 hitUV;
        if (rayTrace(depthtex0, rayOrigin, rayDir, startStep, 1.30, jitter, PT_STEPS, hitUV)) {
            accumGI += evaluateBounceHit(hitUV, sunRad, viewL, skyAmb);
        } else {
            accumGI += getSkyLight(mat3(gbufferModelViewInverse) * rayDir) * skyVis;
        }
    }
    gl_FragData[0] = vec4(finiteColor(accumGI * (1.0 / float(PT_RAYS))), 1.0);
#else
    gl_FragData[0] = vec4(0.0);
#endif
}
#endif

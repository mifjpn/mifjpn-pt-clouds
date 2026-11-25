// Mifjpn-PT | Composite Pass 5: HDR Bloom Blend, Exposure, Tone Mapping & Grading
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/tonemap.glsl"

varying vec2 texcoord;

#ifdef VSH
void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    texcoord    = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex0;
uniform sampler2D colortex8;
uniform sampler2D colortex10;

/* DRAWBUFFERS:0 */
void main() {
    vec2 uv     = texcoord;
    vec2 relCtr = uv - 0.5;

    vec3 hdr;
    if (CHROMATIC_ABERRATION > 0.0) {
        vec2 shift = relCtr * (0.0045 * CHROMATIC_ABERRATION);
        hdr = vec3(texture2D(colortex0, uv + shift).r, texture2D(colortex0, uv).g, texture2D(colortex0, uv - shift).b);
    } else {
        hdr = texture2D(colortex0, uv).rgb;
    }

#ifdef BLOOM
    vec3 bloomTex = texture2D(colortex8, uv).rgb;
    #if defined NETHER
    float bloomMix = clamp(0.05 * BLOOM_STRENGTH * LK_BLOOM * (1.0 + 0.8 * NETHER_MOOD), 0.0, 0.5);
    #else
    float bloomMix = clamp(0.05 * BLOOM_STRENGTH * LK_BLOOM, 0.0, 0.5);
    #endif
    hdr = mix(hdr, bloomTex, bloomMix);
#endif

    float autoExp = texture2D(colortex10, vec2(0.5)).r;
    if (autoExp < 1e-4) autoExp = 1.0;
    hdr *= autoExp * EXPOSURE * LK_EXPOSURE;

#if !defined NETHER && !defined END
    if (isEyeInWater != 1) {
        float mesopic = smoothstep(1.8, 5.0, autoExp) * (1.0 - smoothstep(0.12, 0.85, luma(hdr)));
        hdr = mix(hdr, vec3(luma(hdr)) * vec3(0.78, 0.94, 1.24), mesopic * 0.6);
    }
#endif

    vec3 sdr = gradeColor(toGamma(tonemapColor(whiteBalance(hdr))));

#if defined NETHER
    {
        float moodAmt   = clamp(NETHER_MOOD, 0.0, 2.0);
        vec3  crimson   = sdr * mix(vec3(1.10, 0.86, 0.84), vec3(1.0), smoothstep(0.0, 0.45, luma(sdr)));
        crimson         = (crimson - 0.40) * 1.14 + 0.40;
        float flameMask = smoothstep(0.10, 0.45, sdr.r - sdr.b);
        crimson         = mix(vec3(luma(crimson)), crimson, mix(0.82, 1.06, flameMask));
        sdr             = saturate(mix(sdr, crimson, moodAmt * 0.75));
    }
#endif

#ifdef VIGNETTE
    float r2 = dot(relCtr, relCtr);
    #if defined NETHER
    float pulse = 1.0 + NETHER_MOOD * (0.55 + 0.10 * sin(frameTimeCounter * 0.45));
    sdr *= 1.0 - clamp(r2 * 1.35 * VIGNETTE_STRENGTH * LK_VIGNETTE * pulse, 0.0, 0.85);
    #else
    sdr *= 1.0 - clamp(r2 * 1.35 * VIGNETTE_STRENGTH * LK_VIGNETTE, 0.0, 0.80);
    #endif
#endif

    gl_FragData[0] = vec4(finiteColor(sdr), 1.0);
}
#endif

// Mifjpn-PT | Quarter-Resolution Dual-Stage HDR Bloom & Metering Downsample
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

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
uniform sampler2D colortex9;

#if defined BLOOM_DOWN
/* DRAWBUFFERS:8 */
#elif defined BLOOM_H
/* DRAWBUFFERS:9 */
#else
/* DRAWBUFFERS:8 */
#endif
void main() {
#ifdef BLOOM
    #if defined BLOOM_DOWN
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec3 down  = texture2D(colortex0, texcoord).rgb * 0.50
               + (texture2D(colortex0, texcoord + vec2(-texel.x, -texel.y)).rgb
                + texture2D(colortex0, texcoord + vec2( texel.x, -texel.y)).rgb
                + texture2D(colortex0, texcoord + vec2(-texel.x,  texel.y)).rgb
                + texture2D(colortex0, texcoord + vec2( texel.x,  texel.y)).rgb) * 0.125;
    gl_FragData[0] = vec4(min(finiteColor(down), vec3(64.0)), 1.0);
    #else
    vec2 qRes = max(floor(vec2(viewWidth, viewHeight) * 0.25), vec2(1.0));
        #if defined BLOOM_H
    vec2 stepUV = vec2(BLOOM_RADIUS / qRes.x, 0.0);
    vec3 accum  = texture2D(colortex8, texcoord).rgb;
        #else
    vec2 stepUV = vec2(0.0, BLOOM_RADIUS / qRes.y);
    vec3 accum  = texture2D(colortex9, texcoord).rgb;
        #endif
    float wTotal = 1.0;
    for (int k = 1; k <= 6; ++k) {
        float fk = float(k);
        float w  = exp(-fk * fk * (1.0 / 18.0));
        vec2 uvP = saturate(texcoord + stepUV * fk);
        vec2 uvN = saturate(texcoord - stepUV * fk);
        #if defined BLOOM_H
        accum += (texture2D(colortex8, uvP).rgb + texture2D(colortex8, uvN).rgb) * w;
        #else
        accum += (texture2D(colortex9, uvP).rgb + texture2D(colortex9, uvN).rgb) * w;
        #endif
        wTotal += 2.0 * w;
    }
    gl_FragData[0] = vec4(accum / wTotal, 1.0);
    #endif
#else
    gl_FragData[0] = vec4(0.0);
#endif
}
#endif

// Mifjpn-PT | Unlit / Auxiliary Geometry Pass (Lines, Glint, Celestial, Beacon)
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

varying vec2 vTexCoord;
varying vec4 vColor;

#ifdef VSH
void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor      = gl_Color;
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}
#endif

#ifdef FSH
uniform sampler2D texture;

#if defined BEACON
/* DRAWBUFFERS:02 */
#else
/* DRAWBUFFERS:0 */
#endif
void main() {
#if defined SKYBASIC || (defined SKYTEXTURED && defined END) || defined GBUFFERS_CLOUDS
    discard;
#elif defined BASIC
    gl_FragData[0] = vec4(toLinear(vColor.rgb), vColor.a);
#else
    vec4 outCol = texture2D(texture, vTexCoord) * vColor;
    if (outCol.a < 0.01) discard;
    gl_FragData[0] = outCol;
    #ifdef BEACON
    gl_FragData[1] = vec4(0.0, 0.02, 1.0, outCol.a);
    #endif
#endif
}
#endif

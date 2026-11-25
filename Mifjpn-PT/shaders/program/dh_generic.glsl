// Mifjpn-PT | Distant Horizons Generic Cull Pass
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"

#ifdef VSH
void main() {
#ifdef DISTANT_HORIZONS
    gl_Position = dhProjection * (gl_ModelViewMatrix * gl_Vertex);
#else
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
#endif
}
#endif

#ifdef FSH
/* DRAWBUFFERS:0 */
void main() {
    discard;
}
#endif

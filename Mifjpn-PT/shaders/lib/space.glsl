// Mifjpn-PT | Coordinate Space Transforms & Screen Footprint
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_SPACE_GLSL
#define MIFJPN_PT_SPACE_GLSL

float linearDepth(float rawDepth) {
    float ndcZ = rawDepth * 2.0 - 1.0;
    return 1.0 / max(ndcZ * gbufferProjectionInverse[2][3] + gbufferProjectionInverse[3][3], 1e-6);
}

vec3 screenToView(vec3 screenPos) {
    vec4 clip = vec4(screenPos * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

vec3 viewToScreen(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    return (clip.xyz / max(clip.w, 1e-6)) * 0.5 + 0.5;
}

vec3 viewToPlayer(vec3 viewPos) {
    return mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
}

#ifdef DISTANT_HORIZONS
vec3 dhScreenToView(vec3 screenPos) {
    vec4 clip = vec4(screenPos * 2.0 - 1.0, 1.0);
    vec4 view = dhProjectionInverse * clip;
    return view.xyz / view.w;
}
#endif

float pixelFootprint(float viewDist) {
    return (2.0 * max(viewDist, 0.0)) / max(gbufferProjection[1][1] * viewHeight, 1.0);
}

#endif

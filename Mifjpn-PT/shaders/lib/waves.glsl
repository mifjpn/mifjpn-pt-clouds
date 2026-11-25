// Mifjpn-PT | Foliage & Canopy Wind Displacement
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_WAVES_GLSL
#define MIFJPN_PT_WAVES_GLSL

vec3 windOffset(vec3 worldPos, float weight) {
    float t        = frameTimeCounter;
    float gust     = 0.82 + 0.18 * sin(t * 0.43 + (worldPos.x + worldPos.z) * 0.08);
    float amp      = (0.48 + rainStrength * 0.95) * gust * weight * WAVING_STRENGTH * 0.044;
    float phasePri = dot(worldPos.xz, vec2(0.58, 0.34)) - t * 1.75;
    float phaseSec = dot(worldPos.xz, vec2(-0.31, 0.72)) - t * 1.35;
    float swayX    = sin(phasePri) + 0.38 * sin(t * 2.95 + worldPos.z * 1.12 + worldPos.y * 0.4);
    float swayZ    = sin(phaseSec) + 0.38 * cos(t * 3.25 + worldPos.x * 0.94 + worldPos.y * 0.4);
    return vec3(swayX, 0.0, swayZ) * amp;
}

#endif

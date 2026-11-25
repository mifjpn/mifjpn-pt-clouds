// Mifjpn-PT | GI Resolution Scaling & Rotated 2x2 Bayer Subpixel Addressing
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_GI_GLSL
#define MIFJPN_PT_GI_GLSL

vec2 fullRes() { return vec2(viewWidth, viewHeight); }
vec2 giRes()   { return floor(fullRes() * GI_SCALE); }

vec2 giSampleUV(vec2 giCoord) {
#ifdef GI_HALF_RES
    float phase = mod(float(frameCounter), 4.0);
    float bx    = mod(phase, 2.0);
    float by    = mod(floor(phase * 0.5) + bx, 2.0);
    return (giCoord * 2.0 + vec2(bx, by) + 0.5) / fullRes();
#else
    return (giCoord + 0.5) / fullRes();
#endif
}

#endif

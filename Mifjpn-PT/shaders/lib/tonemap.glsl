// Mifjpn-PT | Open-Toe Filmic Tone Mapping & Display Color Grading
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_TONEMAP_GLSL
#define MIFJPN_PT_TONEMAP_GLSL

#if LOOK_PRESET == 1
    #define LK_EXPOSURE 1.00
    #define LK_CONTRAST 1.06
    #define LK_SAT      1.00
    #define LK_VIB      0.10
    #define LK_TEMP     0.0
    #define LK_TINT     0.0
    #define LK_LIFT     0.000
    #define LK_VIGNETTE 1.0
    #define LK_BLOOM    1.0
#elif LOOK_PRESET == 2
    #define LK_EXPOSURE 1.05
    #define LK_CONTRAST 1.12
    #define LK_SAT      1.18
    #define LK_VIB      0.30
    #define LK_TEMP     1.5
    #define LK_TINT     0.0
    #define LK_LIFT     0.000
    #define LK_VIGNETTE 0.8
    #define LK_BLOOM    1.1
#elif LOOK_PRESET == 3
    #define LK_EXPOSURE 0.95
    #define LK_CONTRAST 1.20
    #define LK_SAT      0.92
    #define LK_VIB      0.15
    #define LK_TEMP     1.0
    #define LK_TINT     1.0
    #define LK_LIFT     0.014
    #define LK_VIGNETTE 1.3
    #define LK_BLOOM    1.0
#elif LOOK_PRESET == 4
    #define LK_EXPOSURE 0.85
    #define LK_CONTRAST 1.16
    #define LK_SAT      0.84
    #define LK_VIB      0.05
    #define LK_TEMP    -3.0
    #define LK_TINT     0.0
    #define LK_LIFT     0.006
    #define LK_VIGNETTE 1.6
    #define LK_BLOOM    0.9
#elif LOOK_PRESET == 5
    #define LK_EXPOSURE 1.10
    #define LK_CONTRAST 0.94
    #define LK_SAT      1.12
    #define LK_VIB      0.25
    #define LK_TEMP     2.0
    #define LK_TINT     0.5
    #define LK_LIFT     0.030
    #define LK_VIGNETTE 0.6
    #define LK_BLOOM    1.8
#elif LOOK_PRESET == 6
    #define LK_EXPOSURE 0.92
    #define LK_CONTRAST 1.22
    #define LK_SAT      1.05
    #define LK_VIB      0.20
    #define LK_TEMP    -2.0
    #define LK_TINT     0.8
    #define LK_LIFT     0.012
    #define LK_VIGNETTE 1.7
    #define LK_BLOOM    2.2
#else
    #define LK_EXPOSURE 1.00
    #define LK_CONTRAST 1.00
    #define LK_SAT      1.00
    #define LK_VIB      0.00
    #define LK_TEMP     0.0
    #define LK_TINT     0.0
    #define LK_LIFT     0.000
    #define LK_VIGNETTE 1.0
    #define LK_BLOOM    1.0
#endif

vec3  acesCurve(vec3 x)       { return saturate((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)); }
vec3  openToeFilmic3(vec3 x)  { return saturate((x * (2.20 * x + 0.16)) / (x * (2.15 * x + 0.65) + 0.14)); }
float openToeFilmic1(float x) { return saturate((x * (2.20 * x + 0.16)) / (x * (2.15 * x + 0.65) + 0.14)); }
vec3  hableCurve(vec3 x)      { return ((x * (0.15 * x + 0.05) + 0.004) / (x * (0.15 * x + 0.50) + 0.06)) - (0.02 / 0.30); }

vec3 tonemapColor(vec3 hdr) {
    vec3 c = max(hdr, vec3(0.0));
#if TONEMAP == 1
    return acesCurve(c);
#elif TONEMAP == 2
    return saturate(hableCurve(c * 2.0) / hableCurve(vec3(11.2)));
#elif TONEMAP == 3
    float y  = luma(c);
    float ym = (y * (1.0 + y * 0.0625)) / (1.0 + y);
    return saturate(c * (ym / max(y, 1e-4)));
#elif TONEMAP == 4
    return saturate(c);
#else
    float lum     = luma(c);
    vec3  lumPath = c * (openToeFilmic1(lum) / max(lum, 1e-4));
    vec3  rgbPath = openToeFilmic3(c);
    vec3  blended = mix(lumPath, rgbPath, 0.42);
    float maxCh   = max(blended.r, max(blended.g, blended.b));
    if (maxCh > 1.0) blended /= maxCh;
    return saturate(blended);
#endif
}

vec3 gradeColor(vec3 disp) {
    float cGain = CONTRAST * LK_CONTRAST;
    float sGain = SATURATION * LK_SAT;
    float vGain = VIBRANCE + LK_VIB;
    float bLift = BLACK_LIFT + LK_LIFT;

    vec3 col = saturate((disp - 0.45) * cGain + 0.45);
    float y  = luma(col);
    float ch = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
    col = mix(vec3(y), col, sGain * (1.0 + vGain * (1.0 - ch)));
    return saturate(col * (1.0 - bLift) + bLift);
}

vec3 whiteBalance(vec3 lin) {
    float temp = (float(TEMPERATURE) + LK_TEMP) * 0.1;
    float tint = (float(TINT) + LK_TINT) * 0.1;
    return max(lin * vec3(1.0 + 0.16 * temp, 1.0 - 0.06 * tint, 1.0 - 0.16 * temp), vec3(0.0));
}

#endif

// Mifjpn-PT | Math Primitives, Octahedral Normals, Noise & Sampling
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_COMMON_GLSL
#define MIFJPN_PT_COMMON_GLSL

const float PI           = 3.14159265359;
const float TAU          = 6.28318530718;
const float GOLDEN_ANGLE = 2.39996322973;

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2  saturate(vec2  x) { return clamp(x, 0.0, 1.0); }
vec3  saturate(vec3  x) { return clamp(x, 0.0, 1.0); }
vec4  saturate(vec4  x) { return clamp(x, 0.0, 1.0); }

float luma(vec3 rgb) {
    return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec3 toLinear(vec3 srgb) {
    return pow(max(srgb, vec3(0.0)), vec3(2.2));
}

vec3 toGamma(vec3 lin) {
    return pow(max(lin, vec3(0.0)), vec3(1.0 / 2.2));
}

vec3 finiteColor(vec3 c) {
    return vec3(
        (c.r >= 0.0 && c.r < 65000.0) ? c.r : 0.0,
        (c.g >= 0.0 && c.g < 65000.0) ? c.g : 0.0,
        (c.b >= 0.0 && c.b < 65000.0) ? c.b : 0.0
    );
}

vec2 snapToTexel(vec2 uv, vec2 res) {
    return (floor(uv * res) + 0.5) / res;
}

vec2 octSignNonZero(vec2 v) {
    return vec2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0);
}

vec2 encodeNormal(vec3 n) {
    vec2 p = n.xy * (1.0 / max(abs(n.x) + abs(n.y) + abs(n.z), 1e-6));
    if (n.z < 0.0) p = (1.0 - abs(p.yx)) * octSignNonZero(p);
    return p * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 enc) {
    vec2 f = enc * 2.0 - 1.0;
    vec3 n = vec3(f.xy, 1.0 - abs(f.x) - abs(f.y));
    float t = max(-n.z, 0.0);
    n.xy += vec2(n.x >= 0.0 ? -t : t, n.y >= 0.0 ? -t : t);
    return normalize(n);
}

// Henyey-Greenstein normalized so isotropic (g = 0) equals 1.0
float phaseHGn(float cosTheta, float g) {
    float g2 = g * g;
    float d  = max(1.0 + g2 - 2.0 * g * cosTheta, 1e-4);
    return (1.0 - g2) / (d * sqrt(d));
}

// Integer-free Dave Hoskins style hashes & Jorge Jimenez IGN
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float ign(vec2 pixCoord, float frameIdx) {
    vec2 p = pixCoord + mod(frameIdx, 64.0) * 5.588238;
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    mat2  rot = mat2(0.80, -0.60, 0.60, 0.80);
    for (int i = 0; i < 4; ++i) {
        sum += amp * noise2D(p);
        p    = rot * p * 2.02 + vec2(13.7, 5.3);
        amp *= 0.5;
    }
    return sum * (1.0 / 0.9375);
}

vec2 vogelDisk(int idx, int total, float phiOffset) {
    float r     = sqrt((float(idx) + 0.5) / float(max(total, 1)));
    float theta = float(idx) * GOLDEN_ANGLE + phiOffset;
    return vec2(cos(theta), sin(theta)) * r;
}

// Pixar branchless orthonormal basis + Malley cosine hemisphere
vec3 cosineHemisphere(vec3 N, vec2 xi) {
    float r   = sqrt(xi.x);
    float phi = TAU * xi.y;
    vec2  d   = vec2(cos(phi), sin(phi)) * r;
    float z   = sqrt(max(1.0 - xi.x, 0.0));

    float s = N.z >= 0.0 ? 1.0 : -1.0;
    float a = -1.0 / (s + N.z);
    float b = N.x * N.y * a;
    vec3  T = vec3(1.0 + s * N.x * N.x * a, s * b, -s * N.x);
    vec3  B = vec3(b, s + N.y * N.y * a, -N.y);
    return normalize(T * d.x + B * d.y + N * z);
}

#endif

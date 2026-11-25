// Mifjpn-PT | Direct Illumination, LabPBR Conductors & Height-Correlated Smith-GGX
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_LIGHTING_GLSL
#define MIFJPN_PT_LIGHTING_GLSL

vec3 torchColor() {
    return pow(vec3(1.0, 0.52, 0.22), vec3(TORCH_WARMTH));
}

vec3 blockLight(float lmBlock) {
    float atten = pow(max(lmBlock, 0.0), 2.6) * TORCH_BRIGHTNESS;
#if defined NETHER
    return torchColor() * atten;
#else
    return torchColor() * (atten * 2.2);
#endif
}

bool isMetalCode(float f0) {
    return f0 > (229.5 / 255.0);
}

bool namedMetal(float f0, out vec3 reflectance) {
    int code = int(floor(f0 * 255.0 + 0.5));
    reflectance = vec3(1.0);
    if (code < 230 || code > 237) return false;
    if      (code == 230) reflectance = vec3(0.531, 0.512, 0.496);
    else if (code == 231) reflectance = vec3(0.944, 0.776, 0.373);
    else if (code == 232) reflectance = vec3(0.912, 0.914, 0.920);
    else if (code == 233) reflectance = vec3(0.556, 0.555, 0.555);
    else if (code == 234) reflectance = vec3(0.926, 0.721, 0.504);
    else if (code == 235) reflectance = vec3(0.632, 0.626, 0.641);
    else if (code == 236) reflectance = vec3(0.679, 0.642, 0.588);
    else                  reflectance = vec3(0.962, 0.949, 0.922);
    return true;
}

vec3 metalColor(float f0, vec3 baseAlbedo) {
    vec3 presetF0;
    return namedMetal(f0, presetF0) ? presetF0 : baseAlbedo;
}

float fresnelSchlick(float cosTheta, float f0) {
    float m  = saturate(1.0 - cosTheta);
    float m2 = m * m;
    return f0 + (1.0 - f0) * (m2 * m2 * m);
}

float specularGGX(vec3 N, vec3 V, vec3 L, float roughness, float f0) {
    float NdotL = max(dot(N, L), 0.0);
    if (NdotL <= 0.0) return 0.0;
    float NdotV = max(dot(N, V), 1e-3);
    vec3  H     = normalize(L + V);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);

    float alpha  = max(roughness * roughness, 0.003);
    float alpha2 = alpha * alpha;
    float denomD = NdotH * NdotH * (alpha2 - 1.0) + 1.0;
    float D      = alpha2 / (PI * denomD * denomD);

    float gv  = NdotL * sqrt(alpha2 + (1.0 - alpha2) * NdotV * NdotV);
    float gl  = NdotV * sqrt(alpha2 + (1.0 - alpha2) * NdotL * NdotL);
    float vis = 0.5 / max(gv + gl, 1e-4);
    float F   = fresnelSchlick(VdotH, f0);
    return min(D * vis * F * NdotL, 36.0);
}

#endif

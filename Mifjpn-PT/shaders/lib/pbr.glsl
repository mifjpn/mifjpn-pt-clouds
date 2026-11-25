// Mifjpn-PT | LabPBR 1.3 / Legacy PBR Unpacking, POM & Luma-Gradient Normals
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_PBR_GLSL
#define MIFJPN_PT_PBR_GLSL
#ifdef FSH

const float PBR_DEFAULT_POROSITY = 0.5;

vec4 pbrSample(sampler2D atlasTex, vec2 uv, vec2 gradX, vec2 gradY) {
#ifdef MIFJPN_POM
    return texture2DGradARB(atlasTex, uv, gradX, gradY);
#else
    return texture2D(atlasTex, uv);
#endif
}

vec2 wrapTile(vec2 uv, vec4 tileBounds) {
    vec2 extent = max(tileBounds.zw, vec2(1e-6));
    return tileBounds.xy + fract((uv - tileBounds.xy) / extent) * extent;
}

bool decodeNormalMap(vec4 rawNormal, out vec3 tsNormal, out float texAO) {
    vec2 nxy = rawNormal.xy * 2.0 - 1.0;
    texAO    = 1.0;
    tsNormal = vec3(0.0, 0.0, 1.0);
    if (abs(nxy.x) + abs(nxy.y) < 0.012) return false;
#if PBR_FORMAT == 1
    float nz = max(rawNormal.z * 2.0 - 1.0, 0.05);
    tsNormal = normalize(vec3(nxy * NORMAL_STRENGTH, nz));
#else
    float r2 = dot(nxy, nxy);
    if (r2 >= 1.0) return false;
    tsNormal = normalize(vec3(nxy * NORMAL_STRENGTH, sqrt(1.0 - r2)));
    texAO    = rawNormal.b;
#endif
    return true;
}

void decodeSpecular(vec4 rawSpec, inout float smoothness, inout float f0, inout float emission, inout float porosity, inout float sss) {
#if PBR_FORMAT == 1
    smoothness = rawSpec.r;
    f0         = rawSpec.g > 0.5 ? 1.0 : 0.04;
    emission   = rawSpec.b;
#else
    smoothness = rawSpec.r;
    f0         = rawSpec.g < (229.5 / 255.0) ? max(rawSpec.g, 0.02) : rawSpec.g;
    emission   = rawSpec.a < (254.5 / 255.0) ? rawSpec.a * (255.0 / 254.0) : 0.0;
    if (rawSpec.b < (64.5 / 255.0)) porosity = rawSpec.b * (255.0 / 64.0);
    else                            sss      = (rawSpec.b * 255.0 - 65.0) * (1.0 / 190.0);
    if (dot(rawSpec, vec4(1.0)) < 0.002) porosity = PBR_DEFAULT_POROSITY;
#endif
}

#ifdef MIFJPN_POM
vec2 parallaxUV(sampler2D normalTex, vec2 baseUV, vec4 tileBounds, vec3 tsViewDir, vec2 gradX, vec2 gradY, float distFade) {
    float currDepthMap = 1.0 - texture2DGradARB(normalTex, baseUV, gradX, gradY).a;
    if (currDepthMap <= 0.002 || tsViewDir.z >= 0.0 || distFade <= 0.0) return baseUV;

    vec3  vDir      = normalize(tsViewDir);
    vec2  uvSpan    = (vDir.xy / max(-vDir.z, 0.10)) * (POM_DEPTH * distFade) * tileBounds.zw;
    float layerStep = 1.0 / float(POM_STEPS);
    float rayLayer  = 0.0;
    float prevLayer = 0.0;
    float prevMap   = currDepthMap;
    vec2  marchedUV = baseUV;

    for (int s = 0; s < POM_STEPS; ++s) {
        if (rayLayer >= currDepthMap) break;
        prevLayer = rayLayer;
        prevMap   = currDepthMap;
        rayLayer += layerStep;
        marchedUV = wrapTile(baseUV + uvSpan * rayLayer, tileBounds);
        currDepthMap = 1.0 - texture2DGradARB(normalTex, marchedUV, gradX, gradY).a;
    }

    float dPrev = prevMap - prevLayer;
    float dCurr = rayLayer - currDepthMap;
    float denom = dPrev + dCurr;
    float w     = denom > 1e-5 ? saturate(dPrev / denom) : 1.0;
    return wrapTile(baseUV + uvSpan * mix(prevLayer, rayLayer, w), tileBounds);
}
#endif

#ifdef GENERATED_NORMALS
float texBrightness(sampler2D atlasTex, vec2 uv, vec4 tileBounds, vec2 texelSize, vec2 gradX, vec2 gradY) {
    vec2 halfTexel = texelSize * 0.5;
    vec2 safeUV    = clamp(uv, tileBounds.xy + halfTexel, tileBounds.xy + tileBounds.zw - halfTexel);
    return luma(pbrSample(atlasTex, safeUV, gradX, gradY).rgb);
}

vec3 generatedNormal(sampler2D atlasTex, vec2 uv, vec4 tileBounds, vec2 texelSize, vec2 gradX, vec2 gradY) {
    float hW = texBrightness(atlasTex, uv - vec2(texelSize.x, 0.0), tileBounds, texelSize, gradX, gradY);
    float hE = texBrightness(atlasTex, uv + vec2(texelSize.x, 0.0), tileBounds, texelSize, gradX, gradY);
    float hN = texBrightness(atlasTex, uv - vec2(0.0, texelSize.y), tileBounds, texelSize, gradX, gradY);
    float hS = texBrightness(atlasTex, uv + vec2(0.0, texelSize.y), tileBounds, texelSize, gradX, gradY);
    vec2 grad = vec2(hE - hW, hS - hN) * (2.0 * GENERATED_NORMAL_STRENGTH);
    return normalize(vec3(-grad, 1.0));
}
#endif

#endif
#endif

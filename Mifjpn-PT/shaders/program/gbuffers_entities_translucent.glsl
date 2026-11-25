// Mifjpn-PT | Translucent Entities Forward-Shaded Pass
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"
#include "/lib/wetness.glsl"
#include "/lib/water.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"

varying vec2 vTexCoord;
varying vec2 vLightMap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vRelPos;

vec3 safeUnitVec(vec3 v, vec3 fallback) {
    float len2 = dot(v, v);
    return len2 > 1e-6 ? (v * inversesqrt(len2)) : fallback;
}

#ifdef VSH
void main() {
    vTexCoord  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 rawLM = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vLightMap  = saturate((rawLM - 0.03125) * 1.06667);
    vColor     = gl_Color;
    vNormal    = safeUnitVec(gl_NormalMatrix * gl_Normal, vec3(0.0, 0.0, 1.0));

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vRelPos      = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec2 eyeLM   = saturate(vec2(eyeBrightnessSmooth) * (1.0 / 240.0));
    vLightMap    = max(vLightMap, eyeLM * ((1.0 - smoothstep(2.5, 7.0, length(vRelPos))) * 0.85));
    gl_Position  = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}
#endif

#ifdef FSH
uniform sampler2D texture;

/* DRAWBUFFERS:026 */
void main() {
    vec4 texCol = texture2D(texture, vTexCoord) * vColor;
    if (texCol.a < 0.1) discard;
    texCol.rgb = mix(texCol.rgb, entityColor.rgb, entityColor.a);

    vec3 linCol = toLinear(texCol.rgb);
    vec3 viewN  = safeUnitVec(vNormal, vec3(0.0, 0.0, 1.0));
    if (!gl_FrontFacing) viewN = -viewN;

    vec3  worldN   = mat3(gbufferModelViewInverse) * viewN;
    float rawNL    = dot(viewN, normalize(shadowLightPosition));
    float wrapDiff = max(rawNL * 0.65 + 0.35, 0.0) * 0.9;

    vec3  visShad = vec3(0.0);
    float wPath   = 0.0;
    if (wrapDiff > 0.0) {
#ifdef SHADOWS
        visShad = getShadow(vRelPos, rawNL > 0.0 ? worldN : lightDirWorld(), ign(gl_FragCoord.xy, 0.0), vLightMap.y, wPath);
#else
        visShad = vec3(unshadowedLight(vLightMap.y));
#endif
    }

    vec3 irrad = getLightColor() * visShad * wrapDiff + getSkyLight(worldN) * skyOcclusion(vLightMap.y) + blockLight(vLightMap.x) + vec3(0.015 + nightVision * 0.25);
#if defined NETHER
    irrad += netherUnderglow(vRelPos + cameraPosition, worldN);
#endif

    gl_FragData[0] = vec4(finiteColor(linCol * irrad), texCol.a);
    gl_FragData[1] = vec4(0.0, 0.02, 0.0, 1.0);
    gl_FragData[2] = vec4(1.0, MAT_ENTITY / 255.0, 0.0, 1.0);
}
#endif

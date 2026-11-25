// Mifjpn-PT | Forward-Lit Particles & Weather Pass
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/sky.glsl"
#include "/lib/lighting.glsl"
#ifdef WEATHER
#include "/lib/rain.glsl"
#endif

varying vec2 vTexCoord;
varying vec2 vLightMap;
varying vec4 vColor;

#if defined WEATHER && defined REALISTIC_RAIN
varying float vSheetMask;
varying vec3  vRelPos;
uniform ivec2 atlasSize;
#endif

#ifdef VSH
void main() {
    vTexCoord  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 rawLM = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vLightMap  = saturate((rawLM - 0.03125) * 1.06667);
    vColor     = gl_Color;

#if defined WEATHER && defined REALISTIC_RAIN
    float fracU = fract(vTexCoord.x);
    vSheetMask  = (fracU < 2e-5 || fracU > 0.99998) ? 1.0 : 0.0;
    if (atlasSize.x > 0) vSheetMask = 0.0;
    vec4 rel    = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
    rel.xz     -= rainWind() * (rel.y * vSheetMask);
    vRelPos     = rel.xyz;
    gl_Position = gl_ProjectionMatrix * (gbufferModelView * rel);
#else
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
#endif
}
#endif

#ifdef FSH
uniform sampler2D texture;

#if defined WEATHER && defined REALISTIC_RAIN
/* RENDERTARGETS: 12,13 */
#else
/* DRAWBUFFERS:0 */
#endif
void main() {
#if defined WEATHER && defined REALISTIC_RAIN
    gl_FragData[1] = vec4(0.0);
    if (atlasSize.x > 0) {
        float dist    = max(length(vRelPos), 1e-3);
        vec2  atDim   = vec2(atlasSize);
        vec2  subUV   = fract(vTexCoord * atDim);
        float alphaC  = texture2D(texture, vTexCoord).a;
        float alphaN  = texture2D(texture, vTexCoord + vec2((subUV.x < 0.5 ? -1.0 : 1.0) / atDim.x, 0.0)).a;
        float taper   = mix(alphaC, alphaN, abs(subUV.x - 0.5));
        float profile = mix(1.0 - smoothstep(0.10, 0.50, abs(subUV.y - 0.5)), 0.45, smoothstep(0.3, 0.8, fwidth(vTexCoord.y * atDim.y)));
        float opacity = taper * profile * vColor.a * sqrt(max(vColor.r, max(vColor.g, vColor.b))) * (0.8 * RAIN_OPACITY);
        if (alphaC < 0.02 || profile < 0.1 || opacity < 0.004) discard;
        vec3 dropRad = rainRadiance(vRelPos / dist, getSkyAmbient(), skyOcclusion(vLightMap.y)) + blockLight(vLightMap.x) * 0.55 + vec3(0.004 + nightVision * 0.25);
        gl_FragData[0] = vec4(dropRad, min(opacity, 0.9));
        gl_FragData[1] = vec4(1.0);
        return;
    }

    if (vSheetMask > 0.5) {
    #ifdef SIMULATED_RAIN
        discard;
    #endif
    #ifdef TEXTURED_RAIN
        {
            vec4  rTex  = texture2D(texture, vTexCoord);
            float dist  = max(length(vRelPos), 1e-3);
            float alpha = rTex.a * vColor.a * 0.40 * rainStrength * RAIN_OPACITY * smoothstep(0.3, 1.2, dist);
            if (alpha < 0.003) discard;
            vec3 tint  = sqrt(max(rTex.rgb, vec3(0.0)));
            tint       = mix(vec3(luma(tint)), tint, 0.45);
            vec3 irrad = getSkyAmbient() * (skyOcclusion(vLightMap.y) * 1.8) + getLightColor() * 0.08 + blockLight(vLightMap.x) * 0.8 + vec3(0.004 + nightVision * 0.25);
            gl_FragData[0] = vec4(tint * irrad, min(alpha, 0.9));
            return;
        }
    #endif
        float dist  = max(length(vRelPos), 1e-3);
        float alpha = rainQuadStreaks(vTexCoord, fwidth(vTexCoord.x), saturate(0.5 * RAIN_AMOUNT)) * 0.42 * RAIN_OPACITY * vColor.a;
        alpha      *= smoothstep(0.3, 1.5, dist) * (0.35 + 0.65 * smoothstep(1.0, 5.0, dist));
        if (alpha < 0.003) discard;
        vec3 streakRad = rainRadiance(vRelPos / dist, getSkyAmbient(), skyOcclusion(vLightMap.y)) + blockLight(vLightMap.x) * 0.55 + vec3(0.004 + nightVision * 0.25);
        gl_FragData[0] = vec4(streakRad, min(alpha, 0.9));
        return;
    }
#endif

    vec4 texCol = texture2D(texture, vTexCoord) * vColor;
    if (texCol.a < 0.1) discard;

#if !defined WEATHER && defined REALISTIC_RAIN
    if (rainStrength > 0.02 && vLightMap.y > 0.6 && texCol.b > texCol.r * 1.25 && texCol.b > texCol.g * 1.02) discard;
#endif

    vec3 linAlbedo = toLinear(texCol.rgb);
    vec3 skyIrrad  = getSkyAmbient() * skyOcclusion(vLightMap.y);
    vec3 irrad     = getLightColor() * (0.6 * pow(vLightMap.y, 4.0)) + skyIrrad + blockLight(vLightMap.x) + vec3(0.004 + nightVision * 0.25);

#ifdef WEATHER
    texCol.a *= 0.35;
    irrad     = skyIrrad * 1.5 + getLightColor() * 0.1 + blockLight(vLightMap.x);
#endif

#if defined WEATHER && defined REALISTIC_RAIN
    if (texCol.b > texCol.r * 1.4 + 0.05) {
        float dist = max(length(vRelPos), 1e-3);
        gl_FragData[0] = vec4(rainRadiance(vRelPos / dist, getSkyAmbient(), skyOcclusion(vLightMap.y)) + blockLight(vLightMap.x) * 0.55, texCol.a * RAIN_OPACITY);
        return;
    }
#endif

    gl_FragData[0] = vec4(finiteColor(linAlbedo * irrad), texCol.a);
}
#endif

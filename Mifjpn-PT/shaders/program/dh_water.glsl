// Mifjpn-PT | Distant Horizons Far Water & Translucent Surface Pass
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"
#include "/lib/wetness.glsl"
#include "/lib/water.glsl"
#include "/lib/lighting.glsl"

varying vec2  vLightMap;
varying vec4  vColor;
varying vec3  vViewNormal;
varying vec3  vRelPos;
varying float vMatID;

#ifdef VSH
void main() {
    vec2 rawLM  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vLightMap   = saturate((rawLM - 0.03125) * 1.06667);
    vColor      = gl_Color;
    vViewNormal = normalize(gl_NormalMatrix * gl_Normal);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vRelPos      = (gbufferModelViewInverse * viewPos).xyz;
    vMatID       = MAT_GLASS;

#ifdef DISTANT_HORIZONS
    if (dhMaterialId == DH_BLOCK_WATER) vMatID = MAT_WATER;
    gl_Position = dhProjection * viewPos;
#else
    gl_Position = gl_ProjectionMatrix * viewPos;
#endif
}
#endif

#ifdef FSH
uniform sampler2D depthtex0;

/* DRAWBUFFERS:1265 */
void main() {
    if (texture2D(depthtex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r < 1.0) discard;
    if (length(vRelPos.xz) < far - 16.0) discard;

    float matCode = floor(vMatID + 0.5);
    vec3  viewN   = normalize(vViewNormal);
    vec2  lm      = vec2(vLightMap.x, max(vLightMap.y, 0.94));
    vec3  worldN  = mat3(gbufferModelViewInverse) * viewN;

    if (matCode == MAT_WATER) {
        float waveCrest = 0.0, subRough = 0.02, foamMask = 0.0;
#ifdef WATER_WAVES
        if (worldN.y > 0.5) {
            vec3  worldPos  = cameraPosition + vRelPos;
            float openRain  = rainStrength * smoothstep(0.5, 0.95, lm.y);
            float dist      = length(vRelPos);
            float footprint = pixelFootprint(dist) / sqrt(max(abs(vRelPos.y) / max(dist, 1e-3), 0.02));
            worldN = waterNormalWorld(worldPos.xz, footprint, openRain, waveCrest, subRough);
    #ifdef WATER_FOAM
            foamMask = smoothstep(0.55, 1.0, waveCrest) * (0.08 + 0.92 * rainStrength);
    #endif
        }
#endif
        viewN = normalize(mat3(gbufferModelView) * worldN);
        gl_FragData[0] = vec4(encodeNormal(viewN), lm);
        gl_FragData[1] = vec4(saturate(vColor.rgb), waveCrest);
        gl_FragData[2] = vec4(subRough, matCode / 255.0, foamMask, 1.0);
        gl_FragData[3] = vec4(0.0);
        return;
    }

    if (vColor.a < 0.02) discard;
    vec3  linCol = toLinear(vColor.rgb);
    float nl     = max(dot(viewN, normalize(shadowLightPosition)), 0.0);
    vec3  irrad  = getLightColor() * unshadowedLight(lm.y) * nl + getSkyAmbient() * skyOcclusion(lm.y) + blockLight(vLightMap.x) + vec3(0.004 + nightVision * 0.25);

    gl_FragData[0] = vec4(encodeNormal(viewN), lm);
    gl_FragData[1] = vec4(0.93, 0.04, 0.0, 1.0);
    gl_FragData[2] = vec4(1.0, MAT_GLASS / 255.0, 0.0, 1.0);
    gl_FragData[3] = vec4(linCol * irrad, vColor.a);
}
#endif

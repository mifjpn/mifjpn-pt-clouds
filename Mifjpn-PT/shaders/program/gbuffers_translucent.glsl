// Mifjpn-PT | Translucent G-Buffer & Water Surface Descriptor Pass
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

varying vec2  vTexCoord;
varying vec2  vLightMap;
varying vec4  vColor;
varying vec3  vNormal;
varying vec3  vRelPos;
varying float vMatID;

#ifdef VSH
attribute vec4 mc_Entity;

void main() {
    vTexCoord  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec2 rawLM = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vLightMap  = saturate((rawLM - 0.03125) * 1.06667);
    vColor     = gl_Color;
    vNormal    = normalize(gl_NormalMatrix * gl_Normal);

#ifdef HAND
    vMatID = MAT_GLASS;
#else
    vMatID = mc_Entity.x > 9999.5 ? (mc_Entity.x - 10000.0) : MAT_GLASS;
#endif

    vec4 localVert = gl_Vertex;
#ifdef MIFJPN_PHYSICS_OCEAN
    if (mc_Entity.x < 9999.5) vMatID = MAT_WATER;
    if (abs(vMatID - MAT_WATER) < 0.5) {
        vec4 physics_position = physics_oceanVertex(gl_Vertex);
        localVert = physics_position;
        if (vLightMap.x < 0.01 && vLightMap.y < 0.01) vLightMap.y = 1.0;
        if (max(vColor.r, max(vColor.g, vColor.b)) < 0.05) vColor = vec4(WATER_DEFAULT_TINT, 1.0);
    }
#endif

    vec3 viewPos = (gl_ModelViewMatrix * localVert).xyz;
    vRelPos      = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    gl_Position  = gl_ProjectionMatrix * vec4(viewPos, 1.0);
}
#endif

#ifdef FSH
uniform sampler2D texture;

/* DRAWBUFFERS:1265 */
void main() {
    vec4  texCol  = texture2D(texture, vTexCoord) * vColor;
    float matCode = floor(vMatID + 0.5);
    vec3  viewN   = normalize(vNormal);

    if (matCode == MAT_WATER) {
        vec3 faceN = normalize(cross(dFdx(vRelPos), dFdy(vRelPos)));
        if (dot(faceN, mat3(gbufferModelViewInverse) * viewN) < 0.0) faceN = -faceN;

        vec3  worldN    = faceN;
        float waveCrest = 0.0, subRough = 0.02, foamMask = 0.0;

#ifdef MIFJPN_PHYSICS_OCEAN
        PhysicsOceanData ocean = physics_oceanFragment();
        worldN = ocean.normal;
        vec2  worldXZ   = cameraPosition.xz + vRelPos.xz;
        float foamBreak = noise2D(worldXZ * 2.3 + frameTimeCounter * vec2(0.20, -0.12)) * 0.6
                        + noise2D(worldXZ * 6.1 - frameTimeCounter * vec2(0.30,  0.25)) * 0.4;
        float distFade  = 1.0 - smoothstep(40.0, 160.0, length(vRelPos));
        foamMask  = smoothstep(0.45, 0.95, ocean.foam + (foamBreak - 0.5) * 0.45) * 0.75 * distFade;
        waveCrest = ocean.foam * 0.6 * distFade;
        subRough  = clamp(length(fwidth(worldN)) * 0.8, 0.02, 0.40);
#elif defined WATER_WAVES
        if (faceN.y > 0.5) {
            vec3 surfPos = cameraPosition + vRelPos;
    #ifdef WATER_PARALLAX
            vec3 waveHit = waterRayHit(cameraPosition, surfPos);
    #else
            vec3 waveHit = surfPos;
    #endif
            float openRain  = rainStrength * smoothstep(0.5, 0.95, vLightMap.y);
            float dist      = length(vRelPos);
            float footprint = pixelFootprint(dist) / sqrt(max(abs(vRelPos.y) / max(dist, 1e-3), 0.02));
            worldN = waterNormalWorld(waveHit.xz, footprint, openRain, waveCrest, subRough);
    #ifdef WATER_FOAM
            foamMask = smoothstep(0.55, 1.0, waveCrest) * (0.06 + 0.55 * rainStrength);
    #endif
        }
#endif

        viewN = normalize(mat3(gbufferModelView) * worldN);
        vec3 biomeTint = saturate(vColor.rgb);
#ifdef MIFJPN_PHYSICS_OCEAN
        biomeTint = biomeWaterColor();
#endif
        gl_FragData[0] = vec4(encodeNormal(viewN), vLightMap);
        gl_FragData[1] = vec4(biomeTint, waveCrest);
        gl_FragData[2] = vec4(subRough, matCode / 255.0, foamMask, 1.0);
        gl_FragData[3] = vec4(0.0);
        return;
    }

    if (texCol.a < 0.02) discard;
    vec3  linCol  = toLinear(texCol.rgb);
    vec3  viewL   = normalize(shadowLightPosition);
    float nl      = max(dot(viewN, viewL), 0.0);
    vec3  visShad = vec3(0.0);
    float wPath   = 0.0;

    if (nl > 0.0) {
#ifdef SHADOWS
        visShad = getShadow(vRelPos, mat3(gbufferModelViewInverse) * viewN, ign(gl_FragCoord.xy, 0.0), vLightMap.y, wPath);
#else
        visShad = vec3(unshadowedLight(vLightMap.y));
#endif
    }

    vec3 irrad = getLightColor() * visShad * nl + getSkyAmbient() * skyOcclusion(vLightMap.y) + blockLight(vLightMap.x) + vec3(0.004 + nightVision * 0.25);
    gl_FragData[0] = vec4(encodeNormal(viewN), vLightMap);
    gl_FragData[1] = vec4(0.93, 0.04, 0.0, 1.0);
    gl_FragData[2] = vec4(1.0, MAT_GLASS / 255.0, 0.0, 1.0);
    gl_FragData[3] = vec4(finiteColor(linCol * irrad), texCol.a);
}
#endif

// Mifjpn-PT | Shadow Map Depth & Colored Water-Column Tag Pass
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/waves.glsl"

varying vec2  vTexCoord;
varying vec4  vColor;
varying float vWaterMask;

#ifdef VSH
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

vec3 warpShadowPosition(vec3 clipPos) {
    float radial = length(clipPos.xy) * 0.9 + 0.1;
    return vec3(clipPos.xy / radial, clipPos.z * 0.2);
}

void main() {
    vTexCoord      = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor         = gl_Color;
    float blockMat = mc_Entity.x - 10000.0;
    vWaterMask     = abs(blockMat - MAT_WATER) < 0.5 ? 1.0 : 0.0;

    vec4 localVert = gl_Vertex;
#ifdef MIFJPN_PHYSICS_OCEAN
    if (mc_Entity.x < 9999.5) vWaterMask = 1.0;
    if (vWaterMask > 0.5) {
        vec4 physics_position = physics_oceanVertex(gl_Vertex);
        localVert = physics_position;
    }
#endif

    vec4 relPos   = shadowModelViewInverse * (gl_ModelViewMatrix * localVert);
    vec3 worldPos = relPos.xyz + cameraPosition;

#ifdef WAVING_PLANTS
    if (abs(blockMat - MAT_LEAVES) < 0.5) relPos.xyz += windOffset(worldPos, 0.6);
    else if (abs(blockMat - MAT_PLANT) < 0.5 && vTexCoord.y < mc_midTexCoord.y) relPos.xyz += windOffset(worldPos, 1.0);
#endif

    vec4 shadowClip = gl_ProjectionMatrix * (shadowModelView * relPos);
    shadowClip.xyz  = warpShadowPosition(shadowClip.xyz);
    gl_Position     = shadowClip;
}
#endif

#ifdef FSH
uniform sampler2D texture;

void main() {
    vec4 texCol = texture2D(texture, vTexCoord) * vColor;
    if (texCol.a < 0.1) discard;

    if (vWaterMask > 0.5) {
        texCol = vec4(WATER_TAG, 1.0);
#ifdef MIFJPN_PHYSICS_OCEAN
        PhysicsOceanData ocean = physics_oceanFragment();
        if (ocean.foam > 0.6) texCol.rgb = vec3(0.92);
#endif
    }
    gl_FragData[0] = texCol;
}
#endif

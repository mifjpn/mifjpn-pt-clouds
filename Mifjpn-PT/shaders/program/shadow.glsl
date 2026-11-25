// Mifjpn-PT | Shadow Map Pass (MC 26.3 Zero-to-One Patcher Compatible)
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
    return vec3(clipPos.xy / radial, clipPos.z * 0.5);
}

void main() {
    vTexCoord      = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor         = gl_Color;
    float blockMat = mc_Entity.x - 10000.0;
    vWaterMask     = abs(blockMat - MAT_WATER) < 0.5 ? 1.0 : 0.0;

    vec4 shadowViewPos = gl_ModelViewMatrix * gl_Vertex;

#ifdef WAVING_PLANTS
    bool isLeaves = abs(blockMat - MAT_LEAVES) < 0.5;
    bool isPlant  = abs(blockMat - MAT_PLANT)  < 0.5 && vTexCoord.y < mc_midTexCoord.y;
    if (isLeaves || isPlant) {
        vec4 relPos   = shadowModelViewInverse * shadowViewPos;
        vec3 worldPos = relPos.xyz + cameraPosition;
        relPos.xyz   += windOffset(worldPos, isLeaves ? 0.6 : 1.0);
        shadowViewPos = shadowModelView * relPos;
    }
#endif

    vec4 shadowClip = gl_ProjectionMatrix * shadowViewPos;
    shadowClip.xyz  = warpShadowPosition(shadowClip.xyz);
    gl_Position     = shadowClip;
}
#endif

#ifdef FSH
uniform sampler2D texture;

/* DRAWBUFFERS:0 */
void main() {
    vec4 rawTex = texture2D(texture, vTexCoord);
    if (rawTex.a < 0.1) discard;

    vec4 texCol = vec4(rawTex.rgb * vColor.rgb, rawTex.a);
    if (vWaterMask > 0.5) {
        texCol = vec4(WATER_TAG, 1.0);
    }
    gl_FragData[0] = texCol;
}
#endif

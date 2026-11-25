// Mifjpn-PT | Iris & Minecraft Engine Uniform Declarations
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_UNIFORMS_GLSL
#define MIFJPN_PT_UNIFORMS_GLSL

uniform float viewWidth;
uniform float viewHeight;
uniform int   frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;

uniform float near;
uniform float far;
uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3  sunPosition;
uniform vec3  moonPosition;
uniform vec3  shadowLightPosition;
uniform vec3  upPosition;

uniform float rainStrength;
uniform float wetness;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3  fogColor;
uniform vec3  skyColor;

uniform int   isEyeInWater;
uniform float nightVision;
uniform float blindness;
uniform vec4  entityColor;

uniform int   biome;
uniform int   biome_category;
uniform int   biome_precipitation;
uniform float temperature;
uniform float rainfall;

#ifdef DISTANT_HORIZONS
uniform float     dhNearPlane;
uniform float     dhFarPlane;
uniform int       dhRenderDistance;
uniform mat4      dhProjection;
uniform mat4      dhProjectionInverse;
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

float worldEdge() {
#ifdef DISTANT_HORIZONS
    return max(far, float(dhRenderDistance));
#else
    return far;
#endif
}

#endif

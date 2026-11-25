// Mifjpn-PT Clouds Edition | Global Configuration & Material Constants
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_SETTINGS_GLSL
#define MIFJPN_PT_SETTINGS_GLSL

// ---- Feature Toggles ----
#define AUTO_EXPOSURE
#define PHYSICAL_SKY
#define VOLUMETRIC_LIGHT
#define MILKY_WAY
//#define AURORA
#define SNOWY_AURORA
#define CLOUDS
#define VOLUMETRIC_CLOUDS
#define CLOUD_CIRRUS
#define CLOUD_INTERACTION
#define WATER_WAVES
#define WATER_PARALLAX
#define WATER_REFRACTION
//#define SNELLS_WINDOW
#define WATER_SSS
#define WATER_CAUSTICS
#define WATER_FOAM
//#define WATER_SHORE_FOAM
//#define REALISTIC_RAIN
//#define TEXTURED_RAIN
//#define DISTANT_RAIN
#define SIMULATED_RAIN
#define RAIN_PUDDLES
#define RAIN_RIPPLES
//#define RAIN_SPLASHES
#define RAIN_WALL_STREAKS
#define NETHER_SMOKE
#define NETHER_LAVA
#define NETHER_EMBERS
#define END_SHADOWS
#define END_MIST_VOLUME
#define END_MIST_SPLASH
#define END_MIST_UNDERSIDE
#define END_MOTES
#define WAVING_PLANTS
#define LABPBR
#define PBR_SSS
#define POM
#define GENERATED_NORMALS
#define PATH_TRACING
#define PT_DENOISER
//#define GI_HALF_RES
#define RAY_TRACED_REFLECTIONS
//#define ROUGH_REFLECTIONS
#define SHADOWS
//#define SHADOW_DEBUG
#define CONTACT_SHADOWS
#define COLORED_SHADOWS
#define BLOOM
#define VIGNETTE
#define FXAA
#define PHYSICS_MOD_SUPPORT

// ---- Exposure, Tone Mapping & Grading ----
#define LOOK_PRESET 0 // [0 1 2 3 4 5 6]
#define TONEMAP 0 // [0 1 2 3 4]
#define EXPOSURE 1.00 // [0.25 0.50 0.70 0.85 1.00 1.15 1.30 1.50 1.80 2.20 3.00]
#define EXPOSURE_SPEED 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00 5.00]
#define NIGHT_VISIBILITY 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define CONTRAST 1.00 // [0.70 0.80 0.90 0.95 1.00 1.05 1.10 1.15 1.25 1.40]
#define SATURATION 1.00 // [0.00 0.50 0.75 0.90 1.00 1.10 1.20 1.35 1.50]
#define VIBRANCE 0.05 // [-0.50 -0.25 0.00 0.05 0.10 0.20 0.30 0.40 0.60]
#define TEMPERATURE 0.0 // [-5.0 -4.0 -3.0 -2.0 -1.0 0.0 1.0 2.0 3.0 4.0 5.0]
#define TINT 0.0 // [-5.0 -4.0 -3.0 -2.0 -1.0 0.0 1.0 2.0 3.0 4.0 5.0]
#define BLACK_LIFT 0.000 // [0.000 0.005 0.010 0.015 0.020 0.030 0.050]

// ---- Sky, Atmosphere & Light Shafts ----
#define BIOME_ATMOSPHERE 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50]
#define SUN_BRIGHTNESS 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define SUN_SIZE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define SUN_GLOW 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define SKY_BRIGHTNESS 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define SKY_SATURATION 1.10 // [0.00 0.50 0.75 0.90 1.00 1.10 1.25 1.50]
#define SUNSET_STRENGTH 1.00 // [0.00 0.50 0.75 1.00 1.25 1.50 2.00]
#define FOG_DENSITY 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00 3.00]
const float sunPathRotation = -35.0; // [-60.0 -45.0 -35.0 -25.0 -15.0 0.0 15.0 25.0 35.0 45.0]
#define VL_STEPS 10 // [4 6 8 10 12 16 24 32]
#define VL_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00 3.00]

// ---- Night & Aurora ----
#define MOON_BRIGHTNESS 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define STAR_BRIGHTNESS 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define AURORA_INTENSITY 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define AURORA_PRESET 1 // [0 1 2 3 4]
#define AURORA_SPEED 1.00 // [0.00 0.25 0.50 1.00 1.50 2.00 3.00]
#define AURORA_ALWAYS_ON 0 // [0 1]
#define SNOWY_AURORA_INTENSITY 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00]

// ---- Dual-Layer Clouds (Low Cumulus + High Cirrus/Cirrocumulus) ----
#define CLOUD_COVERAGE 0.38 // [0.15 0.30 0.38 0.45 0.52 0.62 0.72 0.85]
#define CLOUD_DENSITY 1.00 // [0.40 0.60 0.80 1.00 1.25 1.50 2.00]
#define CLOUD_SPEED 1.00 // [0.00 0.25 0.50 1.00 1.50 2.00 3.00]
#define CLOUD_STEPS 20 // [8 12 16 20 24 32 48]
#define CLOUD_ALTITUDE 320.0 // [128.0 160.0 192.0 224.0 256.0 320.0 384.0]
#define CLOUD_THICKNESS 180.0 // [60.0 85.0 110.0 140.0 180.0 220.0]
#define CLOUD_BRIGHTNESS 1.00 // [0.50 0.75 1.00 1.25 1.50]
#define CLOUD_SHADOW_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00]
#define CLOUD_HIGH_COVERAGE 0.62 // [0.00 0.25 0.40 0.55 0.62 0.75 0.90 1.00]
#define CLOUD_HIGH_DENSITY 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define CLOUD_JOLT 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50]

// ---- Water & Ocean ----
#define WAVE_HEIGHT 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define WAVE_SCALE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define WAVE_SPEED 1.00 // [0.00 0.50 0.75 1.00 1.25 1.50 2.00]
#define WAVE_VARIATION 1.00 // [0.00 0.25 0.50 0.75 1.00]
#define REFRACTION_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define WATER_REFLECTIVITY 1.00 // [0.25 0.50 0.75 1.00 1.25]
#define WATER_GLITTER 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define CAUSTIC_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define FOAM_AMOUNT 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define WATER_COLOR_MODE 0 // [0 1 2 3 4 5 6]
#define WATER_CLARITY 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define WATER_BIOME_TINT 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50]
#define WATER_VARIATION 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50]
#define WATER_CUSTOM_R 0.15 // [0.00 0.05 0.10 0.15 0.20 0.30 0.40 0.50 0.70 1.00]
#define WATER_CUSTOM_G 0.55 // [0.00 0.10 0.20 0.30 0.40 0.55 0.70 0.85 1.00]
#define WATER_CUSTOM_B 0.85 // [0.00 0.10 0.20 0.30 0.50 0.70 0.85 1.00]

// ---- Rain & Wetness ----
#define RAIN_AMOUNT 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define RAIN_OPACITY 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define RAIN_WIND 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define RAIN_MIST 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define PUDDLE_COVERAGE 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50]
#define RIPPLE_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define SURFACE_DRYING 1.00 // [0.00 0.50 1.00 1.50 2.00]

// ---- Nether & End ----
#define NETHER_PALETTE 0 // [0 1 2 3]
#define NETHER_MOOD 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define NETHER_AMBIENT 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define NETHER_GLOW 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define NETHER_SPEED 1.00 // [0.00 0.25 0.50 1.00 1.50 2.00]
#define NETHER_SMOKE_DENSITY 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define NETHER_SMOKE_STEPS 12 // [6 8 12 16 24]
#define NETHER_HEAT 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define NETHER_EMBER_AMOUNT 1.00 // [0.00 0.25 0.50 1.00 1.50 2.00 3.00]

#define END_PALETTE 0 // [0 1 2 3]
#define END_SKY_INTENSITY 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define END_NEBULA 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define END_SKY_SPEED 1.00 // [0.00 0.25 0.50 1.00 1.50 2.00]
#define END_ECLIPSE_SIZE 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define END_LIGHT_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define END_MIST_DENSITY 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define END_MIST_STEPS 16 // [8 12 16 24 32]
#define END_MOTE_BRIGHTNESS 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]

// ---- Direct Lighting, PBR, GI, SSR, Shadows & Post ----
#define AMBIENT_STRENGTH 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define SHADOW_BLUENESS 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50]
#define AO_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50]
#define TORCH_BRIGHTNESS 1.00 // [0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00]
#define TORCH_WARMTH 1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define EMISSION_STRENGTH 2.20 // [0.50 1.00 1.50 2.20 3.00 4.50 6.00]
#define WAVING_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]

#define PBR_FORMAT 0 // [0 1]
#define NORMAL_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define POM_DEPTH 0.12 // [0.04 0.08 0.12 0.18 0.25]
#define POM_STEPS 32 // [8 16 32 64 128]
#define POM_DISTANCE 28.0 // [12.0 20.0 28.0 40.0 64.0]
#define GENERATED_NORMAL_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]

#define PT_RAYS 2 // [1 2 3 4 6 8]
#define PT_STEPS 16 // [8 12 16 24 32]
#define PT_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00]
#define RT_STEPS 32 // [12 16 24 32 48 64 128]

const int   shadowMapResolution = 2048; // [1024 2048 3072 4096 6144]
const float shadowDistance      = 192.0; // [64.0 96.0 128.0 160.0 192.0 256.0 320.0]
#define SHADOW_FILTER_SIZE 1.00 // [0.00 0.50 0.75 1.00 1.50 2.00]
#define SHADOW_SAMPLES 8 // [4 6 8 12 16]

#define BLOOM_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00 3.00]
#define BLOOM_RADIUS 1.00 // [0.50 0.75 1.00 1.50 2.00]
#define VIGNETTE_STRENGTH 1.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define SHARPEN 0.25 // [0.00 0.15 0.25 0.40 0.60 0.80 1.00]
#define CHROMATIC_ABERRATION 0.00 // [0.00 0.25 0.50 0.75 1.00 1.50 2.00]
#define FILM_GRAIN 0.000 // [0.000 0.005 0.010 0.015 0.025 0.040]

// ---- Iris Pipeline Directives ----
const float wetnessHalflife          = 180.0;
const float drynessHalflife          = 60.0;
const float eyeBrightnessHalflife    = 6.0;
const float centerDepthHalflife      = 1.0;
const float ambientOcclusionLevel    = 1.0;
const float shadowIntervalSize       = 2.0;
const float shadowDistanceRenderMul  = 1.0;
const float entityShadowDistanceMul  = 1.0;
const bool  generateShadowMipmap     = false;
const bool  shadowHardwareFiltering  = false;

#ifdef GI_HALF_RES
    #define GI_SCALE 0.5
#else
    #define GI_SCALE 1.0
#endif

#if defined POM && defined LABPBR && (defined TERRAIN || defined BLOCK)
    #define MIFJPN_POM
#endif

#if defined PHYSICS_MOD_SUPPORT && (defined PHYSICS_OCEAN_V3 || defined PHYSICS_OCEAN)
    #define MIFJPN_PHYSICS_OCEAN
#endif

#define PHYSICS_SNOW_ID 10999

const float MAT_NONE     = 0.0;
const float MAT_WATER    = 1.0;
const float MAT_GLASS    = 2.0;
const float MAT_PLANT    = 3.0;
const float MAT_EMISSIVE = 4.0;
const float MAT_METAL    = 5.0;
const float MAT_POLISHED = 6.0;
const float MAT_LAVA     = 7.0;
const float MAT_LEAVES   = 8.0;
const float MAT_SNOW     = 9.0;
const float MAT_ENTITY   = 10.0;
const float MAT_HAND     = 11.0;

const vec3 WATER_TAG = vec3(0.02, 0.49, 0.97);

// ---- Iris Option Registration (standalone #ifdef required by Iris parser) ----
#ifdef LABPBR
#endif
#ifdef POM
#endif
#ifdef DISTANT_RAIN
#endif
#ifdef RAIN_PUDDLES
#endif
#ifdef NETHER_LAVA
#endif
#ifdef PHYSICS_MOD_SUPPORT
#endif
#ifdef END_SHADOWS
#endif
#ifdef END_MOTES
#endif
#ifdef SHADOW_DEBUG
#endif

#endif

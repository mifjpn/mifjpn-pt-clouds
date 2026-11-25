// Mifjpn-PT | Distant Horizons Far Opaque Terrain G-Buffer Writer
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"
#include "/lib/wetness.glsl"

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
    vMatID       = MAT_NONE;

#ifdef DISTANT_HORIZONS
    if      (dhMaterialId == DH_BLOCK_LEAVES)      vMatID = MAT_LEAVES;
    else if (dhMaterialId == DH_BLOCK_SNOW)        vMatID = MAT_SNOW;
    else if (dhMaterialId == DH_BLOCK_LAVA)        vMatID = MAT_LAVA;
    else if (dhMaterialId == DH_BLOCK_ILLUMINATED) vMatID = MAT_EMISSIVE;
    else if (dhMaterialId == DH_BLOCK_WATER)       vMatID = MAT_WATER;
    gl_Position = dhProjection * viewPos;
#else
    gl_Position = gl_ProjectionMatrix * viewPos;
#endif
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,2,6,14 */
void main() {
    if (length(vRelPos.xz) < far - 16.0) discard;

    float matCode  = floor(vMatID + 0.5);
    vec3  viewN    = normalize(vViewNormal);
    vec3  worldPos = vRelPos + cameraPosition;
    vec2  lm       = vec2(vLightMap.x, max(vLightMap.y, 0.94));

    vec3  albedo = vColor.rgb;
    float micro  = hash13(floor(worldPos * 4.0 + 0.001));
    albedo *= 0.90 + 0.20 * micro * (1.0 - 0.5 * luma(albedo));

    float smoothness = 0.0, f0Code = 0.02, emission = 0.0, sssAmt = 0.0;
    if      (matCode == MAT_SNOW)     { smoothness = 0.18; f0Code = 0.04; }
    else if (matCode == MAT_EMISSIVE) { emission = 0.80; }
    else if (matCode == MAT_LEAVES)   { sssAmt = 0.40; }
    else if (matCode == MAT_LAVA)     { emission = 1.00; }

#if defined NETHER && defined NETHER_LAVA
    if (matCode == MAT_LAVA) {
        vec4 crust = netherLava(worldPos, (mat3(gbufferModelViewInverse) * viewN).y, 0.5, 1.0);
        albedo   = crust.rgb;
        emission = crust.a;
    }
#endif

#if defined RAIN_PUDDLES && !defined NETHER && !defined END
    if (wetness > 0.002 && matCode != MAT_LEAVES && matCode != MAT_EMISSIVE && matCode != MAT_LAVA && matCode != MAT_SNOW) {
        WetSurface wetInfo = evalWetSurface(worldPos, mat3(gbufferModelViewInverse) * viewN, lm.y, pixelFootprint(length(vRelPos)));
        albedo     = pow(albedo, vec3(1.0 + 0.6 * wetInfo.wet));
        smoothness = mix(smoothness, 0.55, max(wetInfo.wet * 0.6, wetInfo.puddle));
    }
#endif

    gl_FragData[0] = vec4(albedo, 1.0);
    gl_FragData[1] = vec4(encodeNormal(viewN), lm);
    gl_FragData[2] = vec4(smoothness, f0Code, emission, 1.0);
    gl_FragData[3] = vec4(1.0, matCode / 255.0, sssAmt, 1.0);
    gl_FragData[4] = vec4(albedo, 1.0);
}
#endif

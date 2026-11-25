// Mifjpn-PT | Deferred Pass 1: Variance-Guided Temporal GI Accumulation
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/space.glsl"
#include "/lib/gi.glsl"

varying vec2 texcoord;

#ifdef VSH
void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    texcoord    = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;

const float HISTORY_CAP = 28.0;

/* DRAWBUFFERS:47 */
void main() {
    vec2 giCoord  = floor(gl_FragCoord.xy);
    vec2 bufRes   = giRes();
    vec2 giUV     = (giCoord + 0.5) / bufRes;
    vec2 screenUV = giSampleUV(giCoord);

    float rawZ = texture2D(depthtex0, screenUV).r;
    if (rawZ >= 1.0 || rawZ < 0.56) {
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3  viewPos   = screenToView(vec3(screenUV, rawZ));
    float currDepth = -viewPos.z;
    vec3  currGI    = texture2D(colortex3, giUV).rgb;

#ifdef PT_DENOISER
    vec2 invRes  = 1.0 / bufRes;
    vec3 moment1 = vec3(0.0);
    vec3 moment2 = vec3(0.0);
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            vec3 s = texture2D(colortex3, saturate(giUV + vec2(float(dx), float(dy)) * invRes)).rgb;
            moment1 += s;
            moment2 += s * s;
        }
    }
    moment1 *= (1.0 / 9.0);
    vec3 stdDev = sqrt(max(moment2 * (1.0 / 9.0) - moment1 * moment1, vec3(0.0)));

    vec3 prevRelPos = viewToPlayer(viewPos) + (cameraPosition - previousCameraPosition);
    vec4 prevView   = gbufferPreviousModelView * vec4(prevRelPos, 1.0);
    vec4 prevClip   = gbufferPreviousProjection * prevView;
    vec2 prevUV     = (prevClip.xy / max(abs(prevClip.w), 1e-5)) * 0.5 + 0.5;
    float prevZRef  = -prevView.z;

    vec2 texPos   = prevUV * bufRes - 0.5;
    vec2 baseCell = floor(texPos);
    vec2 fracUV   = texPos - baseCell;

    vec3  histRGB = vec3(0.0);
    float histLen = 0.0;
    float wTotal  = 0.0;
    float zTol    = prevZRef * 0.05 + 0.06;

    for (int tap = 0; tap < 4; ++tap) {
        vec2 offset = vec2(mod(float(tap), 2.0), floor(float(tap) * 0.5));
        vec2 cell   = baseCell + offset;
        if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= bufRes.x || cell.y >= bufRes.y) continue;

        vec2  tapUV   = (cell + 0.5) / bufRes;
        vec4  prevDat = texture2D(colortex4, tapUV);
        float wx      = offset.x > 0.5 ? fracUV.x : (1.0 - fracUV.x);
        float wy      = offset.y > 0.5 ? fracUV.y : (1.0 - fracUV.y);
        float w       = wx * wy * step(abs(prevDat.a - prevZRef), zTol) * step(1e-4, prevDat.a);

        histRGB += prevDat.rgb * w;
        histLen += texture2D(colortex7, tapUV).r * w;
        wTotal  += w;
    }

    vec3  outGI  = currGI;
    float frames = 1.0;
    if (wTotal > 0.05) {
        histRGB /= wTotal;
        frames   = min((histLen / wTotal) * 255.0 + 1.0, HISTORY_CAP);
        vec3 boxRadius = stdDev * 4.0 + 0.01;
        histRGB = clamp(histRGB, moment1 - boxRadius, moment1 + boxRadius);

        float lumDrift = abs(luma(histRGB) - luma(moment1));
        float lumScale = luma(stdDev) * (1.0 / 3.0) + 0.05 * luma(moment1) + 1e-3;
        float reject   = saturate((lumDrift / lumScale - 1.5) * 0.4);
        frames = max(1.0, frames * (1.0 - reject * 0.95));
        outGI  = mix(histRGB, currGI, 1.0 / frames);
    }

    gl_FragData[0] = vec4(finiteColor(outGI), currDepth);
    gl_FragData[1] = vec4(frames / 255.0, 0.0, 0.0, 1.0);
#else
    gl_FragData[0] = vec4(finiteColor(currGI), currDepth);
    gl_FragData[1] = vec4(1.0 / 255.0, 0.0, 0.0, 1.0);
#endif
}
#endif

// Mifjpn-PT | Final Display Pass: Edge AA, Halo-Free Sharpen, Grain & Dither
// SPDX-License-Identifier: MIT

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/clouds.glsl"

varying vec2 texcoord;

#ifdef VSH
void main() {
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    texcoord    = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FSH
uniform sampler2D colortex0;
uniform sampler2D colortex11;
#ifdef SHADOW_DEBUG
uniform sampler2D shadowtex0;
#endif

vec3  sampleDisplay(vec2 uv)   { return texture2D(colortex0, uv).rgb; }
float perceptualLuma(vec3 sdr) { return dot(sdr, vec3(0.299, 0.587, 0.114)); }

#if defined VOLUMETRIC_CLOUDS && defined CLOUD_INTERACTION && !defined NETHER && !defined END
vec2 applyCloudImpulseUV(vec2 baseUV) {
    vec2  imp     = texture2D(colortex11, vec2(0.5)).rg;
    float elapsed = frameTimeCounter - imp.x;
    if (elapsed < 0.0) elapsed += 3600.0;

    float kick   = elapsed < 3.0 ? imp.y * exp(-elapsed * 1.818) : 0.0;
    float nowT   = frameTimeCounter;
    float inBank = smoothstep(0.05, 0.35, cloudDensity(cameraPosition, 1.0));
    float roll   = (0.045 * kick * sin(elapsed * 8.0 + 0.6) + 0.006 * inBank * sin(nowT * 1.3) * sin(nowT * 0.47 + 1.0)) * CLOUD_JOLT;
    vec2  jitter = (vec2(noise2D(vec2(nowT * 23.0, 1.0)), noise2D(vec2(3.0, nowT * 21.0))) - 0.5) * (0.006 * abs(kick) * CLOUD_JOLT);

    float aspect = viewWidth / max(viewHeight, 1.0);
    float margin = 1.0 + abs(roll) * (aspect + 1.0) * 0.55 + length(jitter) * 2.0;
    vec2  p      = (baseUV - 0.5) * vec2(aspect, 1.0) / margin;
    float s = sin(roll), c = cos(roll);
    vec2  rot    = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
    return clamp(rot / vec2(aspect, 1.0) + 0.5 + jitter, 0.001, 0.999);
}
#endif

void main() {
    vec2 uv = texcoord;
#if defined VOLUMETRIC_CLOUDS && defined CLOUD_INTERACTION && !defined NETHER && !defined END
    uv = applyCloudImpulseUV(texcoord);
#endif

    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec3 colC  = sampleDisplay(uv);

#ifdef FXAA
    vec3 colN = sampleDisplay(uv + vec2(0.0, texel.y));
    vec3 colS = sampleDisplay(uv - vec2(0.0, texel.y));
    vec3 colE = sampleDisplay(uv + vec2(texel.x, 0.0));
    vec3 colW = sampleDisplay(uv - vec2(texel.x, 0.0));

    float yC = perceptualLuma(colC), yN = perceptualLuma(colN), yS = perceptualLuma(colS), yE = perceptualLuma(colE), yW = perceptualLuma(colW);
    float yMin   = min(yC, min(min(yN, yS), min(yE, yW)));
    float yMax   = max(yC, max(max(yN, yS), max(yE, yW)));
    float yRange = yMax - yMin;

    if (yRange > max(0.045, yMax * 0.125)) {
        float yNE = perceptualLuma(sampleDisplay(uv + texel));
        float yNW = perceptualLuma(sampleDisplay(uv + vec2(-texel.x,  texel.y)));
        float ySE = perceptualLuma(sampleDisplay(uv + vec2( texel.x, -texel.y)));
        float ySW = perceptualLuma(sampleDisplay(uv - texel));

        float gradH   = abs(yNW + yNE - 2.0 * yN) + 2.0 * abs(yW + yE - 2.0 * yC) + abs(ySW + ySE - 2.0 * yS);
        float gradV   = abs(yNW + ySW - 2.0 * yW) + 2.0 * abs(yN + yS - 2.0 * yC) + abs(yNE + ySE - 2.0 * yE);
        bool  isHoriz = (gradH >= gradV);

        float sideNeg = isHoriz ? yS : yW;
        float sidePos = isHoriz ? yN : yE;
        bool  useNeg  = abs(sideNeg - yC) >= abs(sidePos - yC);

        vec2 normalStep  = (isHoriz ? vec2(0.0, texel.y) : vec2(texel.x, 0.0)) * (useNeg ? -1.0 : 1.0);
        vec2 tangentStep = isHoriz ? vec2(texel.x, 0.0) : vec2(0.0, texel.y);

        float yMean  = (2.0 * (yN + yS + yE + yW) + yNE + yNW + ySE + ySW) * (1.0 / 12.0);
        float subPix = smoothstep(0.0, 1.0, saturate(abs(yMean - yC) / yRange));
        subPix       = subPix * subPix * 0.75;

        float yPair     = 0.5 * (yC + (useNeg ? sideNeg : sidePos));
        float edgeThres = 0.25 * abs((useNeg ? sideNeg : sidePos) - yC);
        vec2  midUV     = uv + normalStep * 0.5;

        float distP = 0.0, distN = 0.0;
        for (int s = 1; s <= 6; ++s) {
            float fs = float(s);
            if (distP == 0.0 && abs(perceptualLuma(sampleDisplay(midUV + tangentStep * fs)) - yPair) >= edgeThres) distP = fs;
            if (distN == 0.0 && abs(perceptualLuma(sampleDisplay(midUV - tangentStep * fs)) - yPair) >= edgeThres) distN = fs;
        }
        if (distP == 0.0) distP = 7.0;
        if (distN == 0.0) distN = 7.0;

        float minSpan = min(distP, distN);
        float endY    = (distP < distN) ? perceptualLuma(sampleDisplay(midUV + tangentStep * distP)) : perceptualLuma(sampleDisplay(midUV - tangentStep * distN));
        float spanShift = (((yC - yPair) < 0.0) != ((endY - yPair) < 0.0)) ? (0.5 - minSpan / (distP + distN)) : 0.0;
        colC = sampleDisplay(uv + normalStep * max(spanShift, subPix));
    }
#endif

    if (SHARPEN > 0.0) {
        vec3 sN = sampleDisplay(uv + vec2(0.0, texel.y));
        vec3 sS = sampleDisplay(uv - vec2(0.0, texel.y));
        vec3 sE = sampleDisplay(uv + vec2(texel.x, 0.0));
        vec3 sW = sampleDisplay(uv - vec2(texel.x, 0.0));
        vec3 crossAvg = (sN + sS + sE + sW) * 0.25;
        vec3 nMin = min(colC, min(min(sN, sS), min(sE, sW))) - 0.03;
        vec3 nMax = max(colC, max(max(sN, sS), max(sE, sW))) + 0.03;
        colC = saturate(clamp(colC + (colC - crossAvg) * (SHARPEN * 2.0), nMin, nMax));
    }

    if (FILM_GRAIN > 0.0) {
        float grain = hash12(gl_FragCoord.xy + mod(float(frameCounter), 61.0) * 17.3) - 0.5;
        colC += grain * FILM_GRAIN * (1.0 - perceptualLuma(colC) * 0.6);
    }

    colC += (ign(gl_FragCoord.xy, 0.0) - 0.5) * (1.0 / 255.0);
    #ifdef SHADOW_DEBUG
    if (texcoord.x < 0.28 && texcoord.y > 0.72) {
        vec2 dbgUV = vec2(texcoord.x / 0.28, (texcoord.y - 0.72) / 0.28);
        float shD  = texture2D(shadowtex0, dbgUV).r;
        vec3  vis  = shD < 0.9999 ? vec3(fract(shD * 16.0), shD, 1.0 - shD) : vec3(0.12, 0.02, 0.02);
        gl_FragData[0] = vec4(vis, 1.0);
        return;
    }
#endif
    gl_FragData[0] = vec4(saturate(colC), 1.0);
}
#endif

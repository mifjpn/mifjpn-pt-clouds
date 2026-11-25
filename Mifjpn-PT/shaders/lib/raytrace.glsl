// Mifjpn-PT | View-Space Screen-Space Ray Traversal
// SPDX-License-Identifier: MIT
#ifndef MIFJPN_PT_RAYTRACE_GLSL
#define MIFJPN_PT_RAYTRACE_GLSL

bool rayTrace(
    sampler2D depthTex,
    vec3 origin,
    vec3 dir,
    float initialStep,
    float stepGrowth,
    float jitter,
    int maxSteps,
    out vec2 hitUV
) {
    hitUV = vec2(0.0);
    float dt = initialStep;
    vec3 prevPos = origin;
    vec3 currPos = origin + dir * (dt * clamp(jitter, 0.05, 0.99));
    bool nearOrigin = (-origin.z > 0.75);

    for (int stepIdx = 0; stepIdx < maxSteps; ++stepIdx) {
        if (currPos.z > -near) return false;

        vec3 proj = viewToScreen(currPos);
        if (proj.x < 0.0 || proj.x > 1.0 || proj.y < 0.0 || proj.y > 1.0) return false;

        float rawDepth = texture2D(depthTex, proj.xy).r;
        if (rawDepth > 0.56) {
            float surfDepth = linearDepth(rawDepth);
            float rayDepth  = -currPos.z;
            float pen       = rayDepth - surfDepth;
            float thickness = max(dt * 2.4, 0.24 + rayDepth * 0.02);

            if ((!nearOrigin || surfDepth >= 0.65) && pen > 0.0 && pen < thickness) {
                vec3 lo = prevPos;
                vec3 hi = currPos;
                for (int r = 0; r < 5; ++r) {
                    vec3 mid = (lo + hi) * 0.5;
                    vec3 midScr = viewToScreen(mid);
                    if (-mid.z > linearDepth(texture2D(depthTex, midScr.xy).r)) hi = mid;
                    else lo = mid;
                }
                hitUV = viewToScreen(hi).xy;
                return true;
            }
        }
        prevPos = currPos;
        currPos += dir * dt;
        dt *= stepGrowth;
    }
    return false;
}

#endif

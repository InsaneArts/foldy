// Projection and darkening adapted from DuoLikeAnimation; the blur pyramid follows Lid Plane's approach.
// Copyright (c) 2026 Elijah Semyonov. MIT. See ThirdPartyNotices.md.
#include <metal_stdlib>
using namespace metal;

// Four float4 vectors; layout matches FoldUniforms.swift exactly.
struct FoldUniforms {
    float4 geometry;  // width, height, angle, eye distance
    float4 optics;    // blur spread, darkening per point of blur radius, right hinge, reveal
    float4 output;    // transition mode, signed vertical angle, page-turn choreography, ripple
    float4 viewpoint; // eye x and y over the pane in points, material index, ripple phase
};

// Materials; keep in step with FoldAppearance.materialIndex.
constant int kFrosted = 0;
constant int kClear = 1;
constant int kGrain = 2;
constant int kGloss = 3;
constant int kInk = 4;
constant int kMidnight = 5;

struct RasterVertex {
    float4 position [[position]];
    float2 uv;
};
// One pane of frosted glass rotated away from the content plane.
struct Pane {
    float2 size;
    float angle;      // horizontal tilt in radians, hinged left or right
    float pitch;      // signed vertical tilt in radians; positive keeps the top edge fixed
    bool hingeRight;
    float eyeDistance;
    float2 eye;       // where the viewer's eye sits over the pane, in points
    float blurSpread;
    float darkening;
    int material;
    float ripple;     // liquid wobble amount, 0 to 1
    float phase;      // where the wobble is along its travel
};

vertex RasterVertex foldVertex(uint id [[vertex_id]]) {
    const float2 uv = float2((id << 1) & 2, id & 2);
    return { float4(uv.x * 2 - 1, 1 - uv.y * 2, 0, 1), uv };
}

static half4 sampleContent(texture2d<half> content, float2 uv) {
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_zero, filter::linear);
    return content.sample(linearSampler, uv);
}

// The renderer softens each mip level so that level L is a Gaussian of about 2^L source pixels.
// One trilinear tap therefore replaces a sparse disc: no speckle, no per-pixel loop.
static half4 sampleBlurred(texture2d<half> content, float2 uv, float sigmaPixels) {
    constexpr sampler blurSampler(coord::normalized, address::clamp_to_zero,
                                  filter::linear, mip_filter::linear);
    float lod = log2(max(sigmaPixels, 1.0));
    return content.sample(blurSampler, uv, level(lod));
}

static Pane makePane(constant FoldUniforms &u) {
    Pane pane;
    pane.size = u.geometry.xy;
    pane.angle = u.geometry.z;
    pane.pitch = u.output.y;
    pane.hingeRight = u.optics.z > 0.5;
    pane.eyeDistance = u.geometry.w;
    pane.eye = u.viewpoint.xy;
    pane.blurSpread = u.optics.x;
    pane.darkening = u.optics.y;
    pane.material = int(u.viewpoint.z + 0.5);
    pane.ripple = u.output.w;
    pane.phase = u.viewpoint.w;
    return pane;
}

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

// Material finish applied after projection and blur. `gap` is the glass-to-plane separation at this
// pixel, `slope` is the sine of the local tilt, `p` the pixel in points, `hit` the sampled point.
static half4 finish(half4 color, Pane pane, float gap, float slope, float2 p, float2 hit) {
    float2 size = pane.size;
    switch (pane.material) {
    case kGrain: {
        // Sanded glass: fine grain that thickens with the gap, on the color only.
        float grain = hash21(floor(p * 1.5)) - 0.5;
        half amount = half(clamp(gap / size.x, 0.0, 1.0)) * 0.22h;
        color.rgb *= 1.0h + half(grain) * amount;
        return color;
    }
    case kGloss: {
        // Polished glass: a soft highlight band that sweeps across the pane with the tilt.
        float along = pane.hingeRight ? (size.x - p.x) / size.x : p.x / size.x;
        float band = exp(-pow((along - slope) * 4.0, 2.0));
        half sheen = half(band * slope) * 0.55h;
        color.rgb = color.rgb * (1.0h - sheen) + sheen * color.a;
        return color;
    }
    case kInk: {
        // Ink on paper: a shadow bleeds outward from the crease, deepest along the hinge.
        float hinge = pane.hingeRight ? size.x : 0;
        float d = abs(p.x - hinge) / size.x;
        half shadow = half(exp(-d * 6.0) * slope) * 0.6h;
        color.rgb *= 1.0h - shadow;
        return color;
    }
    case kMidnight: {
        // Cool, dark diffusion.
        half t = half(clamp(gap / size.x, 0.0, 1.0));
        color.rgb = color.rgb * (1.0h - 0.35h * t) + half3(0.02h, 0.03h, 0.08h) * t * color.a;
        return color;
    }
    default:
        return color;
    }
}

static half4 frosted(float2 uv, texture2d<half> content, Pane pane) {
    float2 size = pane.size;
    float angle = pane.angle;
    float pitch = abs(pane.pitch);
    if (angle < 0.00001 && pitch < 0.00001) return sampleContent(content, uv);
    float hinge = pane.hingeRight ? size.x : 0;
    float side = pane.hingeRight ? -1 : 1;
    float2 p = uv * size;
    float d = abs(p.x - hinge);
    float3 glass = float3(hinge + side * d * cos(angle), p.y, d * sin(angle));
    // Rotate the pane around its top or bottom edge after the horizontal fold.
    // With zero pitch this is exactly the original single-axis projection.
    float hingeY = pane.pitch >= 0 ? 0 : size.y;
    float sideY = pane.pitch >= 0 ? 1 : -1;
    float dy = abs(p.y - hingeY);
    float horizontalGap = glass.z;
    glass.y = hingeY + sideY * (dy * cos(pitch) - horizontalGap * sin(pitch));
    glass.z = dy * sin(pitch) + horizontalGap * cos(pitch);
    float3 eye = float3(pane.eye, pane.eyeDistance);
    float depth = eye.z - glass.z;
    if (depth <= 0.001) return half4(0);
    float2 hit = eye.xy + (glass.xy - eye.xy) * (eye.z / depth);
    if (pane.ripple > 0.0) {
        // Liquid glass: two crossed waves displace the sampled point, growing with the lift so the
        // hinge stays still while the free edge wobbles. The phase moves with the fold itself.
        float lift = clamp(glass.z / size.x, 0.0, 1.0);
        float amp = pane.ripple * size.x * 0.045 * lift;
        hit.x += amp * sin(p.y / size.y * 12.0 + pane.phase);
        hit.y += amp * 0.6 * cos(p.x / size.x * 9.0 - pane.phase * 1.3);
    }
    float radius = pane.blurSpread * glass.z;
    if (any(hit < -radius) || any(hit > size + radius)) return half4(0);
    // Frosted glass also absorbs: dim in proportion to how much it scatters.
    half attenuation = half(max(1.0 - pane.darkening * radius, 0.0));
    // A disc of radius r has the spread of a Gaussian with sigma r / 2.
    float pixelsPerPoint = float(content.get_width()) / size.x;
    half4 color = radius < 0.5
        ? sampleContent(content, hit / size)
        : sampleBlurred(content, hit / size, 0.5 * radius * pixelsPerPoint);
    // Preserve premultiplied alpha. Missing rays remain transparent.
    color.rgb *= attenuation;
    return finish(color, pane, glass.z, sin(max(angle, pitch)), p, hit);
}

fragment half4 foldFragment(RasterVertex in [[stage_in]],
                           texture2d<half> source [[texture(0)]],
                           texture2d<half> destination [[texture(1)]],
                           constant FoldUniforms &u [[buffer(0)]]) {
    Pane front = makePane(u);
    half4 pane = frosted(in.uv, source, front);
    if (u.output.x < 0.5) return pane;
    float reveal = u.optics.w;
    half4 behind;
    if (u.output.z > 0.5) {
        // Page turn: the destination unfolds around the same hinge as the source folds away,
        // so both panes share one geometry at the midpoint and the hinge edge stays sharp throughout.
        Pane back = front;
        back.angle = M_PI_2_F - front.angle;
        behind = frosted(in.uv, destination, back);
        pane *= half(1 - smoothstep(0.3f, 0.7f, reveal));
    } else {
        // The original demo models a single tilted pane. This fade completes the screen handoff.
        behind = sampleContent(destination, in.uv);
        pane *= half(1 - smoothstep(0.15f, 1.0f, reveal));
    }
    return pane + behind * (1 - pane.a);
}

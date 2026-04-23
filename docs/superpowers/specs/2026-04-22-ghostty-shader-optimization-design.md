# Ghostty Shader GPU Optimization Design

**Date**: 2026-04-22
**Status**: Draft
**Target hardware**: Mac Mini M4 Pro (integrated GPU)

## Problem

Two Ghostty custom shaders (`inside-the-matrix.glsl` and `cursor_blaze.glsl`) consume excessive GPU when run together, causing high GPU usage visible in Activity Monitor even when idle.

## Goals

- Reduce GPU usage by ~50-60% when both shaders are active
- Moderate visual fidelity trade-off is acceptable (fewer deep rain columns, simpler rune glyphs)
- Preserve the overall matrix rain aesthetic and cursor trail effect

## Approach: Combined Surgical Cuts + Targeted Early Exits

Cherry-pick the highest-impact optimizations from two strategies: reducing raw computation, and skipping work when the result is invisible.

---

## Section 1: `inside-the-matrix.glsl` — Iteration & Loop Reduction

### 1a. Cut `ITERATIONS` from 40 to 22

The outer raymarching loop walks through xy-cells. At iteration 22+, distance attenuation (`1. + pow(0.06*tmin/t3_to_t2, 2.)`) already dims columns to near-invisible. Cutting here removes ~45% of the main loop work.

**Visual impact**: Far background rain draw distance slightly shorter.

### 1b. Reduce rune strokes from 4 to 3

Each rune character draws 4 line segments in `rune()`. Dropping to 3 saves 25% of the inner loop cost. Glyphs are tiny on screen and randomness masks the simplification.

Implementation: Change `i < 4` to `i < 3`, remove the `if (i == 3)` branch. Adjust remaining branches so that strokes 0, 1, 2 still touch 3 edges of the bounding box.

### 1c. Reduce z-cell inner loop from 2 to 1

The `for (int j=0; j<2)` loop checks two vertical cells per column. With the mostly-horizontal camera angle, 1 iteration is sufficient. This halves work inside each outer iteration.

**Combined effect for Section 1**: ~60% reduction in `rain()` computation (0.55 × 0.75 × 0.5 ≈ 0.21 of original cost).

---

## Section 2: `inside-the-matrix.glsl` — Cheaper Hashing

### 2a. Replace `sin()`-based hashes with algebraic hashes

Current pattern:
```glsl
return fract(sin(v) * 43758.5453123);
```

Replace with cheaper algebraic approach. For scalar:
```glsl
float hash(float v) {
    return fract(v * 0.7548776662 + v * v * 0.4237987837);
}
```

For vector variants (`hash(vec2)`, `hash2`, `hash4`), replace `sin()` with `fract()` of dot-product combinations using different constant vectors per component, preserving each function's input/output signature. The key change is eliminating `sin()` — the specific constants don't matter as long as they produce well-distributed pseudo-random output.

**Visual impact**: Rain patterns will be "differently random" but equally random-looking.

### 2b. Precompute constant snap vector

In `rune()`, `vec4 snaps = vec4(2, 3, 2, 3)` is constructed every iteration. Hoist to a file-level `const`.

**Estimated savings**: ~15-20% additional reduction on top of Section 1.

---

## Section 3: `inside-the-matrix.glsl` — Early Exit & Skip Logic

### 3a. Lower alpha accumulation bail-out from 0.98 to 0.90

The last 10% of alpha blending is imperceptible. Lowering the threshold lets us stop raymarching sooner once a pixel is mostly opaque.

### 3b. Skip rain computation for terminal text pixels

Sample the terminal texture at the start of `mainImage()` and skip `rain()` entirely when the pixel has bright terminal text:

```glsl
vec4 terminalColor = texture(iChannel0, uv);
float textBrightness = dot(terminalColor.rgb, vec3(0.299, 0.587, 0.114));
if (textBrightness > 0.4) {
    fragColor = terminalColor;
    return;
}
```

**Estimated savings**: Content-dependent. A busy terminal skips 40-60% of pixels entirely.

**Visual impact**: Rain won't shimmer behind text, but the current shader already masks text over rain, so composited output is nearly identical.

---

## Section 4: `cursor_blaze.glsl` — Cleanup & Early Exit

### 4a. Remove duplicate SDF function

`sdBox` and `getSdfRectangle` are identical. Remove `sdBox` (unused).

### 4b. Replace `pow(1.0 - x, 10.0)` with repeated squaring

```glsl
float ease(float x) {
    float t = 1.0 - x;
    float t2 = t * t;
    float t4 = t2 * t2;
    float t8 = t4 * t4;
    return t8 * t2;  // t^10
}
```

~5 multiplications instead of a transcendental `pow()` call.

### 4c. Precompute constant in `antialising()`

`normalize(vec2(2., 2.), 0.).x` equals `4.0 / iResolution.y` — a per-frame constant. Compute once at the top of `mainImage()` and inline.

### 4d. Time-based early exit

When cursor hasn't moved recently (`iTime - iTimeCursorChange > DURATION`), skip all trail computation. Cursor blaze costs zero GPU when cursor is idle. This check must be placed **after** the texture read (so `fragColor` retains the terminal content) but **before** any trail math:

```glsl
#if !defined(WEB)
fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
#endif
float elapsed = iTime - iTimeCursorChange;
if (elapsed > DURATION) return;
```

**Combined savings for cursor_blaze**: Effectively zero GPU when idle, ~30% cheaper when active.

---

## Summary of Expected Impact

| Optimization | GPU Savings | Visual Impact |
|---|---|---|
| Iteration reduction (1a-1c) | ~60% of rain() | Slightly shorter draw distance, simpler glyphs |
| Cheaper hashing (2a-2b) | ~15-20% additional | Different random patterns, equally random |
| Early exits (3a-3b) | 40-60% pixels skipped (content-dependent) | Imperceptible |
| Cursor blaze cleanup (4a-4d) | Near-zero when idle | None |

**Overall**: ~50-60% GPU reduction when both shaders are active together.

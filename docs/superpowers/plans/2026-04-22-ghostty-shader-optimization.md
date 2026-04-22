# Ghostty Shader GPU Optimization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce GPU usage ~50-60% for the two Ghostty custom shaders (`inside-the-matrix.glsl` and `cursor_blaze.glsl`) running together on an M4 Pro Mac Mini.

**Architecture:** Apply three optimization strategies — reduce iteration/loop counts, replace expensive `sin()`-based hashing with cheaper algebraic alternatives, and add early-exit paths to skip invisible work. Each change is independent and revertible.

**Tech Stack:** GLSL (Ghostty custom shader API), Nix (home-manager module)

---

## File Structure

- **Modify:** `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl` — all matrix rain optimizations (Sections 1-3 of spec)
- **Modify:** `modules/home-manager/common/ghostty/shaders/cursor_blaze.glsl` — all cursor trail optimizations (Section 4 of spec)
- **Modify:** `modules/home-manager/common/ghostty/default.nix` — enable both shaders together

---

### Task 1: Reduce iteration counts in `inside-the-matrix.glsl`

**Files:**
- Modify: `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl:10`
- Modify: `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl:75`
- Modify: `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl:156`

- [ ] **Step 1: Cut main raymarching iterations from 40 to 22**

In `inside-the-matrix.glsl`, change line 10:

```glsl
// before
const int ITERATIONS = 40;   //use less value if you need more performance

// after
const int ITERATIONS = 22;   //use less value if you need more performance
```

- [ ] **Step 2: Reduce rune strokes from 4 to 3**

In `inside-the-matrix.glsl`, replace the `rune()` function (lines 72-93):

```glsl
float rune(vec2 U, vec2 seed, float highlight)
{
	float d = 1e5;
	for (int i = 0; i < 3; i++)	// number of strokes (reduced from 4)
	{
            vec4 pos = hash4(seed);
            seed += 1.;

            // each rune touches the edge of its box on 3 sides
            if (i == 0) pos.y = .0;
            if (i == 1) pos.x = .999;
            if (i == 2) pos.x = .0;
            // snap the random line endpoints to a grid 2x3
            vec4 snaps = vec4(2, 3, 2, 3);
            pos = ( floor(pos * snaps) + .5) / snaps;

            if (pos.xy != pos.zw)  //filter out single points (when start and end are the same)
                d = min(d, rune_line(U, pos.xy, pos.zw + .001) ); // closest line
	}
	return smoothstep(0.1, 0., d) + highlight*smoothstep(0.4, 0., d);
}
```

Note: `snaps` will be hoisted to a file-level `const RUNE_SNAPS` in Task 2 Step 2.

- [ ] **Step 3: Reduce z-cell inner loop from 2 to 1**

In `inside-the-matrix.glsl`, change line 156:

```glsl
// before
for (int j=0; j<2; j++) {  //2 iterations is enough if camera doesn't look much up or down

// after
{  // single z-cell check (camera angle is mostly horizontal)
    int j = 0;
```

Keep the closing `}` and the `zcell += cell_shift.z;` line at the end — remove only the for-loop construct but keep the body running once. Remove the `zcell += cell_shift.z;` line (line 200) and its comment (line 199) since they're no longer needed without the loop.

- [ ] **Step 4: Verify the shader compiles by checking Ghostty loads without errors**

Open Ghostty on nixmini. The matrix rain should render with slightly fewer visible deep-background columns and marginally simpler glyphs. No error screen (red).

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl
git commit -m "perf(shaders): reduce iteration counts in matrix rain shader"
```

---

### Task 2: Replace `sin()`-based hashing with cheaper algebraic hashes

**Files:**
- Modify: `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl:28-60`
- Modify: `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl:72` (rune snaps const)

- [ ] **Step 1: Replace all hash functions**

Replace lines 28-60 (the entire `// ---- random ----` section) with:

```glsl
//        ----  random  ----

float hash(float v) {
    return fract(v * 0.7548776662 + v * v * 0.4237987837);
}

float hash(vec2 v) {
    return hash(dot(v, vec2(5.3983, 5.4427)));
}

vec2 hash2(vec2 v)
{
    return fract(vec2(
        dot(v, vec2(127.1, 311.7)),
        dot(v, vec2(269.5, 183.3))
    ) * 0.7548776662 + dot(v, v) * vec2(0.4237987837, 0.3914756201));
}

vec4 hash4(vec2 v)
{
    return fract(vec4(
        dot(v, vec2(127.1, 311.7)),
        dot(v, vec2(269.5, 183.3)),
        dot(v, vec2(113.5, 271.9)),
        dot(v, vec2(246.1, 124.6))
    ) * 0.7548776662 + dot(v, v) * vec4(0.4237987837, 0.3914756201, 0.4831942539, 0.3683495187));
}

vec4 hash4(vec3 v)
{
    return fract(vec4(
        dot(v, vec3(127.1, 311.7, 74.7)),
        dot(v, vec3(269.5, 183.3, 246.1)),
        dot(v, vec3(113.5, 271.9, 124.6)),
        dot(v, vec3(271.9, 269.5, 311.7))
    ) * 0.7548776662 + dot(v, v) * vec4(0.4237987837, 0.3914756201, 0.4831942539, 0.3683495187));
}
```

- [ ] **Step 2: Hoist rune snap vector to file-level const**

Add this constant near the top of the file, after the existing constants block (after line 26, the `const float PI` line):

```glsl
const vec4 RUNE_SNAPS = vec4(2, 3, 2, 3);
```

Then in `rune()`, replace:
```glsl
vec4 snaps = vec4(2, 3, 2, 3);
pos = ( floor(pos * snaps) + .5) / snaps;
```
with:
```glsl
pos = ( floor(pos * RUNE_SNAPS) + .5) / RUNE_SNAPS;
```

- [ ] **Step 3: Verify visually**

Open Ghostty. Rain should still look random and matrix-like, just with a different random pattern than before.

- [ ] **Step 4: Commit**

```bash
git add modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl
git commit -m "perf(shaders): replace sin()-based hashing with cheaper algebraic hashes"
```

---

### Task 3: Add early exit and skip logic in `inside-the-matrix.glsl`

**Files:**
- Modify: `modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl` — `rain()` and `mainImage()` functions

- [ ] **Step 1: Lower alpha bail-out threshold from 0.98 to 0.90**

In the `rain()` function, find:

```glsl
if (result.a > 0.98)
    return result.xyz;
```

Change to:

```glsl
if (result.a > 0.90)
    return result.xyz;
```

- [ ] **Step 2: Add text-pixel skip in `mainImage()`**

In `mainImage()`, the current code samples the terminal texture and computes the mask near the end (lines 399-408). Restructure so the texture sample and text check happen early. Replace the `mainImage()` function starting from line 247 (`vec2 uv = fragCoord.xy / iResolution.xy;`) through to the end of the function with:

```glsl
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Early out: skip rain computation for pixels occupied by terminal text
    vec4 terminalColor = texture(iChannel0, uv);
    float textBrightness = dot(terminalColor.rgb, vec3(0.299, 0.587, 0.114));
    if (textBrightness > 0.4) {
        fragColor = terminalColor;
        return;
    }

    float time = mod(iTime, 300) * SPEED; //reset time every 5 minutes, as large values lead to the same (and eventually no) rune(s)
```

Keep the rest of `mainImage()` (camera logic, `rain()` call) unchanged, except update the final compositing block. Replace lines 395-408:

```glsl
    vec3 col = rain(ro, rd, time) * 0.25;

    // Combine the matrix effect with the terminal color
    float mask = 1.2 - step(0.5, dot(terminalColor.rgb, vec3(1.0)));
    vec3 blendedColor = mix(terminalColor.rgb * 1.2, col, mask);

    fragColor = vec4(blendedColor, terminalColor.a);
```

The `terminalColor` variable is now already available from the early sample — remove the duplicate `vec4 terminalColor = texture(iChannel0, uv);` that was previously at line 399.

- [ ] **Step 3: Verify visually**

Open Ghostty with text content visible. Rain should only render in background gaps. Text areas should show terminal content directly without rain shimmer behind them.

- [ ] **Step 4: Commit**

```bash
git add modules/home-manager/common/ghostty/shaders/inside-the-matrix.glsl
git commit -m "perf(shaders): add early exit for text pixels and lower alpha bail-out"
```

---

### Task 4: Clean up and optimize `cursor_blaze.glsl`

**Files:**
- Modify: `modules/home-manager/common/ghostty/shaders/cursor_blaze.glsl`

- [ ] **Step 1: Remove duplicate `sdBox` function**

Delete lines 6-10 (the entire `sdBox` function):

```glsl
// delete this:
float sdBox(in vec2 p, in vec2 xy, in vec2 b)
{
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
```

- [ ] **Step 2: Replace `pow()` in `ease()` with repeated squaring**

Replace the `ease()` function (lines 2-4):

```glsl
// before
float ease(float x) {
    return pow(1.0 - x, 10.0);
}

// after
float ease(float x) {
    float t = 1.0 - x;
    float t2 = t * t;
    float t4 = t2 * t2;
    float t8 = t4 * t4;
    return t8 * t2;  // t^10
}
```

- [ ] **Step 3: Precompute the `antialising()` constant**

Replace the `antialising()` function (line 55-57):

```glsl
// before
float antialising(float distance) {
    return 1. - smoothstep(0., normalize(vec2(2., 2.), 0.).x, distance);
}

// after
float antialising(float distance, float aaWidth) {
    return 1. - smoothstep(0., aaWidth, distance);
}
```

Then in `mainImage()`, after the texture read and before the trail computation, compute the constant:

```glsl
float aaWidth = 4.0 / iResolution.y;
```

And update the call site (line 138) from:

```glsl
newColor = mix(newColor, TRAIL_COLOR, antialising(sdfTrail));
```

to:

```glsl
newColor = mix(newColor, TRAIL_COLOR, antialising(sdfTrail, aaWidth));
```

- [ ] **Step 4: Add time-based early exit**

In `mainImage()`, immediately after the existing texture read (line 89-91), add:

```glsl
#if !defined(WEB)
fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
#endif
// Early exit: trail has fully faded, skip all computation
float elapsed = iTime - iTimeCursorChange;
if (elapsed > DURATION) return;
```

This replaces the existing texture read — don't duplicate it. The early exit goes right after.

- [ ] **Step 5: Verify visually**

Open Ghostty with cursor_blaze enabled. Move cursor — trail should still render. Stop moving — GPU usage should drop as the shader early-exits.

- [ ] **Step 6: Commit**

```bash
git add modules/home-manager/common/ghostty/shaders/cursor_blaze.glsl
git commit -m "perf(shaders): optimize cursor blaze with early exit, cheaper math"
```

---

### Task 5: Enable both shaders and final verification

**Files:**
- Modify: `modules/home-manager/common/ghostty/default.nix:26-29`

- [ ] **Step 1: Uncomment cursor_blaze in the Ghostty config**

In `modules/home-manager/common/ghostty/default.nix`, change lines 26-29:

```nix
# before
        custom-shader = [
          "${./shaders/inside-the-matrix.glsl}"
          # "${./shaders/cursor_blaze.glsl}"
        ];

# after
        custom-shader = [
          "${./shaders/inside-the-matrix.glsl}"
          "${./shaders/cursor_blaze.glsl}"
        ];
```

- [ ] **Step 2: Deploy and verify on nixmini**

Rebuild the system config (`nix run .#rebuild`  or equivalent). Open Ghostty and verify:
1. Matrix rain renders in background
2. Cursor trail renders when moving cursor
3. Both effects work together without visual artifacts
4. Check Activity Monitor — GPU usage should be noticeably lower than before optimization

- [ ] **Step 3: Commit**

```bash
git add modules/home-manager/common/ghostty/default.nix
git commit -m "feat(ghostty): enable both shaders together after GPU optimization"
```

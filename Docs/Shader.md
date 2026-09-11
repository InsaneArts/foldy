# How the shader works

Foldy draws every frame with one Metal fragment function, `foldFragment` in `Sources/Foldy/Shaders/Fold.metal`.
This page explains it in graphics terms. No prior Metal knowledge is assumed beyond "a fragment function runs once per pixel."

## The model: stationary interface, moving glass

The interface never moves. It lives on a fixed plane in space, the plane the screen occupied before any tilt.
The viewer never moves either. Their eye sits on that plane's normal through the pane's center, 320 mm away, which is 1920 points at 6 points per millimetre.
Only the glass moves. The pane rotates around one of its edges, the hinge, and the rest of it lifts toward the eye.

For each output pixel the shader answers one question: if this pixel is a point on the tilted glass, which point of the interface does the eye see through it?

## Step 1: place the pixel on the glass

The pixel's position `p` is converted to points. Its distance from the hinge along the pane is `d`.
Rotating around a vertical hinge by `angle` puts the pixel at:

```
x = hinge ± d · cos(angle)
y = p.y
z = d · sin(angle)          // the gap between glass and interface
```

A vertical tilt, `pitch`, rotates the result again around the top or bottom edge. With zero pitch this is exactly the single-axis projection of the reference demo.

## Step 2: cast a ray to the interface

The eye is at `(eye.x, eye.y, eyeDistance)`. A line from the eye through the glass point continues until it meets the interface plane at `z = 0`:

```
t   = eyeDistance / (eyeDistance − z)
hit = eye.xy + (glass.xy − eye.xy) · t
```

`hit` is the interface point this pixel shows. Near the hinge `z` is small and `hit ≈ p`, so the image is undistorted. Far from the hinge the glass is closer to the eye, so the interface appears magnified and shifted. Rays that leave the interface return transparent.

`eye.xy` is `FoldStyle.viewpoint`. Two panes that share one eye project consistently, which is how the Duo demo folds a display in half.

## Step 2b: liquid ripple

With `FoldStyle.ripple` above zero, the hit point is displaced by two crossed sine waves before sampling:

```
amp   = ripple · width · 0.045 · lift        // lift = z / width, so the hinge never moves
hit.x += amp · sin(12 · p.y / height + phase)
hit.y += 0.6 · amp · cos(9 · p.x / width − 1.3 · phase)
```

`phase` is nine times the tilt in radians, so the wobble travels with the fold instead of a clock and is reproducible frame to frame.

## Step 3: blur and darken by the gap

Frosted glass scatters light in proportion to the distance it is from what you look at. The blur radius is:

```
radius = blur · z        // FoldStyle.blur, points of radius per point of gap
```

and the light lost is `darkening · radius`. Both are zero at the hinge and grow across the pane.

The blur itself does not sample a disc. At capture time the renderer builds a mip pyramid of each snapshot and softens every level with a small Gaussian, so level `L` is a blur of roughly `2^L` source pixels. The shader then takes one trilinear sample at `lod = log2(radius)`. One texture read replaces up to 32, with no speckle, and the blurred edge of the snapshot fades out instead of ending in a hard cut. This approach follows Lid Plane; see the notices.

## Step 4: composite two views

A single-view tilt returns the pane and stops. A transition also samples the destination.

With `.reveal`, the destination is drawn flat underneath and the pane fades out over the last part of the fold.

With `.pageTurn`, the destination is projected as a second pane around the same hinge, rotated by `90° − angle`, so at the midpoint both panes stand at 45° and the hinge stays sharp. The source fades across the middle of the fold.

Compositing is premultiplied: `pane + behind · (1 − pane.alpha)`. Transparent snapshots stay transparent, so cards and overlays fold without a black surround.

## Step 5: finish by material

`FoldAppearance` chooses a finish applied after blur and darkening:

| Material | What it adds |
| --- | --- |
| frosted | Nothing beyond the blur and darkening above |
| clear | Zero blur and darkening; pure projection |
| grain | A per-pixel hash of the position that thickens with the gap |
| gloss | A Gaussian band across the pane whose position follows `sin(tilt)`, like a highlight sweeping across |
| ink | A shadow, `exp(−6 · d)`, bleeding outward from the hinge |
| midnight | Cool, dark diffusion mixed in by the gap |

Every material is invisible at rest.

## Uniforms

The shader takes four `float4` vectors, 64 bytes, laid out identically in `FoldUniforms.swift`:

| Vector | x | y | z | w |
| --- | --- | --- | --- | --- |
| geometry | width | height | angle | eye distance |
| optics | blur | darkening | hinge is right | reveal progress |
| output | is transition | signed pitch | is page turn | unused |
| viewpoint | eye x | eye y | material | unused |

All values are clamped on the CPU before upload, and the eye is kept beyond the farthest point the pane can reach, so the projection never divides by zero.

## Frame pacing

Nothing is drawn at rest. During a fold the renderer draws once per display refresh on a `CADisplayLink` with at most two frames in flight, and presents each drawable with the Core Animation transaction that changes the live views, so no frame is ever uncovered.

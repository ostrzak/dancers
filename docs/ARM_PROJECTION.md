# Top-down arm projection

The dancers use a deliberately simplified 3D-to-2D arm model. Anatomical
segment lengths stay constant, while only their top-down projections are drawn.
This makes shoulder adduction and elbow flexion readable without lighting,
shadows, or a second 3D character rig.

## Pose parameter

`Dancer.get_arm_flexion()` produces a normalized pose value `t`:

- `t = 0`: arm released and maximally abducted;
- `t = 1`: arm fully adducted and flexed.

The trigger moves continuously between these endpoints.

Both anatomical arm segments and their pose-control distance were reduced to
70% of the original prototype values. Projection angles, hand size, and the
duration of the arm transition remain unchanged.

## Upper arm

The upper arm stays radial in screen space. Its projected length is:

`upper_projection = upper_arm_length * sin(abduction_angle)`

Abduction moves from 84 degrees to 0 degrees. At full adduction the projection
therefore reaches zero, the elbow overlaps the shoulder, and the remaining
joint is drawn as a hand-sized shoulder cap.

## Forearm

Shoulder motion reorients the elbow hinge while the elbow flexes. The forearm's
effective out-of-plane angle moves continuously from 0 degrees to 80 degrees:

`forearm_projection = forearm_length * cos(out_of_plane_angle)`

Cosine projection makes shortening subtle near the released pose and
increasingly strong toward full adduction. The in-plane elbow direction still
folds through the dancer's dorsal side. At the endpoint, the short projected
forearm places each hand over the pectoral on the same side of the body; hands
do not cross the centreline.

## Gameplay authority

The projected hand position is used consistently for drawing, hand catches,
constraint forces, hand velocity, and effective rotational inertia. Presentation
and gameplay therefore agree about where the visible hand is.

The relevant tuning properties are `minimum_abduction_degrees`,
`maximum_abduction_degrees`, `minimum_elbow_flexion_degrees`,
`maximum_elbow_flexion_degrees`, `minimum_forearm_out_of_plane_degrees`, and
`maximum_forearm_out_of_plane_degrees`.

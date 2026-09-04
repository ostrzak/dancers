# Top-down arm projection

The dancers use a deliberately simplified 3D-to-2D arm model. Anatomical
segment lengths stay constant, while only their top-down projections are drawn.
This makes shoulder adduction and elbow flexion readable without lighting,
shadows, or a second 3D character rig.

The dancers are upright humans viewed from directly overhead, not bodies lying
in the floor plane. Each head occludes the torso's full centre and the torso
stays within the head's front-to-rear footprint. Only a short neck, shoulders,
and compact clothing edges remain visible around it. A small nose marks local
forward on the corrected side. The black man's head remains solid black, with
angular tuxedo shoulders. The white woman uses a filled rear hair cap and side
locks, long hair draped over rounded shoulders, restrained bodice lobes, and
three shallow rear dress ruffles within a normal human footprint.

These man and woman silhouettes are visual puppets over one identical
mechanical skeleton. Both dancers inherit the same shoulder spacing, upper-arm
and forearm lengths, arm-length range, projection limits, hand size, and torso
collider. `body_style`, names, and colours distinguish the dancers without
changing hand reach or the geometry presented to the handhold solver.

## Pose parameter

`Dancer.get_arm_flexion(side)` produces a normalized pose value `t` for one
arm:

- `t = 0`: arm released and maximally abducted;
- `t = 1`: arm fully adducted and flexed.

LT moves the left arm continuously between these endpoints; RT independently
moves the right arm.

## Extended stance

Each controller's D-pad adjusts the fully extended pose of both arms on that
dancer. Left and right narrow or widen the stance by changing the baseline
elbow flexion. Up and down sweep both arm chains forward or backward relative to
the nose. Holding a direction adjusts continuously at 40 degrees per second.
The authored neutral stance begins 25 degrees forward, giving two facing dancers
a useful ballroom frame before either trigger is pressed.

The limits are anatomical rather than cosmetic: extended elbow flexion stays
between 5 and 55 degrees, forward sweep stays between 25 degrees rearward and
45 degrees forward, and the chosen extrema cannot cross a hand over the body's
centreline. Each trigger independently fades the selected stance as that arm
adducts and flexes. At full trigger the forward sweep is zero and the existing
145-degree tucked elbow endpoint remains authoritative.

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
increasingly strong toward full adduction. The approved in-plane elbow bend is
unchanged by the corrected nose and RS axis. At the endpoint, the short
projected forearm places each hand over the pectoral on the same side of the
body; hands do not cross the centreline.

## Gameplay authority

The projected hand position is used consistently for drawing, hand catches,
constraint forces, hand velocity, and effective rotational inertia. Presentation
and gameplay therefore agree about where the visible hand is.

The relevant tuning properties are `minimum_abduction_degrees`,
`maximum_abduction_degrees`, `extended_elbow_flexion_degrees`,
`extended_forward_sweep_degrees`, `maximum_elbow_flexion_degrees`,
`minimum_forearm_out_of_plane_degrees`, and
`maximum_forearm_out_of_plane_degrees`. Extended-stance minimums, maximums, and
adjustment rate are exported separately.

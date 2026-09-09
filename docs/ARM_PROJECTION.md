# Top-down arm projection

The dancers use a deliberately simplified 3D-to-2D arm model. Anatomical
segment lengths stay constant, while only their top-down projections are drawn.
This makes shoulder adduction and elbow flexion readable without lighting,
shadows, or a second 3D character rig.

The dancers are upright humans viewed from directly overhead, not bodies lying
in the floor plane. Each head occludes the upper torso's centre. A rounded belly
becomes visible forward of the head as weight rises in 5 kg bands, rather than
stretching the entire body into a frontal silhouette. A short neck, shoulders,
and clothing edges remain visible around the head. A small nose marks local
forward on the corrected side. The black man's head remains solid black, with
angular tuxedo shoulders. The white woman uses a filled rear hair cap and side
locks, long hair draped over rounded shoulders, restrained bodice lobes, and
three shallow rear dress ruffles within a normal human footprint.

## Pose parameter

`Dancer.get_arm_flexion(side)` produces a normalized pose value `t` for one
arm:

- `t = 0`: arm released and maximally abducted;
- `t = 1`: arm fully adducted and flexed.

LT moves the left arm continuously between these endpoints; RT independently
moves the right arm.

## Extended stance

Each controller's D-pad adjusts the trigger-released pose of both arms. Left
adducts the shoulders; right abducts them. Up sweeps the arms forward (shoulder
flexion); down sweeps them backward (extension) relative to the dancer's nose.
Diagonals combine both axes at 40 degrees per second per axis. The neutral elbow
bend stays at its authored 12 degrees; the D-pad no longer tunes elbow flexion.

Each axis always requires both players to hold the same D-pad direction,
whether apart or in a single or double handhold.
An idle or opposing partner blocks that axis. For example, Up-Right plus Up
allows only forward sweep. The agreed angular change is identical on both
dancers and stops at either partner's limit. Existing pose differences are
preserved without a snap at catch time. This is a dancer-wide neutral pose, so
in a single hold the agreement also governs the free arm. Releasing the last
handhold keeps the same mutual-input requirement. Paused D-pad input only navigates menus.
The authored neutral stance begins 25 degrees forward, giving two facing dancers
a useful ballroom frame before either trigger is pressed.

Neutral abduction ranges from 0 to 84 degrees; forward sweep stays between
25 degrees rearward and 45 degrees forward. Each trigger independently fades
the selected stance as that arm
adducts and flexes. At full trigger the forward sweep is zero and the existing
145-degree tucked elbow endpoint remains authoritative.

Both anatomical arm segments and their pose-control distance were reduced to
70% of the original prototype values. Projection angles, hand size, and the
duration of the arm transition remain unchanged.

## Upper arm

The upper arm stays radial in screen space. Its projected length is:

`upper_projection = upper_arm_length * sin(abduction_angle)`

Abduction moves from the D-pad-selected neutral angle (84 degrees by default)
to 0 degrees. At full adduction the projection
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

Arms are drawn as tapered, rounded upper-arm and forearm segments with a thin
contrasting outline and a short cuff mark when there is room. Both segment
outlines are drawn before their fills, avoiding an elbow seam. At zero projected
length, round caps remain valid without a degenerate polygon. Drawing uses the
existing shoulder, elbow, and hand coordinates through every trigger and D-pad
pose; the artwork does not change physical reach. The torso alone uses the
weight-dependent clothing scale and rounded belly contour documented in `TUNING.md`.

Hands use rounded palm silhouettes with a narrow wrist and a small mirrored thumb
bump. Their direction follows the forearm. A visual axial roll blends normalized
shoulder adduction and elbow flexion equally: the extended pose shows the back,
the intermediate pose is edge-on, and the tucked pose shows the palm. D-pad
adduction also contributes. This is an authored pose coupling, not an anatomical
constraint or a new physical wrist joint. Projected palm width follows cosine
of roll, with a 2 px half-thickness at edge-on and a faint crease on the palm face.
The thumb crosses sides continuously rather than flipping instantly. The
grip point remains at the palm centre; catch distances and connection markers are
unchanged. Individual fingers are omitted for readability at gameplay scale.

The projected hand position is used consistently for drawing, hand catches,
constraint forces, hand velocity, and effective rotational inertia. Presentation
and gameplay therefore agree about where the visible hand is.

The relevant tuning properties are `minimum_abduction_degrees`,
`maximum_abduction_degrees`, `extended_elbow_flexion_degrees`,
`extended_forward_sweep_degrees`, `maximum_elbow_flexion_degrees`,
`minimum_forearm_out_of_plane_degrees`, and
`maximum_forearm_out_of_plane_degrees`. Extended-stance minimums, maximums, and
adjustment rate are exported separately.

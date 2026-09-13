# Top-down arm projection

The dancers use a deliberately simplified 3D-to-2D arm model. Anatomical segment
lengths stay constant while only their top-down projections are drawn. This
makes shoulder adduction and elbow flexion readable without lighting, shadows,
or a 3D character rig.

The dancers are upright humans viewed from directly overhead. Each head occludes
the torso centre; only a short neck, shoulders, and compact clothing edges remain
visible around it. The black dancer uses the man silhouette and the white dancer
uses the woman silhouette.

## Independent arm model

Each dancer stores and solves its left and right arm independently.
Dancer.get_arm_flexion(side) produces a normalized pose value for one arm:

- 0: released and maximally abducted;
- 1: fully adducted and flexed.

In the single-controller layout, LT sends one contraction value to both black
arms and RT sends another value to both white arms. The arm code remains
side-specific: each hand has its own pose value, projected chain, velocity,
catch point, and inertia contribution. The current control routing deliberately
moves the two arms of one dancer together.

## Shared extended stance

The D-pad adjusts the fully extended pose of both arms on both dancers.
Left/right narrows or widens the stance by changing baseline elbow flexion;
up/down sweeps the chains backward or forward relative to each dancer's nose.
Holding a direction adjusts continuously at 40 degrees per second. Both dancers
receive the same bounded delta on each axis: either dancer reaching its limit
stops that axis for both, preserving any existing difference between their poses.
The single controller supplies this shared input directly.

The authored neutral stance begins 25 degrees forward. Extended elbow flexion is
limited to 5â€“55 degrees and sweep to 25 degrees rearward through 45 degrees
forward. The extrema cannot cross either hand over its dancer's centreline.
Trigger contraction fades out the extended-stance influence so the authored
145-degree tucked endpoint remains authoritative.

## Projection

The upper-arm projection is:

upper_projection = upper_arm_length * sin(abduction_angle)

Abduction moves from 84 degrees to 0 degrees. At full adduction, the elbow
overlaps the shoulder and the remaining joint becomes a compact hand-sized cap.

The forearm projection is:

forearm_projection = forearm_length * cos(out_of_plane_angle)

The out-of-plane angle moves from 0 to 80 degrees. Cosine projection keeps
shortening subtle near release and increasingly visible near full contraction.
At the endpoint, each hand finishes over the pectoral on the same side of the
body rather than crossing the centreline.

The D-pad forward sweep rotates the upper-arm direction before the elbow bend is
applied. Left and right chains remain mirrored around each dancer's body axis.

## Gameplay authority

The projected hand position is authoritative for drawing, catches, joint
constraints, hand velocity, and effective rotational inertia. Presentation and
gameplay therefore agree about where every visible hand is.

Relevant tuning properties include minimum_abduction_degrees,
maximum_abduction_degrees, extended_elbow_flexion_degrees,
extended_forward_sweep_degrees, maximum_elbow_flexion_degrees,
minimum_forearm_out_of_plane_degrees, and
maximum_forearm_out_of_plane_degrees.

## Artwork migration

Tapered outlined arms, cuffs, rounded palms with mirrored thumbs, updated torso
contours and clothing, and the man's white forelock come from the current co-op
artwork, including its uncommitted visual refinements. Appearance uses a fixed
slim silhouette; there are no weight or fit-weight controls in this variant.
Palm roll follows achieved shoulder adduction and elbow flexion up to 120 degrees.

Drawing uses the existing physical hand positions. Body mass, inertia calculation,
12 px torso colliders, and each dancer's existing shoulder spacing and arm lengths
are unchanged. Co-op's common skeleton and 20 px colliders are not migrated.

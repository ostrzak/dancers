# Runtime tuning

The pause menu has `GENERAL`, `TUNING`, and `DANCERS` tabs. While paused, LB and RB switch
tabs, directional input changes focus or a selected slider, A activates buttons,
and B returns to play. Tuning is session-local and starts from the authored
defaults whenever the project starts.

## Controls

- **Turn speed** multiplies both the extended and tucked maximum facing speeds.
- **Move speed** multiplies movement force and the input-speed ceiling.
- **Arm / move ratio** controls how strongly the faster tucked-arm state also
  boosts movement. Both arms contribute through their average flexion, so one
  tucked arm gives an intermediate benefit.
- **Trigger sensitivity** changes the response curve shared by LT and RT on
  both controllers.
- **Stick sensitivity** changes LS response. RS uses linear post-deadzone
  travel so its engagement thresholds stay consistent when this slider changes.

During unpaused play, D-pad Left/Right adducts/abducts the shoulders and Up/Down
sweeps both arms forward/backward. Diagonals combine the two axes; neutral elbow
bend stays fixed. Whether apart or holding one or two hands, each axis requires
matching directions from both players and advances
both poses by the same amount, stopping at either partner's limit. Releasing the
last handhold keeps the mutual-input requirement. Settings are session-local.
While paused, the D-pad remains exclusively menu navigation.

The released-arm default is 25 degrees forward. This places a natural two-hand
frame outside the torso colliders instead of making both constraints
pull the dancers toward the same body space.

Sensitivity uses `output = input ^ (1 / sensitivity)`. A value of one is linear,
higher values respond earlier, and lower values provide finer low-input control.
Zero and full input remain unchanged.

## Dancer weight

`DANCERS` provides independent 1 kg sliders: man 70–100 kg (default 85), woman
50–70 kg (default 60). They update while paused and remain session-local.
Both use the same conversion: `mass = 1.2 * weight_kg / 75`. Thus a 100 kg dancer
has twice the physical mass of a 50 kg dancer; each kilogram affects forces,
impulses, collision response, and the existing inverse-mass handhold correction.
The old tuning corresponds to the common 75 kg reference, rather than giving
different kilograms the same physical mass for each sex.

Effective torso-plus-arm inertia is multiplied by `weight_kg / 75`, using the
existing projected arm positions. Movement forces and speed ceilings remain
unchanged, so heavier dancers accelerate less under the same force. RS remains
the existing kinematic heading control: its acceleration and braking are scaled
by `75 / weight_kg`, while heading targets, radial response, and speed ceilings
retain their previous meaning. This is a weight-sensitive control ramp, not a
new torque motor. Physical partner-induced rotation uses the actual inertia.

Appearance advances at each 5 kg threshold (64 kg uses the 60 kg silhouette).
Shoulder/clothing width ranges from 88% to 112% and depth from 92% to 108% across
each sex's range. A separate rounded abdomen contour grows from a 13 px to 24 px
half-width and reaches 14–26 px forward of the body origin, making the belly
visible beyond the head and nose at higher weights. The belly forms the continuous
front edge of the jacket/dress; it is not just a wider shoulder silhouette.

Both torso collision circles are now a fixed 20 px radius (previously 12 px),
leaving physical space for the fuller bodies. Radius does not change with weight.
Head size, shoulder anchors, and anatomical arm lengths remain unchanged.
The belly can overhang the circle by 6 px at maximum weight; larger circles
conflict with fully tucked handholds. The added artwork does not alter the
established weight/inertia formula.

## Turn consistency at walls

Dancer collision friction is zero. Arena walls can stop translation but do not
apply tangential friction that grabs a spinning dancer and changes angular speed.
RS requests a screen-space heading beyond 0.15 processed travel (about 29% raw)
and releases below 0.08 (about 23% raw). Stick direction is the heading; stick
radius controls how quickly the dancer corrects toward it. A full outer-ring
circle still produces a continuous full dancer rotation.

At full travel and the 75 kg reference, the response uses 80 rad/s² acceleration, 240 rad/s² braking,
and arm-dependent 8–12 rad/s ceiling. Toward the inner threshold, a smooth radial
curve scales all three down to an 8% minimum, preserving the same human-inertia
shape while making small corrections deliberately slow. `facing_response_rate =
40` is scaled with the same curve. Full rotations are therefore outer-ring
gestures; partial travel is for fine heading correction. Reversing the requested
heading brakes the old motion before changing direction. Holding RS still settles
onto that heading; centering cancels the correction immediately.

RS applies controlled rotation without erasing physical angular velocity. A
partner can still rotate the body after release. While RS is active, its requested
heading continues correcting against partner displacement. Legacy `spin_torque`
and `spin_response_gain` do not tune this response. This is an eased kinematic
control, not a torque motor.

## L3 and R3 physical locks

Holding L3 suppresses the LS motor and anchors position with configurable
stiffness, damping, and maximum force. Holding R3 suppresses the RS motor and
anchors orientation with configurable stiffness, damping, and maximum torque.
The two locks are independent and may be held together.

## Telemetry

Every capture records all five live tuning values plus both preferred and live
controller assignments. Applied movement force already includes move-speed and
arm-to-move scaling, so captures show the actual force used by gameplay.
`facing_dial` records engagement, radial response scale, applied controlled
rotation, and remaining heading error.
`target_angular_velocity` is the applied RS rate; `angular_velocity` describes
physics-driven spin. Configuration records the dial limits and easing values.
Each dancer sample also records exact kilograms, engine mass, and the 5 kg
visual band. Configuration includes the shared kilogram-to-mass reference.

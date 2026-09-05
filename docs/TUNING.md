# Runtime tuning

The pause menu has `GENERAL` and `TUNING` tabs. While paused, LB and RB switch
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

During unpaused play, each controller's D-pad changes only that dancer's
extended arm stance: left/right narrow or widen both arms and up/down sweep both
arms backward or forward. The setting is session-local like the tuning sliders.
While paused, the D-pad remains exclusively menu navigation.

The released-arm default is 25 degrees forward. This places a natural two-hand
frame outside the minimal torso colliders instead of making both constraints
pull the dancers toward the same body space.

Sensitivity uses `output = input ^ (1 / sensitivity)`. A value of one is linear,
higher values respond earlier, and lower values provide finer low-input control.
Zero and full input remain unchanged.

## Turn consistency at walls

Dancer collision friction is zero. Arena walls can stop translation but do not
apply tangential friction that grabs a spinning dancer and changes angular speed.
RS is a relative circular dial: engage beyond 0.55 processed travel (about 62%
raw travel), sweep clockwise/counterclockwise to turn, and release below 0.25
(about 37% raw). Entry captures the current stick angle without changing facing.
Stick radius controls engagement; circular movement controls the requested turn.

The dial eases in at 80 rad/s² and brakes at 240 rad/s². The existing Turn speed
slider scales the arm-dependent 8–12 rad/s ceiling. `facing_response_rate = 40`
controls how closely small remaining adjustments settle. Pending travel is
limited to `facing_dial_max_lag_degrees = 20`: excess travel is discarded, so
arbitrarily fast circles do not guarantee matching dancer turn counts. Reversing
discards the opposite backlog and brakes the old motion before changing direction.
Holding RS still finishes only the small remaining adjustment; centering cancels
it immediately. Ordinary gestures below these limits preserve their angular travel.

RS applies controlled rotation without erasing physical angular velocity. A
partner can still rotate the body, including after release; the 20° bound concerns
unfinished RS input, not displacement caused by the partner. Legacy `spin_torque`
and `spin_response_gain` do not tune this dial. This is an eased kinematic control,
not a torque motor.

## L3 and R3 physical locks

Holding L3 suppresses the LS motor and anchors position with configurable
stiffness, damping, and maximum force. Holding R3 suppresses the RS motor and
anchors orientation with configurable stiffness, damping, and maximum torque.
The two locks are independent and may be held together.

## Telemetry

Every capture records all five live tuning values plus both preferred and live
controller assignments. Applied movement force already includes move-speed and
arm-to-move scaling, so captures show the actual force used by gameplay.
`facing_dial` records engagement, applied gesture travel, and pending travel.
`target_angular_velocity` is the applied RS rate; `angular_velocity` describes
physics-driven spin. Configuration records the dial limits and easing values.

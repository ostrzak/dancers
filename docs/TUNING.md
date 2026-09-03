# Runtime tuning

The pause menu has `GENERAL` and `TUNING` tabs. While paused, LB and RB switch
tabs, directional input changes focus or a selected slider, A activates buttons,
and B returns to play. Tuning is session-local and starts from the authored
defaults whenever the project starts.

## Controls

- **Turn speed** multiplies the maximum kinematic rate used to approach the
  absolute RS angle. It does not add momentum or change the stick deadzone.
- **Move speed** multiplies movement force and the input-speed ceiling.
- **Arm / move ratio** controls how strongly the faster tucked-arm state also
  boosts movement. Both arms contribute through their average flexion, so one
  tucked arm gives an intermediate benefit.
- **Trigger sensitivity** changes the response curve shared by LT and RT on
  both controllers.
- **Stick sensitivity** changes post-deadzone LS magnitude. RS discards
  magnitude after the deadzone, so partial and full travel at one angle give the
  same facing target.

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
RS facing is kinematic rather than an acceleration motor. While active it moves
toward the absolute stick angle at the configured rate and writes no turn
torque. While neutral it applies no orientation correction, allowing the
handhold to guide rotation without a later return toward the old request.

## L3 and R3 physical locks

Pressing L3 toggles a position anchor that suppresses the LS motor and uses
configurable stiffness, damping, and maximum force. Pressing R3 toggles an
orientation anchor that suppresses the RS motor and uses configurable stiffness,
damping, and maximum torque. The two toggles are independent and may both be on.

## Telemetry

Every capture records all five live tuning values plus both preferred and live
controller assignments. Applied movement force already includes move-speed and
arm-to-move scaling, so captures show the actual force used by gameplay. Hold
telemetry additionally records the 27 px hard limit, the current single-hold
authorized length, mutual-dorsal blocking, compliance, solver mode, and hard
safety corrections.

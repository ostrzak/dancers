# Runtime tuning

The pause menu has GENERAL and TUNING tabs. While paused, LB and RB switch
tabs, directional input changes focus or a selected slider, A activates buttons,
and B returns to play. Tuning is session-local and resets to authored defaults
when the project starts.

## Controls

- Spin speed multiplies the trigger-generated target angular velocity. With the
  trigger released, the target is zero. Contracting the arms continuously raises
  it toward the configured maximum.
- Move speed multiplies movement force and the input-speed ceiling.
- Arm / move ratio controls how strongly faster contracted-arm states also
  boost movement.
- Trigger sensitivity changes the response curve shared by LT and RT.
- Stick sensitivity changes post-deadzone magnitude for LS and RS.

LT contracts both black-dancer arms and RT contracts both white-dancer arms.
The underlying arm geometry remains independently solved per side.
L3 reverses the black dancer's selected spin direction as a press toggle. R3
does the same for the white dancer. Releasing either stick button has no effect.

During unpaused play, the D-pad changes the extended stance of both dancers:
left/right narrows or widens all arm chains, while up/down sweeps them backward
or forward. The setting is session-local. While paused, the D-pad remains
exclusively menu navigation. During play, each axis applies the same bounded
delta to both dancers and stops when either reaches its limit. Face buttons do
not adjust the arm stance.

The released-arm default is 25 degrees forward. This gives the pair a useful
shared stance before either trigger is pressed.

Sensitivity uses output = input ^ (1 / sensitivity). A value of one is linear,
higher values respond earlier, and lower values provide finer low-input control.
Zero and full input remain unchanged.

## Turn consistency at walls

Dancer collision friction is zero. Arena walls can stop translation but do not
apply tangential friction that grabs a spinning dancer and changes angular
speed. Rotation remains torque-driven: while its trigger is applied, each dancer
accelerates toward its own selected target direction; releasing the trigger
brings the requested speed back to zero.

## Telemetry

Every capture records all five live tuning values and the single-controller
assignment. It also states the LS/RS, LT/RT, LB/RB, and L3/R3 ownership map. Applied
movement force already includes move-speed and arm-to-move scaling. Hold
telemetry records rigid-joint solver mode, the current acquisition-authorized
length, acquisition progress, and position/velocity constraint corrections.

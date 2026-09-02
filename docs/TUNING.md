# Runtime tuning

The pause menu has `GENERAL` and `TUNING` tabs. While paused, LB and RB switch
tabs, directional input changes focus or a selected slider, A activates buttons,
and B returns to play. Tuning is session-local and starts from the authored
defaults whenever the project starts.

## Controls

- **Spin speed** multiplies both the extended and tucked target angular speeds.
- **Move speed** multiplies movement force and the input-speed ceiling.
- **Spin / move ratio** controls how strongly the faster tucked spin state also
  boosts movement. At zero, spin posture does not affect travel speed. At one,
  movement follows the full ratio between the tucked and extended spin targets.
- **Trigger sensitivity** changes the response curve shared by LT and RT.
- **Stick sensitivity** changes the post-deadzone response curve shared by both
  movement sticks.

Sensitivity uses `output = input ^ (1 / sensitivity)`. A value of one is linear,
higher values respond earlier, and lower values provide finer low-input control.
Zero and full input remain unchanged.

## Spin consistency at walls

Dancer collision friction is zero. Arena walls can stop translation but do not
apply tangential friction that grabs a spinning dancer and changes angular speed.
The spin motor remains responsible for angular acceleration and reversal.

## Telemetry

Every capture records all five live tuning values in the controller
configuration. Applied movement force already includes move-speed and
spin-to-move scaling, so captures show the actual force used by gameplay.

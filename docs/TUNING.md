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
- **Stick sensitivity** changes the post-deadzone response curve shared by LS
  and RS on both controllers.

Sensitivity uses `output = input ^ (1 / sensitivity)`. A value of one is linear,
higher values respond earlier, and lower values provide finer low-input control.
Zero and full input remain unchanged.

## Turn consistency at walls

Dancer collision friction is zero. Arena walls can stop translation but do not
apply tangential friction that grabs a spinning dancer and changes angular speed.
The RS-facing motor remains responsible for angular acceleration and alignment.
It disengages while RS is neutral, allowing physical hand forces from the other
dancer to guide rotation.

## L3 and R3 physical locks

Holding L3 suppresses the LS motor and anchors position with configurable
stiffness, damping, and maximum force. Holding R3 suppresses the RS motor and
anchors orientation with configurable stiffness, damping, and maximum torque.
The two locks are independent and may be held together.

## Telemetry

Every capture records all five live tuning values plus both preferred and live
controller assignments. Applied movement force already includes move-speed and
arm-to-move scaling, so captures show the actual force used by gameplay.

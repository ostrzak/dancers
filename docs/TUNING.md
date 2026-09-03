# Runtime tuning

The pause menu has `GENERAL` and `TUNING` tabs. While paused, LB and RB switch
tabs, directional input changes focus or a selected slider, A activates buttons,
and B returns to play. Tuning is session-local and starts from the authored
defaults whenever the project starts.

## Controls

- **Trigger sensitivity** changes the response curve shared by LT and RT on
  both controllers.
- **Stick sensitivity** changes post-deadzone LS magnitude. RS discards
  magnitude after the deadzone, so partial and full travel at one angle give the
  same facing target.
- **Man weight** and **woman weight** set physical body weight from 40 to 150 kg
  in one-kilogram steps. Both default to 75 kg.

Seventy-five kilograms maps to the original body mass of 1.2. Mass and
rotational inertia scale proportionally, so a 100 kg partner yields half as far
as a 50 kg partner to the same hand-contact correction. Each dancer's own LS
force and physical lock authority scale with their weight, preserving the same
self-controlled acceleration. Weight therefore changes how readily a dancer is
moved by the partner, not how responsive their own controller feels. It does
not change visual body size.

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

Every capture records both sensitivity values, both kilogram weights, derived
mass and inertia, and both preferred and live controller assignments. Applied
movement force includes weight scaling, so captures show the actual force used
by gameplay. Hold telemetry additionally records the 27 px one-hand hard limit,
the current single-hold authorized length, mutual-dorsal blocking, compliance,
hybrid solver mode, rigid double-hold permissions and effort, and hard safety
corrections.

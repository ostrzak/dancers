# Runtime tuning

The title selects single-player or co-op. See [Play modes](PLAY_MODES.md) for
single-player controls and its additional spin/move tuning. The co-op-specific
heading and D-pad behavior below remains unchanged. Figures are co-op-only.

The pause menu has `GENERAL`, `TUNING`, `DANCERS`, and `FIGURES` tabs. While paused, LB and
RB switch tabs, directional input changes focus or a selected slider, A
activates buttons, and B returns to play. Settings are session-local and reset
to the authored defaults when the project starts.

## Sensitivity

The TUNING tab retains hybrid's two controls:

- **Trigger sensitivity** changes the LT and RT response curve on both controllers.
- **Stick sensitivity** changes post-deadzone LS magnitude. RS retains linear
  post-deadzone travel independently of this slider.

Sensitivity uses `output = input ^ (1 / sensitivity)`. One is linear, higher
values respond earlier, and lower values provide finer low-input control. Zero
and full input remain unchanged. The obsolete move/spin scale controls from
main are superseded by hybrid's tuning contract.

## Actual and fit weight

The DANCERS tab gives each dancer two independent settings:

- **Weight:** 40-120 kg in 1 kg steps; changes mass and rotational inertia.
- **Fit weight:** 40-120 kg in 5 kg steps; selects the reference for slim artwork.

Both settings default to 75 kg for both dancers. A dancer stays slim below or
at fit weight. Each complete 5 kg above fit advances the belly/clothing shape;
at +30 kg the largest shape is reached and further weight does not enlarge it.
For example, at fit 85 kg, actual weights 85-89 kg share the slim shape, 90 kg
adds the first increment, and 115-120 kg share the maximum belly.

Seventy-five kilograms maps to body mass 1.2. Mass and rotational inertia scale
proportionally for every kilogram. A 100 kg partner yields half as far as a
50 kg partner to the same translational hand-contact correction. Hybrid's own
LS force and physical lock authority also scale with weight, preserving the
same self-controlled acceleration. Fit weight affects none of these quantities.
Artwork bands never change the common skeleton or fixed 20 px body circles.

## Walking and partner carry

Free LS requests screen-space walking speed, with a proportional response of 22/s
and maximum ground force of 3000 at 75 kg (scaled with weight). Full-input speed
remains 360 px/s times the existing arm-dependent move scale. Neutral LS brakes
walking promptly. The separate partner-carry vector is built only by handhold
velocity impulses and is limited to motion the dancer actually has.

Connected LS retains the original 900 force at 75 kg, scaled with weight and arm
pose, and 2.2 linear damping plus the project's default damping. Neutral held LS
applies no walking force. Ground support blends between held and free movement
over 0.125 seconds. Free movement uses zero replacement damping and motor resistance.

Recorded carry decay is 3.5/s normally and 8/s in double holds; the decay rate
blends at 16/s on hold transitions. Carry affects free movement after release;
it does not replace the original held forces. Opposite LS actively consumes carry.
These authored parameters live in `dancer.gd`, not in the pause menu.

## Right-stick heading

The current RS mode is main's `radial_heading_response`. Stick direction sets
the screen-space heading. Radius scales correction speed, acceleration,
braking, and response from 8% minimum authority to full authority. Engagement
starts at 0.15 post-deadzone travel and releases at 0.08. Main's eased response
uses acceleration 80 rad/s², braking 240 rad/s², and response rate 40; RS
acceleration/braking scale by `75 / weight_kg`. The arm-dependent top turn rate
remains 8-12 rad/s. The heading response uses the same parameters while held.
RS-driven hand velocity contributes to the handhold, and both dancers remain
free to receive physical turning reactions unless explicitly rotation-locked.
There are no additional distance-dependent turn limits.

Light travel gives smooth correction; full travel corrects quickly and supports
continuous outer-ring circles. Overload uses the shortest heading error, with
no pending revolutions. Correction is added to body rotation; active RS and
release both preserve physical angular velocity from contacts and the partner.
Frictionless body contacts preserve turning at arena walls.

## D-pad and physical locks

During play, D-pad adjustment requires both controllers to hold the same
direction simultaneously, independently per axis, in free motion and all holds.
Agreed input applies the same bounded adjustment to both dancers' stances.
Left/right narrow or widen the arm frame through baseline elbow flexion;
up/down sweep it backward or forward. The neutral forward sweep is 25 degrees.
While paused the D-pad remains menu navigation.

In a double hold, D-pad and trigger changes stop where the connected arm frame
would require torso overlap. Reverse the input to move away from this boundary;
there is no accumulated blocked motion. This applies to both front and rear
holds. Release a hand before repositioning across a blocked front/rear transition.
Free and one-hand controls keep their full anatomical limits.

L3 toggles a position anchor, suppressing LS while leaving rotation free. R3
toggles an orientation anchor, suppressing RS while leaving translation free.
Both may be enabled. These retain hybrid's press-to-toggle behavior and weighted
physical lock authority.

## Telemetry

Version `dancers-coop-telemetry-v11` records weights, fit weights, visual excess
bands, derived mass/inertia, controller assignments, sensitivities, radial RS
state and authority, achieved hand roll, and rigid-joint acquisition/correction
metrics. Double holds include mutual flexion permissions and per-arm effort.
Additive fields record `partner_carry_velocity` and `free_movement_blend` (zero
when fully using held forces, one when fully using free movement). Configuration
identifies `movement_mode` as `original_hold_partner_carry` and records the free
response, carry decay, and original held force/damping parameters.
The additive `double_hold_pose_limited` field identifies a pose request stopped
by hand-span compatibility, torso clearance, or continuity of the connected frame.
Arm tint uses the difference between partners' requests with a 10% quiet zone
and a smooth fade into red. Matching full-tuck requests remain neutral even
when torso clearance limits the achieved pose. Raw request-minus-achieved
effort remains in telemetry alongside `request_mismatch`.
This identifies the combined behavior without relying on the checkout name.

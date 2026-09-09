# Runtime tuning

The pause menu has `GENERAL`, `TUNING`, and `DANCERS` tabs. While paused, LB and
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

## Right-stick heading

The current RS mode is main's `radial_heading_response`. Stick direction sets
the screen-space heading. Radius scales correction speed, acceleration,
braking, and response from 8% minimum authority to full authority. Engagement
starts at 0.15 post-deadzone travel and releases at 0.08. Main's eased response
uses acceleration 80 rad/s², braking 240 rad/s², and response rate 40; RS
acceleration/braking scale by `75 / weight_kg`. The arm-dependent top turn rate
remains 8-12 rad/s.

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

L3 toggles a position anchor, suppressing LS while leaving rotation free. R3
toggles an orientation anchor, suppressing RS while leaving translation free.
Both may be enabled. These retain hybrid's press-to-toggle behavior and weighted
physical lock authority.

## Telemetry

Version `dancers-coop-telemetry-v11` records weights, fit weights, visual excess
bands, derived mass/inertia, controller assignments, sensitivities, radial RS
state and authority, achieved hand roll, and rigid-joint acquisition/correction
metrics. Double holds include mutual flexion permissions and per-arm effort.
Arm tint uses the difference between partners' requests with a 10% quiet zone
and a smooth fade into red. Matching full-tuck requests remain neutral even
when torso clearance limits the achieved pose. Raw request-minus-achieved
effort remains in telemetry alongside `request_mismatch`.
This identifies the combined behavior without relying on the checkout name.

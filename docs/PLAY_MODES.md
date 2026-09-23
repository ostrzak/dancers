# Single player and co-op

The title offers **Single player** (one person controls both dancers) and
**Co-op** (one controller per dancer). Either choice starts a fresh session:
hands, momentum, locks, spin directions and telemetry are reset. Returning
from pause resumes the current session. Ballroom, music and runtime tuning
are shared; the separate `single` project is not required or modified.

## Single-player controls

- LS moves the black dancer; RS moves the white dancer.
- LT contracts both black arms and drives black spin. RT does the same for white.
- L3 reverses black spin; R3 reverses white spin. Defaults are opposite directions.
- D-pad adjusts the extended arm stance of both dancers, with shared limits.
- LB and RB each own the hand connection they create. Either may go first.
  Hold a free bumper to prime the nearest eligible free pair. Catching still
  requires reach, acceptable relative speed and expired endpoint cooldowns.
  Letting the bumper up keeps the catch latched; its next press releases only
  its own pair. The other bumper can catch the remaining free hands.
- The remaining connection keeps its bumper when another is released.
  A held catch/release never repeats. A rejected second catch requires a fresh
  press before trying again. Buttons held through menus must be released first.
- Keyboard fallback: WASD / arrows move; Shift / Enter contract and spin;
  Q / E operate the two connections. Spin reversal and D-pad stance use the pad.
- Start or Escape opens pause; the Controls tab contains the current controls.

The Tuning tab includes single-player spin speed, move speed, arm/move ratio,
and both input sensitivities. Single-player preserves its 12 px colliders,
woman-specific arm dimensions, 5 rad/s full-flexion spin target and torque-driven
spin braking. Weight and fit controls remain available, defaulting to 75 kg.

## Shared physics, distinct steering

Both modes use the co-op rigid handhold solver, including two simultaneous
connections, double-hold pose limits, collision clearance and catch cooldowns.
Impossible second-hand geometry releases only the newer connection.

Walking, held movement and partner-derived release carry use the current co-op
implementation. Releasing a hand changes neither dancer's linear nor angular
velocity. Free movement preserves a short coast received from a partner, and
opposite movement input brakes it. Single-player's rotational motor still
targets the speed requested by arm contraction, including braking toward zero
as the arms extend. Its physical angular velocity already contributes to hand
velocity; co-op's additional heading-dial velocity must not be added to it.

Single-player free walking uses 65% of the walking-speed target (234 px/s
with extended arms at default tuning). This does not scale held forces,
held speed limits, spin, or the carry received from a partner.

Rear two-hand catches use the same collision-safe acquisition fit. For unequal
arm spans, acquisition also checks past the rear-arm span maximum, where
flexing begins to narrow the span. This avoids rejecting reachable rear holds
because the local fit stalled; it still rejects incompatible geometry and
never switches partners through each other into a front hold.

In single-player two-hand holds, the fit adjusts both arms of each dancer
together, matching the shared trigger control. Co-op keeps independent arms.
Compatibility flexion does not request spin: single-player spin is bounded by
the actual arm contraction and the player's trigger request, so released
triggers continue braking even when the hold requires partly bent arms.

Two-hand holds can make independently driven spins oppose one another. The
shared constraints and torque limits determine the result; there is no forced
spin synchronization or scripted dance motion.

Existing figures, ghost demonstrations and narration are available only in
co-op. Single-player has no migrated figures.

## Implementation and validation

`prototype_controller.gd` selects mode and restores mode-specific geometry.
`single_player_controls.gd` maps steering and owns the two bumper assignments.
`hand_connection.gd` supplies nearest-pair acquisition and the shared solver.
`dancer.gd` shares movement/carry and selects trigger spin or heading control.
Telemetry includes mode, bumper ownership, spin direction and mode-specific tuning.

Run `tests/single_player_mode_test.gd` for mode switching, control mapping,
both bumper orders, release/cooldown behavior, two-hand spin stress and carry.
Co-op regression coverage remains in the existing mechanics, movement, release,
double-hold, menu and figure tests. Controller feel still needs playtesting.

# Co-op reconciliation, 2026-09-09

This integration combines the previously divergent gameplay and artwork using
the user's explicit precedence decisions:

| Area | Source and outcome |
| --- | --- |
| Gameplay baseline | `885d265` (hybrid): common skeleton, grip ownership/latching, independent D-pad stance, toggle locks, weighted LS and lock authority, sensitivity tuning |
| Handholding and effort | `7081309` (historical rigid): smooth acquisition followed by rigid point joints for every hold; double-hold mutual flexion and full red-arm feedback |
| RS | `7a5f779` (main): radial heading correction, eased light travel, strong full travel, continuous circles, no queued turns, physical spin retained |
| Artwork | `7a5f779` (main): tapered arms, cuffs, palm/thumb meshes with supination, torso/belly contours, and fixed 20 px body circles |
| Weight | New common 40-120 kg range, precise 1 kg mass/inertia updates, per-dancer fit reference in 5 kg steps, capped visual growth every 5 kg above fit |

The saved hybrid stash was reviewed in full. Its controller change preserves
linear RS magnitude independently of stick sensitivity; that change is kept.
Its pending-turn accumulation, rate-limited dial tests, and corresponding docs
and telemetry describe an older RS design and are superseded by main's current
radial heading behavior. The original stash is retained.

Hybrid's compliant one-hand spring and mutual-dorsal exception are superseded
by the explicitly requested rigid solver. Main's spring stabilization is also
superseded: the combined version has no spring handhold. Main's held locks,
mutual D-pad abduction, different male/female arm lengths, and older speed-scale
menu controls give way to hybrid's gameplay contract.

One compatibility extension was needed: the old rigid full-flexion pose could
close the hands by overlapping the torso circles (measured centre distance
7.25 px for circles requiring 40 px). The existing arm-span projection now also
respects torso clearance. Requested triggers remain unchanged, and impossible
flexion uses the same red effort feedback. No input averaging or scripted
movement recovery was added.

The rigid position solver's iteration limit is 32 (previously 16). Same-side
double grips under different D-pad stances needed the extra iterations: their
worst measured gap decreased from 1.36 px to 0.03 px. The solver still exits
early when contacts converge.

The archive branches `codex/archive-hybrid-20260909`,
`codex/archive-main-20260909`, `codex/archive-rigid-20260909`, and
`codex/archive-hybrid-stash-20260909` retain all four original source states.
No source commits were rewritten and the stash was not popped or dropped.

## Validation commands

Run Godot in this co-op project with `--headless --path . --script` and each of:

- `res://tests/prototype_mechanics_test.gd`
- `res://tests/rs_dial_test.gd`
- `res://tests/combined_hold_test.gd` (both extreme weight orderings, RS, D-pad, full and unequal flexion)
- `res://tests/telemetry_recorder_test.gd`
- `res://tests/handhold_replay_test.gd` (latest regression input, captured weights)
- `res://tests/handhold_replay_test.gd -- --extreme-weights` (120/40 kg)

`tests/weight_visual_preview.gd` uses a real renderer and writes weight bands,
pose/supination, menu, and connected effort previews to the OS temporary folder.
Automated checks do not establish subjective two-controller feel.

The restored mechanics suite samples at the end of physics processing, after
the dancer motors and contact solver, matching telemetry. Sampling the
SceneTree `physics_frame` signal itself measures the unsolved start of a step.

Final validation passed: mechanics 132/132, RS 10/10, telemetry 42/42, and
combined holds 20/20. The combined test's maximum contact gap was 0.033 px,
including 120/40 kg, reversed weight ordering, and same-side double grips.
Every neutral tail settled without sustained spin oscillation. The latest
capture regression also settled without oscillation, and the full telemetry
replay and rendered weight/pose/menu/effort previews were inspected.

# Figure references

Open the pause menu with Start / Escape and select FIGURES (LB / RB changes
tabs). Four two-hand references are available:

1. **Travelling turn**: contract one joined side halfway and travel through a half-turn.
2. **Turn in place**: circle through a full turn around a fixed shared centre.
3. **Alternating sides**: contract one joined side halfway, swap sides, then swap back.
4. **Open and close**: travel across the floor, drawing both joined sides inward
   and extending them again twice.

Each movement lasts six seconds at normal speed. It holds briefly at the end,
then fades out and back in at the beginning to repeat. Contractions use the
triggers, with both partners matching their requests at each connected hand.
Open and close uses both triggers on both controllers. These references do
not change the D-pad stance; that remains a separate player control.

- Show demonstration turns both semi-transparent dancers on or off. Enabling
  it restarts the reference.
- Previous / next selects a figure and restarts it, leaving players in place.
  The arrows are disabled while only one figure is available.
- Speed 0.5x / 0.75x / 1x affects only the reference, including its loop pause.
- Restart demonstration rewinds the reference.
- Reset players to corners releases their handholds and clears movement and
  locks, returning them to their original bottom-corner positions.

The menu pauses both gameplay and the reference. Closing it resumes playback.
Players can move freely, watch any number of repetitions, and try their own
version; there is no scoring or pose matching. Settings last for this session.

## Authoring

`DanceFigure` resources contain a name, instruction, duration, and timed keys
for pair centre, rotation (unwrapped radians), and connected-side contractions:
`flexion` controls A-left / B-right; `secondary_flexion` controls A-right / B-left
and defaults to zero for older resources.
An optional `arc` vector bends a segment away from its straight path. Transitions
ease in and out. Register resources in `FigureDemonstration.FIGURES`; the menu
reads their names and count automatically.

The renderer supports opposite-hand double holds with either or both connected
sides contracting. It aligns the two equal hand spans to keep
both contacts closed. Other hold types will need their own pose construction
before adding figures that use them. Keep torso clearance when authoring keys.

Ghosts reuse the existing dancer artwork and arm geometry with frozen bodies,
no collision shapes, zero collision layers/masks, and disabled physics processing.
A CanvasGroup applies opacity to the completed artwork. Their authored motion
never drives the players or the hand-connection solver.

Validation: `--headless --path . --script res://tests/figure_demonstration_test.gd`.

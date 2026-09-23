# Figure references

Open the pause menu with Start / Escape and select FIGURES (LB / RB changes tabs).
Demonstrations start switched off; players start in the bottom corners.
There are **21 figure entries containing 38 selectable demonstrations**.
Connected turn and its former reverse entry now share one figure entry.

Use the upper arrows to choose a figure and the VARIANT arrows beneath them to
choose its direction or starting side. The variant row is hidden for figures
with only one demonstration. Descriptions and the floor caption identify the
selected variant. Each figure remembers its last variant for this session.
Changing a figure or variant restarts the demonstration and queues its narration,
without moving players or changing playback speed or demonstration visibility.

Clockwise/counterclockwise refer to the overhead view; CW and CCW are abbreviated
only in compact labels. Screen left/right identify floor positions, while hand
names refer to each partner's own hands. Descriptions and narration use gentleman
(dancer A), lady (dancer B), and partners.

| Figure | Variants |
| --- | --- |
| Travelling turn | Clockwise / Counterclockwise |
| Turn in place | Clockwise / Counterclockwise |
| Alternating sides | Single demonstration |
| Open and close | Single demonstration |
| Join behind the back | Single demonstration |
| Connected turn | Clockwise / Counterclockwise |
| Release, turn, catch | Left to right / Right to left |
| Open out and return | Gentleman left / lady right / Gentleman right / lady left |
| Progressive twinkles | Start left / Start right |
| Open impetus | Clockwise / Counterclockwise |
| Wing | Right to left / Left to right |
| Weave from promenade | Counterclockwise / Clockwise |
| Away and together | Gentleman left / lady right / Gentleman right / lady left |
| Solo turns and rejoin | Gentleman CW / lady CCW / Gentleman CCW / lady CW |
| Synchronous spins | Clockwise / Counterclockwise |
| Mirror spins | Gentleman CW / lady CCW / Gentleman CCW / lady CW |
| Two planets | Clockwise / Counterclockwise |
| Spinning planets | Clockwise / Counterclockwise |
| Do-si-do | Right shoulders / Left shoulders |
| Travelling turns | Clockwise / Counterclockwise |
| Mirror paths | Single demonstration |

Most opposite variants mirror the complete choreography, including travel paths,
arm contractions and hand changes. Connected turn instead reverses the lady's
rotation while keeping the same starting pose and gentleman-left/lady-right hold.
Spinning planets reverses both orbit and body spin together; its description
explicitly states both directions. There is no separate counter-rotating orbit mode.
Alternating sides already demonstrates both sides. Open and close, Join behind
the back and Mirror paths retain one demonstration each.

The first five references use two hands. Connected turn through Solo turns and
rejoin use one hand, with releases where demonstrated. Synchronous spins through
Mirror paths use no hand contact: keep both bumpers released. Hold only the
bumper for the joined hand in one-hand figures. Release and change bumpers when
the demonstration changes hands. Contractions use triggers, with partners
matching their requests at each connected hand.

Each movement lasts six seconds at normal speed, holds briefly at the end, then
fades out and back to the beginning. Ghosts are references for experimentation;
there is no scoring or exact pose matching.

- Show demonstration switches both ghosts on or off; enabling restarts playback.
- Previous / next figure and variant arrows wrap through their respective lists.
- Speed 0.5x / 0.75x / 1x affects the movement and loop pause, not narration speed.
- Restart demonstration rewinds the movement and replays available narration.
- Reset players to corners releases holds and clears movement, locks and arm state.

The menu pauses gameplay, the demonstration and narration. Closing it resumes
playback. Narration plays once when enabled, selected or explicitly restarted;
automatic loops do not repeat it. Switching figures or variants stops the previous
voice. Missing recordings leave the demonstration silent. The floor caption
shows the figure and variant, hides in menus, and has no numbering.

[FIGURE_VOICEOVERS.md](FIGURE_VOICEOVERS.md) contains all 38 prepared scripts.
Existing neutral recordings remain attached where accurate, including shared
recordings for mirrored Travelling turn, Turn in place and Open out and return.
The four recordings using colour-based roles (both Connected turns, Release,
turn, catch, and Progressive twinkles) were detached and deleted on 2026-09-23. No new
audio was generated for this change. See [recording status](VOICEOVER_RECORDINGS.md).

## Path references

Progressive twinkles, Open impetus, Wing and Weave from promenade adapt waltz
floor patterns to the game's handholds. Their mirrored versions are game
adaptations too, not claims about formal ballroom technique or figure names.
These references informed the original paths:

- [Progressive twinkles](https://www.ballroomdancers.com/dances/info.asp?sid=761)
- [Open impetus](https://www.ballroomdancers.com/Dances/info.asp?sid=498)
- [Wing](https://www.ballroomdancers.com/Dances/info.asp?sid=500)
- [Weave from promenade](https://www.dancecentral.info/ballroom/international-style/waltz/weave-from-promenade-position)
- [Round-dance waltz figures](https://www.rounddancing.net/dance/figures/waltz.html),
  including away-and-together and solo turns
- [CALLERLAB Do-si-do](https://teaching.callerlab.org/mainstream/dosado-definition/dosado-teaching/)

## Playback pacing

Loops use figure-specific durations: simple demonstrations remain six seconds;
more travel or turning gets more time. At 1x, the catalogue is tuned to peak
body speeds below 150 px/s, hand speeds below 180 px/s and turns below 110 degrees/s.
These are authoring targets checked against the rendered ghost skeleton, not
runtime clamps. Each figure retains its paths, easing and relative key timing.

Connected turn takes 9 s; Release, turn, catch 10 s; Progressive twinkles 14 s;
Open impetus 6.5 s; Wing 10 s; Weave from promenade 9.5 s; Away and together 8 s;
Solo turns 9.5 s; Two planets 8.5 s; Spinning planets 12 s; Do-si-do 7 s.
Mirrored variants use the same timing. The end pause/fade and narration speed
remain unchanged; the existing speed buttons still scale movement playback.

## Authoring

`DanceFigure` resources contain a name, instruction, duration, and timed keys
for pair centre, rotation (unwrapped radians), and connected-side contractions:
`flexion` controls A-left / B-right; `secondary_flexion` controls A-right / B-left
and defaults to zero for older resources.
The optional `narration` AudioStream references the corresponding local WAV in
`voiceover_samples/`. Assign new recordings to this field as they are generated;
resource references ensure that audio is included in exported builds. Keep WAV
looping disabled. Playback never contacts the generation API.
`forward_sweep` defaults to 25 degrees. An approach figure can set
`separate_body_distance` and animate `join_progress` from zero to one, with
`joined_from` marking when both hand contacts must close.
An optional `arc` vector bends a segment away from its straight path. Transitions
ease in and out. Register one base resource per figure in `FigureDemonstration.FIGURES` and its
additional resources in `FigureDemonstration.VARIANTS`, keyed by the base filename
without `.tres`. The menu reads names, counts, descriptions and `variant_label`
automatically. Resources assign `script` before script-defined properties.

A mirrored variant points `mirror_of` to its base figure instead of duplicating
keyframes. `get_keys()` reflects absolute positions across x=640, negates horizontal
offsets, arcs and unwrapped angles, exchanges anatomical hand sides, and swaps
the two contractions for double holds. It preserves partner identities and timing.
Copy the base duration and hold-mode metadata into the variant resource; author
its own label and description. Connected turn's counterclockwise variant retains
its separately authored keys because it reverses the turn using the same hands.
Use `get_keys()` for timeline consumers, including connection glints.

Double holds align the two equal hand spans to keep both contacts closed after
any authored approach. With `single_hand`, `turn` and `partner_turn` independently
rotate the dancers, and `flexion` / `partner_flexion` control their joined arms.
`hand_side` selects A's contact (-1 left, +1 right) with B's opposite hand.
`free_flexion` and `partner_free_flexion` control the unjoined arms.
`release_offset` separates the selected hands; `release_weight` blends B onto
an independent `release_position` floor path. Switch contact sides only while
fully released, with equal arm poses at the switch, to avoid visual jumps.
`anchor_first_body` makes `centre` the first dancer's position; otherwise it is
the pair midpoint. Keep torso clearance when authoring keys.

With `no_hands`, `position_a` and `position_b` independently describe body offsets
from `centre`. `path_turn` rotates these offsets around that centre to produce
an exact circular orbit. `turn` / `partner_turn` still control body facing
independently; changing them does not alter the path. Optional `arc_a` / `arc_b`
bend each path segment. The four flexion fields continue to pose the arms.
Use unwrapped angles for full turns. No-hand mode takes precedence over hold
construction and does not imply a contact even when hands happen to approach.

Ghosts reuse the existing dancer artwork and arm geometry with frozen bodies,
no collision shapes, zero collision layers/masks, and disabled physics processing.
A CanvasGroup applies opacity to the completed artwork. Their authored motion
never drives the players or the hand-connection solver.

Focused validation:
- `tests/figure_demonstration_test.gd`: continuity, clearance, contact and figure actions across all variants.
- `tests/figure_variant_test.gd`: full-body/hand reflection, selector behaviour and narration switching.
- `tests/figure_voiceover_test.gd`: playback, pause, restart and missing-recording behaviour.
- `python tools/generate_figure_voiceover.py --list`: validates every script against the resource catalogue without networking.

- `tests/figure_pacing_test.gd`: body, hand and angular speed limits across all 38 demonstrations, timeline endpoints and mirrored timing.

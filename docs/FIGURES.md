# Figure references

Open the pause menu with Start / Escape and select FIGURES (LB / RB changes
tabs). Demonstrations start switched off; players start in the bottom corners.
Twenty-two references are available, starting with five two-hand figures:

1. **Travelling turn**: contract one joined side halfway and travel through a half-turn.
2. **Turn in place**: circle through a full turn around a fixed shared centre.
3. **Alternating sides**: contract one joined side halfway, swap sides, then swap back.
4. **Open and close**: travel across the floor, drawing both joined sides inward
   and extending them again twice.
5. **Join behind the back**: start apart, back-to-back, sweep both arms backward
   with D-pad down, then approach and hold both bumpers to join. Stay still.

Single-hand and release figures follow (normally dark dancer's left / light dancer's right):

6. **Connected turn**: the light dancer closes both arms, makes a clockwise full turn
   while the dark dancer stays in place, then extends again.
7. **Connected turn - reverse**: the adjacent counterclockwise version, also
   with both turning arms fully closed during rotation.
8. **Release, turn, catch**: start to one side, turn inward, release, pass in
   front while completing the turn, then extend and catch the opposite pair
   of hands on the partner's other side.
9. **Open out and return**: turn outward into an open position, pause, then return.
10. **Progressive twinkles**: travel in a zigzag while the light dancer passes
    from side to side, changing the joined hand pair at each crossing.
11. **Open impetus**: turn around the dark dancer, open into a V, then travel
    together in a shared direction.
12. **Wing**: the light dancer traces a semicircle across the partner's front,
    moving from right to left and settling facing the partner.
13. **Weave from promenade**: start in an open V, travel through a left turn,
    close face-to-face and continue diagonally.
14. **Away and together**: release, turn outward and travel apart, then return
    to face each other and reconnect.
15. **Solo turns and rejoin**: separate, close both arms and turn independently
    in opposite directions, then reach and reconnect.

Seven figures use no hand contact at any point:

16. **Synchronous spins**: stay in separate places and turn once in the same
    direction, at the same time.
17. **Mirror spins**: turn once in opposite directions, like two gears.
18. **Two planets**: circle a shared midpoint, staying opposite and facing
    each other throughout the orbit.
19. **Spinning planets**: complete one orbit while each body makes two turns.
20. **Do-si-do**: pass right shoulders, move behind each other, and return
    without changing body facing.
21. **Travelling turns**: move across the floor on parallel paths while both spin.
22. **Mirror paths**: follow mirrored curves, approaching, separating, then
    approaching again while facing each other.

Keep both bumpers released for these figures. Arms stay mostly closed to make
the body turns clear and preserve space between the dancers. The planets and
mirror paths use descriptive game names. Do-si-do follows the floor pattern
described by [CALLERLAB](https://teaching.callerlab.org/mainstream/dosado-definition/dosado-teaching/).

The former single-hand Walk around the partner and Change places were removed to avoid redundant
circles. The two connected turns remain adjacent.

Figures 10-13 adapt waltz floor patterns to the game's handholds; they do not
teach ballroom footwork or reproduce a closed ballroom frame. Wing changes hands
during its crossing. The sources below informed the paths and facing directions:

- [Progressive twinkles](https://www.ballroomdancers.com/dances/info.asp?sid=761)
- [Open impetus](https://www.ballroomdancers.com/Dances/info.asp?sid=498)
- [Wing](https://www.ballroomdancers.com/Dances/info.asp?sid=500)
- [Weave from promenade](https://www.dancecentral.info/ballroom/international-style/waltz/weave-from-promenade-position)
- [Round-dance waltz figures](https://www.rounddancing.net/dance/figures/waltz.html),
  including away-and-together and solo turns, inspired figures 14-15.

Hold only the bumper for the joined hand. Release it during the free turn in
figure 8, then hold the other bumper to catch on the opposite side. Free-arm
poses vary by figure to make the action clear.

Each movement lasts six seconds at normal speed. It holds briefly at the end,
then fades out and back in at the beginning to repeat. Contractions use the
triggers, with both partners matching their requests at each connected hand.
Open and close uses both triggers on both controllers. The first four references
keep a fixed D-pad stance; Join behind the back demonstrates the backward sweep.

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
`forward_sweep` defaults to 25 degrees. An approach figure can set
`separate_body_distance` and animate `join_progress` from zero to one, with
`joined_from` marking when both hand contacts must close.
An optional `arc` vector bends a segment away from its straight path. Transitions
ease in and out. Register resources in `FigureDemonstration.FIGURES`; the menu
reads their names and count automatically.

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

Validation: `--headless --path . --script res://tests/figure_demonstration_test.gd`.

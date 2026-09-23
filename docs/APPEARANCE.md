# Ballroom presentation

Run the project (`main.tscn`) to open the title screen. Dance enters the current
session; Settings and Ballroom return to the title screen with Back. During play,
Esc or the controller Start/Options button opens the pause menu. Its General tab
also offers Return to title, preserving the current dance.

Menus support mouse, keyboard focus navigation, and controller navigation.
Enter / A confirms, Esc / B goes back, and LB / RB changes settings tabs.
The title screen shows the connection state of the two controllers assigned by
the existing player-selection code.

## Floors

Ballroom is available from the title screen and as a pause-menu tab:

- Classic parquet: oak herringbone with a dark wood border (default).
- Grand ballroom: walnut parquet panels with brass perimeter details.
- Practice studio: muted maple boards, with an optional practice grid.

The selected floor and grid preference are saved to `user://coop_appearance.cfg`.
The grid appears only on the studio floor. An unsuccessful save is reported in
the picker; the current session can still use the selection.

`ballroom_floor.gd` draws the floor behind the dancers. These choices are purely
visual: arena bounds, collisions, grip behavior, and movement remain unchanged.
The SVG assets in `assets/floors/` can be edited directly or regenerated with
`python tools/build_floor_art.py` (standard library only).

## Typography and menus

`ballroom_theme.gd` defines the ivory, brass, and charcoal UI palette and control
styles. `entrance_screen.gd` builds the title screen; `pause_menu.gd` shares the
theme across the existing tuning, dancer, figure, and telemetry controls.

The fonts are bundled locally under the SIL Open Font License:

- [Cormorant Garamond](https://github.com/google/fonts/tree/main/ofl/cormorantgaramond)
  at weight 500 for large headings.
- [Source Sans 3](https://github.com/google/fonts/tree/main/ofl/sourcesans3)
  at weight 450 for body text and controls.

Licenses and editable FontVariation resources live in `assets/fonts/`.
The numeric variation key `2003265652` is the OpenType `wght` tag. The body face
is also the project default, so diagnostic labels use the same font.
The title's right-hand area shows the actual dancer artwork: a two-second
approach, hand connection, and a travelling turn around a circular path. After
the introduction, the dance loops continuously without fading or resetting.
`title_dance.gd` reuses `FigureDemonstration`'s artwork and connected-hand pose
calculation. These are isolated, non-colliding display dancers; the gameplay
session stays paused. `icon.svg` remains the project icon only.
Title playback runs at 1.5x speed. A brief gold-and-ivory glint marks the initial
hand connection; the same half-second cue appears on each successful gameplay
handhold. It fades out without changing the catch or hold behavior.

`prototype.tscn` remains the direct gameplay scene for existing mechanics tests.
`main.tscn` inherits it and enables the title screen for normal launches.

## Validation

- `tests/ballroom_menu_test.gd`: startup, pause/back navigation, controller
  actions, floor selection, and valid/invalid preference files. Uses its own
  temporary preference path, without changing the player's saved appearance.
- Existing `prototype_mechanics_test.gd` and `figure_demonstration_test.gd`.
- `tests/title_dance_test.gd`: approach, hand contact, continuous looping,
  screen bounds, and isolation from the paused gameplay session.
- `tests/render_preview.gd`: modes `title`, `ballroom`, `menu`, `figures`,
  and `floor 0`, `floor 1`, or `floor 2 grid` for rendered inspection.
  `title 0`, `title 3`, and `title 18` capture fixed animation times.

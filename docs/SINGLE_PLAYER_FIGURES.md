# Single-player figures in the combined game

Launch this checkout's `project.godot`, choose **Single player**, then open
**Start / Escape > FIGURES**. There are 19 figures with 43 selectable demonstrations.
Enable Show demonstration and resume. Variant arrows, 0.5x/0.75x/1x speed,
restart, and reset-to-corners work as in co-op. Demonstrations begin hidden.

The single-player catalogue is separate from the 21-entry co-op catalogue.
Changing modes stops the outgoing ghosts and narration, and routes every Figures
control to the selected mode. Each catalogue retains its own selections and speed.

This integrates the figures originally created in the separate `Dancers/single`
checkout into the combined game. The combined game has newer hand controls:
hold either bumper to catch one pair, then the other to catch the remaining pair.
Release a bumper after catching; press it again to release only its owned pair.
The descriptions and [prepared narration](SINGLE_PLAYER_VOICEOVERS.md) use those
controls. No new recordings or changes to player physics are included.

The catalogue includes planets and spin combinations, do-si-do, slalom, passing
spirals, pendulum, moving sun, open-out, travelling wheel, release/spin/catch,
alternating catches, three rear-hold figures, and five two-hand figures. These
are ideal ghost references for experimentation, not forced physical replays.
Turning open-and-close describes a movement to explore; opposite spin requests
alone do not guarantee the demonstrated shared rotation.

`single_figures/*.tres` and `single_figure_demonstration.gd` keep single-player
choreography isolated. Playback, captions and narration reuse the co-op base.
`tools/build_single_figures.py` rebuilds only single-player resources and exact
narration text, preserving later attached recordings. It does not generate audio.

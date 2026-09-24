# Active Dancers checkout

This `combined` worktree is the working source of truth for both single-player
and co-op modes. Continue development here. The sibling `coop` and `single`
checkouts are preserved historical references; do not synchronize edits back
to them unless the user requests it.

The Godot entry point is `project.godot` / `main.tscn`. Keep each mode's figure
catalogue and control guidance separate: `figures/` is co-op, `single_figures/`
is single-player. Preserve existing user edits and voiceover recordings.

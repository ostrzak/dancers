extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene: PrototypeController = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	await process_frame
	menu.entrance.single_player_button.pressed.emit()
	var demo: SingleFigureDemonstration = scene.figure_demonstration
	var coop: FigureDemonstration = scene.get_node("FigureDemonstration")
	check(menu.demonstration == demo and not menu.tabs.is_tab_hidden(3), "Title Single player selects its own visible Figures tab")
	check(demo.FIGURES.size() == 19 and coop.FIGURES.size() == 21, "Separate single/co-op catalogues")
	menu._pause()
	menu._switch_tab(3)
	menu.figure_toggle.button_pressed = true
	check(demo.visible and not coop.visible, "Show toggle targets single ghosts only")
	var original_a := scene.left_dancer.position
	var original_b := scene.right_dancer.position
	var scripts := FileAccess.get_file_as_string("res://docs/SINGLE_PLAYER_VOICEOVERS.md")
	var total := 0
	var layout_fits := true
	for index in demo.FIGURES.size():
		demo.select_figure(index)
		for variant in demo.get_variants().size():
			total += 1
			demo.select_variant(variant)
			var figure: SingleDanceFigure = demo.get_figure()
			menu._refresh_figure_labels()
			check(scripts.contains(figure.narration_text) and not figure.description.is_empty(), figure.get_caption() + ": exact narration and menu text")
			check(not figure.narration_text.contains("hold both bumpers") and not figure.narration_text.contains("future two-hand"), figure.get_caption() + ": combined-game controls")
			var valid := true
			for frame in 61:
				demo.elapsed = figure.duration * frame / 60.0
				demo._update_pose()
				for ghost in [demo.ghost_a, demo.ghost_b]:
					valid = valid and ghost.position.is_finite() and Rect2(60,60,1160,580).has_point(ghost.position)
					valid = valid and is_equal_approx(ghost.get_arm_flexion(-1), ghost.get_arm_flexion(1))
			check(valid, figure.get_caption() + ": finite poses and synchronized arms")
			await process_frame
			await process_frame
			layout_fits = layout_fits and root.get_visible_rect().grow(1).encloses(menu.get_node("Center/Panel").get_global_rect())
	check(total == 43 and layout_fits, "All 43 demonstrations fit menu")
	check(scene.left_dancer.position == original_a and scene.right_dancer.position == original_b, "Selections do not move players")
	demo.elapsed = 3.0
	menu.figure_restart.pressed.emit()
	check(demo.elapsed == 0.0, "Restart button targets active single demonstration")
	menu._set_figure_speed(0.5)
	check(demo.playback_speed == 0.5 and coop.playback_speed == 1.0, "Independent playback settings")
	scene.start_session(PrototypeController.PlayMode.COOP)
	check(menu.demonstration == coop and not demo.visible, "Switching to co-op stops single demonstration and reroutes menu")
	menu.figure_toggle.button_pressed = true
	check(coop.visible and not demo.visible, "Toggle switches to co-op playback")
	scene.start_session(PrototypeController.PlayMode.SINGLE)
	check(not coop.visible and menu.demonstration == demo and not demo.visible, "Returning to single stops co-op playback")
	check(menu.figure_speed_buttons[0].button_pressed, "Single speed selection restored")
	scene.free()
	print("SINGLE FIGURE MENU: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

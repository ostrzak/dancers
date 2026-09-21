extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := "res://diagnostics/dancers-preview.png"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		output_path = arguments[0]
	var scene: Node = load("res://prototype.tscn").instantiate()
	get_root().add_child(scene)
	if arguments.size() > 1:
		match arguments[1]:
			"effort":
				var man: Dancer = scene.get_node("LeftDancer")
				man.set_double_hold_arm_state(-1, 0.25, 1.0)
			"menu":
				var pause_menu: PauseMenu = scene.get_node("PauseMenu")
				pause_menu._pause()
				pause_menu.tabs.current_tab = 1
				pause_menu.trigger_sensitivity_slider.grab_focus()
			"figures":
				var pause_menu: PauseMenu = scene.get_node("PauseMenu")
				if arguments.size() > 2:
					pause_menu.demonstration.select_figure(int(arguments[2]))
					pause_menu._refresh_figure_labels()
				pause_menu._pause()
				pause_menu._switch_tab(3)
			"figure_pose":
				var demonstration: FigureDemonstration = scene.get_node("FigureDemonstration")
				demonstration.set_process(false)
				demonstration.set_demonstration_visible(true)
				if arguments.size() > 2:
					demonstration.select_figure(int(arguments[2]))
				demonstration.elapsed = float(arguments[3]) if arguments.size() > 3 else 3.0
				demonstration._update_pose()
	for _frame in 4:
		await process_frame
	var image := get_root().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save preview: %s" % error_string(error))
		quit(1)
		return
	print("RENDER PREVIEW: %s" % ProjectSettings.globalize_path(output_path))
	quit(0)

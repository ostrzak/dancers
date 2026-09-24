extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if not args.is_empty() else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.start_session(PrototypeController.PlayMode.SINGLE)
	scene.set_physics_process(false)
	var demo := scene.figure_demonstration
	demo.set_process(false)
	demo.set_demonstration_visible(true)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	menu._pause()
	menu._switch_tab(3)
	for selection in [[1, 5], [18, 1]]:
		demo.select_figure(selection[0])
		demo.select_variant(selection[1])
		menu._refresh_figure_labels()
		await capture(directory.path_join("menu-%d.png" % selection[0]))
	menu._resume()
	for selection in [[0, 7.0], [7, 5.0], [9, 8.0], [11, 6.0], [14, 5.0], [18, 7.0]]:
		demo.select_figure(selection[0])
		demo.select_variant(0)
		demo.elapsed = selection[1]
		demo._update_pose()
		await capture(directory.path_join("pose-%d.png" % selection[0]))
	quit()


func capture(path: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Failed to save " + path)
		quit(1)

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
	if arguments.size() > 1 and arguments[1] == "grip":
		var left: Dancer = scene.get_node("LeftDancer")
		var right: Dancer = scene.get_node("RightDancer")
		var connection: HandConnection = scene.get_node("HandConnection")
		left.freeze = true
		right.freeze = true
		left.global_position = Vector2(560.0, 360.0)
		left.global_rotation = 0.0
		right.global_rotation = PI
		right.global_position = (
			left.get_hand_world_position(1)
			+ Vector2(35.0, 0.0)
			- right.get_hand_offset(1)
		)
		connection.set_dancer_grip_state(left, true)
	for _frame in 4:
		await process_frame
	var texture := get_root().get_texture()
	if texture == null:
		push_error("Render preview requires a real display renderer.")
		quit(1)
		return
	var image := texture.get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save preview: %s" % error_string(error))
		quit(1)
		return
	print("RENDER PREVIEW: %s" % ProjectSettings.globalize_path(output_path))
	quit(0)

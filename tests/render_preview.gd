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

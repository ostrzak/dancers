extends SceneTree

# Run with a real renderer, --windowed --resolution 1280x720.
# Preview images go to the OS temporary directory, outside the project.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := Node2D.new()
	get_root().add_child(gallery)
	var dancers: Array[Dancer] = []
	_label(gallery, "WEIGHT / ARM VISUAL CHECK", Vector2(35, 30), 24)
	for style in [0, 1]:
		var weights := range(70, 101, 5) if style == 0 else range(50, 71, 5)
		for index in weights.size():
			var dancer := Dancer.new()
			dancer.body_style = style
			dancer.body_color = Color("111111") if style == 0 else Color("f2f2f2")
			dancer.detail_color = Color("f2f2f2") if style == 0 else Color("111111")
			if style == 1:
				dancer.shoulder_half_width = 16.0
				dancer.upper_arm_length = 38.5
				dancer.forearm_length = 38.5
			dancer.freeze = true
			dancer.position = Vector2(100 + index * 180 + style * 180, 200 + style * 260)
			gallery.add_child(dancer)
			dancer.set_physics_process(false)
			dancer.set_weight_kg(float(weights[index]))
			dancers.append(dancer)
			_label(gallery, "%d kg" % weights[index], dancer.position + Vector2(-25, -70), 18)
	for pose in [0.0, 0.5, 1.0]:
		for dancer in dancers:
			for side in [-1, 1]:
				dancer.set_current_arm_length(side, lerpf(dancer.maximum_arm_length, dancer.minimum_arm_length, pose))
			dancer.queue_redraw()
		await _capture("dancers-weight-pose-%d.png" % int(pose * 100))
	# Extreme D-pad sweep and asymmetric trigger on the same geometry.
	for dancer in dancers:
		dancer.extended_forward_sweep_degrees = -25.0
		dancer.set_current_arm_length(-1, dancer.minimum_arm_length)
		dancer.set_current_arm_length(1, dancer.maximum_arm_length)
		dancer.queue_redraw()
	await _capture("dancers-weight-asymmetric.png")
	gallery.free()
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	get_root().add_child(scene)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	menu._pause()
	menu._switch_tab(2)
	await _capture("dancers-weight-menu.png")
	menu._resume()
	scene.set_physics_process(false)
	var man: Dancer = scene.get_node("LeftDancer")
	var woman: Dancer = scene.get_node("RightDancer")
	for dancer in [man, woman]:
		dancer.freeze = true
		dancer.set_physics_process(false)
	man.position = Vector2(640, 260)
	man.rotation = 0.0
	woman.rotation = PI
	woman.position = man.position + man.get_hand_local_position(1) - woman.get_hand_local_position(-1).rotated(PI)
	var connection: HandConnection = scene.get_node("HandConnection")
	for side in [-1, 1]:
		connection.set_grip_button_state(man, side, true)
		connection.set_grip_button_state(woman, -side, true)
	await _capture("dancers-palm-handhold.png")
	scene.free()
	quit()


func _label(parent: Node, text: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("TEMP").path_join(filename)
	var error := get_root().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Preview save failed: %s" % path)
	else:
		print(path)

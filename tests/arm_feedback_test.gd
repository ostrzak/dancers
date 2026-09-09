extends SceneTree

var checks := 0
var failures := 0
var scene: PrototypeController


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	scene = load("res://prototype.tscn").instantiate()
	get_root().add_child(scene)
	scene.set_physics_process(false)
	var man := scene.left_dancer
	var woman := scene.right_dancer
	var hold := scene.hand_connection
	_check_consent("free")
	for dancer in [man, woman]:
		dancer.freeze = true
	man.position = Vector2(640, 280)
	woman.rotation = PI
	woman.position = man.position + man.get_hand_local_position(1) - woman.get_hand_local_position(-1).rotated(PI)
	await physics_frame
	for dancer in [man, woman]:
		dancer.freeze = false
	for side in [-1, 1]:
		hold.set_grip_button_state(man, side, true)
		hold.set_grip_button_state(woman, -side, true)
	_check(hold.get_active_connection_count() == 2, "test acquired both actual handholds")
	_check_consent("double")
	for dancer in [man, woman]:
		dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0)
	await _frames(150)
	for dancer in [man, woman]:
		for side in [-1, 1]:
			_check(dancer.get_double_hold_arm_effort(side) > 0.05
				and dancer.get_hand_display_color(side).is_equal_approx(dancer.body_color),
				"matched full tuck remains neutral despite the physical torso limit")
	await _preview("dancers-tint-matched.png")
	woman.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.94, 0.94)
	await _frames(45)
	_check(man.get_hand_display_color(-1).is_equal_approx(man.body_color)
		and man.get_hand_display_color(1).is_equal_approx(man.body_color),
		"six-percent partner differences remain inside the quiet zone")
	woman.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	await _frames(60)
	_check(man.get_hand_display_color(-1).is_equal_approx(Dancer.FIGHT_HAND_COLOR)
		and woman.get_hand_display_color(1).is_equal_approx(woman.body_color),
		"a strong unmatched request still turns only the requesting partner red")
	await _preview("dancers-tint-unmatched.png")
	hold.release_secondary_hands()
	_check_consent("single")
	await _frames(2)
	_check(man.get_hand_display_color(-1).is_equal_approx(man.body_color),
		"leaving double hold clears the request tint")
	print("ARM CONSENT / FEEDBACK: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _check_consent(mode: String) -> void:
	var man := scene.left_dancer
	var woman := scene.right_dancer
	for dancer in [man, woman]:
		dancer.extended_elbow_flexion_degrees = 12.0
		dancer.extended_forward_sweep_degrees = 25.0
	scene._apply_arm_pose_inputs(Vector2.ONE, Vector2.ZERO, 0.1)
	scene._apply_arm_pose_inputs(Vector2.ONE, -Vector2.ONE, 0.1)
	_check(man.extended_elbow_flexion_degrees == 12.0 and woman.extended_elbow_flexion_degrees == 12.0
		and man.extended_forward_sweep_degrees == 25.0 and woman.extended_forward_sweep_degrees == 25.0,
		"%s: one-sided and opposing D-pad input cannot adjust either stance" % mode)
	scene._apply_arm_pose_inputs(Vector2.ONE, Vector2.ONE, 0.1)
	_check(man.extended_elbow_flexion_degrees == 8.0 and woman.extended_elbow_flexion_degrees == 8.0
		and man.extended_forward_sweep_degrees == 29.0 and woman.extended_forward_sweep_degrees == 29.0,
		"%s: matching input adjusts both stances equally" % mode)
	scene._apply_arm_pose_inputs(Vector2.ONE, Vector2.DOWN, 0.1)
	_check(man.extended_elbow_flexion_degrees == 8.0 and woman.extended_elbow_flexion_degrees == 8.0
		and man.extended_forward_sweep_degrees == 33.0 and woman.extended_forward_sweep_degrees == 33.0,
		"%s: consent is independent per axis" % mode)
	man.extended_elbow_flexion_degrees = 5.0
	woman.extended_elbow_flexion_degrees = 7.0
	scene._apply_arm_pose_inputs(Vector2.RIGHT, Vector2.RIGHT, 0.1)
	_check(woman.extended_elbow_flexion_degrees == 7.0,
		"%s: either partner's endpoint stops the shared adjustment" % mode)
	paused = true
	scene._apply_arm_pose_inputs(Vector2.ONE, Vector2.ONE, 0.1)
	_check(man.extended_forward_sweep_degrees == 33.0, "%s: paused D-pad stays menu-only" % mode)
	paused = false
	for dancer in [man, woman]:
		dancer.extended_elbow_flexion_degrees = 12.0
		dancer.extended_forward_sweep_degrees = 25.0


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _preview(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--preview"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("TEMP").path_join(filename)
	_check(get_root().get_texture().get_image().save_png(path) == OK, "save feedback preview")
	print(path)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

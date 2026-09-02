extends SceneTree

var _failures: Array[String] = []
var _root: PrototypeController
var _left: Dancer
var _right: Dancer
var _connection: HandConnection
var _debug_overlay: DebugOverlay
var _pause_menu: PauseMenu


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root = load("res://prototype.tscn").instantiate()
	get_root().add_child(_root)
	_left = _root.get_node("LeftDancer")
	_right = _root.get_node("RightDancer")
	_connection = _root.get_node("HandConnection")
	_debug_overlay = _root.get_node("DebugOverlay")
	_pause_menu = _root.get_node("PauseMenu")
	_root.set_physics_process(false)
	_expect(ProjectSettings.get_setting("display/window/size/mode") == 3, "project launches in fullscreen mode")
	_expect(_left.body_color.get_luminance() < 0.5 and _right.body_color.get_luminance() > 0.5, "man is black and woman is white")
	_expect(_left.detail_color.get_luminance() > 0.5 and _right.detail_color.get_luminance() < 0.5, "each dancer uses an opposite-color body detail")
	_expect(not _left.flip_body_symbol and _right.flip_body_symbol, "woman uses the opposite triangle and head arrangement")
	_expect(_right.hand_line_offset < _left.hand_line_offset, "woman's hands sit closer to her head")
	_expect(
		is_equal_approx(_left.upper_arm_length, 52.0 * 0.7)
		and is_equal_approx(_left.forearm_length, 52.0 * 0.7)
		and is_equal_approx(_right.upper_arm_length, 55.0 * 0.7)
		and is_equal_approx(_right.forearm_length, 55.0 * 0.7),
		"both arm segments are shortened proportionally by thirty percent"
	)
	_expect(
		_left.physics_material_override.friction == 0.0
		and _right.physics_material_override.friction == 0.0,
		"frictionless dancer contacts preserve spin through wall impacts"
	)

	await _wait_physics_frames(150)
	print("spin sample: left=%.3f right=%.3f targets=(%.3f, %.3f) inertia=(%.1f, %.1f)" % [
		_left.angular_velocity, _right.angular_velocity,
		_left.target_angular_velocity, _right.target_angular_velocity,
		_left.inertia, _right.inertia
	])
	_expect(_left.angular_velocity > 0.5, "left dancer accelerates clockwise")
	_expect(_right.angular_velocity < -0.5, "right dancer accelerates counterclockwise")
	_expect(_arm_segments_match(_left) and _arm_segments_match(_right), "arms use their current top-down projected segment lengths")
	_expect(_upper_arms_project_radially(_left) and _upper_arms_project_radially(_right), "upper arms stay radial in the top-down projection")
	_expect(
		_left.get_projected_upper_arm_length() < _left.upper_arm_length
		and _left.get_projected_upper_arm_length() > _left.upper_arm_length * 0.95,
		"maximum abduction exposes almost the full anatomical upper arm"
	)
	_expect(
		_forearms_bend_dorsally(_left, true)
		and _forearms_bend_dorsally(_right, true)
		and is_equal_approx(_left.get_projected_forearm_length(), _left.forearm_length),
		"released triggers retain a slight mirrored elbow bend"
	)
	_expect(is_equal_approx(_left.global_position.y, 360.0), "left dancer has no downward gravity drift")
	_expect(is_equal_approx(_right.global_position.y, 360.0), "right dancer has no downward gravity drift")
	_expect(_hands_are_mirrored(_left), "two hands remain mirrored across the body axis")
	_expect(
		absf(_left.get_hand_local_position(1).x) > _left.maximum_arm_length - 2.0,
		"released arms retain their broad lateral reach"
	)
	_left.reverse_spin()
	await _wait_physics_frames(1)
	_expect(_left.angular_velocity > 0.5, "reversal does not instantly flip angular velocity")
	var crossed_low_angular_velocity := false
	for _frame in 300:
		await physics_frame
		crossed_low_angular_velocity = crossed_low_angular_velocity or absf(_left.angular_velocity) < 0.2
	_expect(crossed_low_angular_velocity, "reversal passes through a low-angular-velocity window")
	_expect(_left.angular_velocity < -0.5, "torque reversal eventually changes physical spin")

	var extended_inertia := _left.inertia
	var anatomical_upper_arm_length := _left.upper_arm_length
	var extended_projected_forearm_length := _left.get_projected_forearm_length()
	_left.set_control_input(Vector2.ZERO, 1.0)
	await _wait_physics_frames(60)
	_expect(_left.current_arm_length < _left.maximum_arm_length - 40.0, "trigger contracts the arm continuously")
	_expect(_left.inertia < extended_inertia, "contracted arm lowers effective inertia")
	_expect(absf(_left.target_angular_velocity) > _left.minimum_target_angular_velocity, "contracted arm raises target spin speed")
	_expect(
		_left.get_spin_move_scale() > 1.0,
		"the faster tucked spin state also raises movement speed"
	)
	_expect(_arm_segments_match(_left), "flexed pose uses both projected segment lengths")
	_expect(
		is_equal_approx(_left.upper_arm_length, anatomical_upper_arm_length)
		and is_zero_approx(_left.get_projected_upper_arm_length())
		and _left.get_elbow_local_position(1).is_equal_approx(
			_left.get_shoulder_local_position(1)
		)
		and is_equal_approx(_left.get_elbow_joint_radius(), Dancer.HAND_RADIUS),
		"full adduction collapses the humerus into a hand-sized shoulder cap"
	)
	_expect(_forearms_bend_dorsally(_left, false), "adducted forearms fold inward through the elbows")
	_expect(
		_left.get_projected_forearm_length() < _left.forearm_length * 0.2
		and _hands_finish_on_same_side_pec(_left),
		"forearm foreshortening places each hand over its same-side pectoral"
	)
	var tucked_projected_forearm_length := _left.get_projected_forearm_length()
	_left.current_arm_length = lerpf(
		_left.maximum_arm_length,
		_left.minimum_arm_length,
		0.5
	)
	var midway_projected_forearm_length := _left.get_projected_forearm_length()
	_left.current_arm_length = _left.minimum_arm_length
	_expect(
		extended_projected_forearm_length > midway_projected_forearm_length
		and midway_projected_forearm_length > tucked_projected_forearm_length,
		"forearm projection shortens continuously throughout the movement"
	)

	_left.set_control_input(Vector2.ZERO, 0.0)
	_left.global_position = Vector2(500.0, 360.0)
	_left.global_rotation = 0.0
	_right.global_rotation = PI
	_right.global_position = (
		_left.get_hand_world_position(1) - _right.get_hand_offset(1)
	)
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0
	await _wait_physics_frames(2)
	_expect(_connection.is_connected, "near, slow hands catch automatically")
	_left.set_control_input(Vector2.LEFT, 1.0)
	_right.set_control_input(Vector2.RIGHT, 1.0)
	var peak_connection_force := 0.0
	var peak_connection_error := 0.0
	var separation_limit_activation_frames := 0
	for _frame in 240:
		await physics_frame
		peak_connection_force = maxf(peak_connection_force, _connection.connection_force)
		peak_connection_error = maxf(peak_connection_error, _connection.distance_error)
		if _connection.separation_limit_active:
			separation_limit_activation_frames += 1
	print("connection stress sample: peak_error=%.3f px limit_frames=%d" % [
		peak_connection_error,
		separation_limit_activation_frames,
	])
	_expect(_connection.is_connected, "ordinary tension does not auto-release the hands")
	_expect(peak_connection_force > 10.0, "connected hands generate a physical constraint force")
	_expect(
		peak_connection_error <= _connection.maximum_hand_separation + 0.05,
		"strong opposing pushes and arm retraction stay within two hand widths"
	)
	_expect(
		separation_limit_activation_frames > 0,
		"stress scenario exercises the firm separation tether"
	)
	_expect(_left.linear_velocity.is_finite() and _right.linear_velocity.is_finite(), "coupled motion remains numerically finite")
	_expect(maxf(_left.linear_velocity.length(), _right.linear_velocity.length()) < 2000.0, "coupled motion remains below emergency velocities")

	var left_direction_before := _left.intended_spin_direction
	var right_direction_before := _right.intended_spin_direction
	_left.linear_velocity = Vector2(91.0, -27.0)
	_right.linear_velocity = Vector2(-48.0, 63.0)
	_left.angular_velocity = 1.75
	_right.angular_velocity = -2.25
	var left_linear_before := _left.linear_velocity
	var right_linear_before := _right.linear_velocity
	var left_angular_before := _left.angular_velocity
	var right_angular_before := _right.angular_velocity

	_root._register_bumper_press(_root.LEFT_BUMPER)
	_root._register_bumper_press(_root.RIGHT_BUMPER)
	_expect(_connection.is_connected, "connected LB+RB keeps the handhold")
	_expect(_left.intended_spin_direction == -left_direction_before, "connected LB+RB reverses the left dancer")
	_expect(_right.intended_spin_direction == -right_direction_before, "connected LB+RB reverses the right dancer")
	_expect(_left.linear_velocity.is_equal_approx(left_linear_before), "direction chord preserves left linear velocity")
	_expect(_right.linear_velocity.is_equal_approx(right_linear_before), "direction chord preserves right linear velocity")
	_expect(is_equal_approx(_left.angular_velocity, left_angular_before), "direction chord does not instantly flip left angular velocity")
	_expect(is_equal_approx(_right.angular_velocity, right_angular_before), "direction chord does not instantly flip right angular velocity")

	var left_direction_before_release := _left.intended_spin_direction
	var right_direction_before_release := _right.intended_spin_direction
	_root._input(_joy_button_event(JOY_BUTTON_A))
	_expect(not _connection.is_connected, "A releases the handhold")
	_expect(_left.intended_spin_direction == left_direction_before_release, "A release preserves left intended direction")
	_expect(_right.intended_spin_direction == right_direction_before_release, "A release preserves right intended direction")
	_expect(_left.linear_velocity.is_equal_approx(left_linear_before), "A release preserves left linear velocity")
	_expect(_right.linear_velocity.is_equal_approx(right_linear_before), "A release preserves right linear velocity")
	_expect(is_equal_approx(_left.angular_velocity, left_angular_before), "A release preserves left angular velocity")
	_expect(is_equal_approx(_right.angular_velocity, right_angular_before), "A release preserves right angular velocity")

	_root._register_bumper_press(_root.LEFT_BUMPER)
	_root._register_bumper_press(_root.RIGHT_BUMPER)
	_expect(_left.intended_spin_direction == -left_direction_before_release, "disconnected LB+RB reverses the left dancer")
	_expect(_right.intended_spin_direction == -right_direction_before_release, "disconnected LB+RB reverses the right dancer")

	var left_direction_before_single := _left.intended_spin_direction
	_root._register_bumper_press(_root.LEFT_BUMPER)
	_root._resolve_pending_bumper(_root.bumper_chord_window + 0.001)
	_expect(_left.intended_spin_direction == -left_direction_before_single, "single bumper reverses only after the chord window")

	_expect(not _debug_overlay.visible and not _pause_menu.visible, "telemetry and pause menu start hidden")
	_pause_menu._pause()
	_expect(paused and _pause_menu.visible, "pause menu pauses the simulation")
	_pause_menu.telemetry_toggle.grab_focus()
	_pause_menu._input(_joy_button_event(JOY_BUTTON_A))
	_expect(_debug_overlay.visible and _pause_menu.telemetry_toggle.button_pressed, "gamepad A toggles telemetry")
	_expect(
		is_equal_approx(_root._apply_input_sensitivity(0.25, 2.0), 0.5)
		and is_equal_approx(_root._apply_input_sensitivity(0.25, 0.5), 0.0625),
		"input sensitivity changes response curvature without changing endpoints"
	)
	_pause_menu._input(_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER))
	_expect(
		_pause_menu.tabs.current_tab == 1
		and _pause_menu.spin_speed_slider.has_focus(),
		"RB opens the tuning tab and focuses its first slider"
	)
	_pause_menu.spin_speed_slider.value = 1.5
	_pause_menu.move_speed_slider.value = 1.25
	_pause_menu.spin_move_ratio_slider.value = 0.5
	_pause_menu.trigger_sensitivity_slider.value = 2.0
	_pause_menu.stick_sensitivity_slider.value = 0.75
	_expect(
		is_equal_approx(_root.spin_speed_scale, 1.5)
		and is_equal_approx(_root.move_speed_scale, 1.25)
		and is_equal_approx(_root.spin_move_ratio, 0.5)
		and is_equal_approx(_root.trigger_sensitivity, 2.0)
		and is_equal_approx(_root.stick_sensitivity, 0.75)
		and is_equal_approx(_left.spin_speed_scale, 1.5)
		and is_equal_approx(_right.move_speed_scale, 1.25),
		"tuning sliders update both dancers and shared input response"
	)
	_pause_menu._resume()
	_expect(not paused and not _pause_menu.visible, "resume closes the menu and unpauses")

	_right.set_runtime_tuning(1.0, 1.0, 1.0)
	_right.intended_spin_direction = 1
	_right.current_arm_length = _right.maximum_arm_length
	_right.set_control_input(Vector2.RIGHT, 0.0)
	_right.global_position = Vector2(1230.0, 360.0)
	_right.linear_velocity = Vector2(300.0, 0.0)
	_right.angular_velocity = _right.minimum_target_angular_velocity
	var minimum_wall_contact_spin := INF
	for _frame in 30:
		await physics_frame
		minimum_wall_contact_spin = minf(
			minimum_wall_contact_spin,
			_right.angular_velocity
		)
	_expect(
		minimum_wall_contact_spin > _right.minimum_target_angular_velocity * 0.75,
		"white dancer keeps an even spin while pressing into an arena wall"
	)

	if _failures.is_empty():
		print("PROTOTYPE MECHANICS: 61/61 checks passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("PROTOTYPE MECHANICS: %d failure(s)" % _failures.size())
		quit(1)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _joy_button_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event


func _arm_segments_match(dancer: Dancer) -> bool:
	for side in [-1, 1]:
		var shoulder := dancer.get_shoulder_local_position(side)
		var elbow := dancer.get_elbow_local_position(side)
		var hand := dancer.get_hand_local_position(side)
		if absf(shoulder.distance_to(elbow) - dancer.get_projected_upper_arm_length()) > 0.05:
			return false
		if absf(elbow.distance_to(hand) - dancer.get_projected_forearm_length()) > 0.05:
			return false
	return true


func _upper_arms_project_radially(dancer: Dancer) -> bool:
	for side in [-1, 1]:
		var shoulder := dancer.get_shoulder_local_position(side)
		var elbow := dancer.get_elbow_local_position(side)
		var outward := Vector2.RIGHT * float(side)
		var upper_arm := elbow - shoulder
		if absf(upper_arm.cross(outward)) > 0.05 or upper_arm.dot(outward) <= 0.0:
			return false
	return true


func _forearms_bend_dorsally(dancer: Dancer, should_still_point_outward: bool) -> bool:
	for side in [-1, 1]:
		var elbow := dancer.get_elbow_local_position(side)
		var forearm := dancer.get_hand_local_position(side) - elbow
		var outward := Vector2.RIGHT * float(side)
		if forearm.dot(dancer.get_dorsal_local_direction()) <= 0.0:
			return false
		if should_still_point_outward != (forearm.dot(outward) > 0.0):
			return false
	return true


func _hands_are_mirrored(dancer: Dancer) -> bool:
	var left_hand := dancer.get_hand_local_position(-1)
	var right_hand := dancer.get_hand_local_position(1)
	return (
		is_equal_approx(left_hand.x, -right_hand.x)
		and is_equal_approx(left_hand.y, right_hand.y)
	)


func _hands_finish_on_same_side_pec(dancer: Dancer) -> bool:
	for side in [-1, 1]:
		var hand := dancer.get_hand_local_position(side)
		var lateral_position := hand.x * float(side)
		if lateral_position <= 0.0 or lateral_position >= dancer.shoulder_half_width:
			return false
	return true

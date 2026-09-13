extends SceneTree

var _failures: Array[String] = []
var _checks := 0
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

	_expect(
		ProjectSettings.get_setting("display/window/size/mode") == 3,
		"project launches in fullscreen mode"
	)
	_expect(
		_root.preferred_gamepad_device == 0,
		"single-player controls prefer the first controller"
	)
	_expect(
		_left.body_color.get_luminance() < 0.5
		and _right.body_color.get_luminance() > 0.5,
		"the left dancer is black and the right dancer is white"
	)
	_expect(
		_left.body_style == 0 and _right.body_style == 1,
		"the dancers retain distinct top-down silhouettes"
	)
	_expect(
		absf(wrapf(_right.global_rotation - _left.global_rotation - PI, -PI, PI))
		< 0.01,
		"the dancers begin in opposite orientations"
	)
	_expect(
		is_equal_approx(_left.get_node("CollisionShape2D").shape.radius, 12.0)
		and is_equal_approx(_right.get_node("CollisionShape2D").shape.radius, 12.0),
		"minimal torso colliders leave room for the hand spring"
	)
	_expect(
		_left.physics_material_override.friction == 0.0
		and _right.physics_material_override.friction == 0.0,
		"frictionless dancer contacts preserve spin at the walls"
	)
	_expect(
		_connection.get_solver_mode() == "spring"
		and is_equal_approx(_connection.maximum_hand_separation, 27.0),
		"the migrated solver is the coop one-hand spring with its hard tether"
	)

	await _wait_physics_frames(150)
	_expect(
		absf(_left.angular_velocity) < 0.05
		and is_zero_approx(_left.target_angular_velocity),
		"the black dancer does not spin without LT"
	)
	_expect(
		absf(_right.angular_velocity) < 0.05
		and is_zero_approx(_right.target_angular_velocity),
		"the white dancer does not spin without RT"
	)
	_expect(
		_arm_segments_match(_left) and _arm_segments_match(_right),
		"drawn arms use their independent projected segment lengths"
	)

	var right_extended_hand := _left.get_hand_local_position(1)
	var extended_inertia := _left.inertia
	_root.apply_control_state(
		Vector2.ZERO,
		Vector2.ZERO,
		1.0,
		0.0,
		Vector2.ZERO,
		1.0 / 60.0
	)
	await _wait_physics_frames(60)
	_expect(
		_left.get_arm_flexion(-1) > 0.99
		and _left.get_arm_flexion(1) > 0.99,
		"LT contracts both independent black-dancer arms"
	)
	_expect(
		_right.get_arm_flexion(-1) < 0.01
		and _right.get_arm_flexion(1) < 0.01,
		"LT leaves both white-dancer arms extended"
	)
	_expect(
		_left.get_hand_local_position(1) != right_extended_hand
		and _left.inertia < extended_inertia,
		"arm contraction changes the visible hand and effective inertia"
	)
	_expect(
		absf(_left.target_angular_velocity)
		> _left.minimum_target_angular_velocity,
		"LT arm contraction creates the black dancer's spin target"
	)
	_expect(
		_left.angular_velocity > 0.5
		and absf(_right.angular_velocity) < 0.05,
		"only the dancer with an applied trigger begins spinning"
	)
	var full_trigger_spin := absf(_left.target_angular_velocity)
	_root.apply_control_state(
		Vector2.ZERO,
		Vector2.ZERO,
		0.5,
		0.0,
		Vector2.ZERO,
		1.0 / 60.0
	)
	await _wait_physics_frames(30)
	_expect(
		absf(_left.target_angular_velocity) > 0.0
		and absf(_left.target_angular_velocity) < full_trigger_spin,
		"spin target rises continuously as the trigger contracts the arms"
	)

	var left_direction_before_l3 := _left.intended_spin_direction
	var right_direction_before_l3 := _right.intended_spin_direction
	var left_spin_before_l3 := _left.angular_velocity
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_STICK))
	_expect(
		_left.intended_spin_direction == -left_direction_before_l3
		and _right.intended_spin_direction == right_direction_before_l3,
		"L3 toggles only the black dancer's spin direction"
	)
	_expect(
		is_equal_approx(_left.angular_velocity, left_spin_before_l3),
		"L3 changes the target direction without teleporting angular momentum"
	)
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_STICK, 0, false))
	_expect(
		_left.intended_spin_direction == -left_direction_before_l3,
		"releasing L3 does not toggle a second time"
	)
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_STICK))
	_expect(
		_left.intended_spin_direction == left_direction_before_l3,
		"a second L3 press toggles the black direction back"
	)
	var left_direction_before_r3 := _left.intended_spin_direction
	var right_direction_before_r3 := _right.intended_spin_direction
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_STICK))
	_expect(
		_right.intended_spin_direction == -right_direction_before_r3
		and _left.intended_spin_direction == left_direction_before_r3,
		"R3 toggles only the white dancer's spin direction"
	)
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_STICK))
	_expect(
		_right.intended_spin_direction == right_direction_before_r3,
		"a second R3 press toggles the white direction back"
	)

	_root.apply_control_state(
		Vector2(0.25, -0.75),
		Vector2(-0.5, 0.2),
		0.3,
		0.8,
		Vector2.ZERO,
		1.0 / 60.0
	)
	_expect(
		_left.movement_input.is_equal_approx(Vector2(0.25, -0.75))
		and _right.movement_input.is_equal_approx(Vector2(-0.5, 0.2)),
		"LS maps to the black dancer and RS maps to the white dancer"
	)
	_expect(
		is_equal_approx(_left.left_trigger_value, 0.3)
		and is_equal_approx(_left.right_trigger_value, 0.3)
		and is_equal_approx(_right.left_trigger_value, 0.8)
		and is_equal_approx(_right.right_trigger_value, 0.8),
		"LT and RT independently set the two dancers' paired arm contraction"
	)

	_root.apply_control_state(
		Vector2.ZERO,
		Vector2.ZERO,
		0.0,
		0.0,
		Vector2.RIGHT,
		1.0
	)
	_expect(
		_left.extended_elbow_flexion_degrees
		== _left.minimum_extended_elbow_flexion_degrees
		and _right.extended_elbow_flexion_degrees
		== _right.minimum_extended_elbow_flexion_degrees,
		"D-pad stance adjustment applies identically to both dancers"
	)
	await _wait_physics_frames(180)
	_expect(
		is_zero_approx(_left.target_angular_velocity)
		and is_zero_approx(_right.target_angular_velocity)
		and absf(_left.angular_velocity) < 0.05
		and absf(_right.angular_velocity) < 0.05,
		"releasing both triggers brings both dancers back to rest"
	)
	_left.extended_elbow_flexion_degrees = 12.0
	_right.extended_elbow_flexion_degrees = 12.0

	await _prepare_hand_gap(1, 1, Vector2(90.0, 0.0))
	_expect(
		not _connection.has_any_connection(),
		"hands remain open until both dancer bumpers are held"
	)
	_connection.set_dancer_grip_state(_left, true)
	_expect(
		_connection.is_dancer_primed(_left)
		and _connection.is_hand_primed(_left, 1)
		and not _connection.has_any_connection(),
		"LB primes only the closest black hand while waiting for RB"
	)
	await _prepare_hand_gap(-1, -1, Vector2(60.0, 0.0))
	_expect(
		_connection.is_hand_primed(_left, -1)
		and not _connection.is_hand_primed(_left, 1),
		"the small candidate marker follows the currently closest black hand"
	)
	_connection.set_dancer_grip_state(_right, true)
	await _wait_physics_frames(2)
	_expect(
		not _connection.has_any_connection(),
		"both held bumpers keep waiting while the closest pair is out of reach"
	)
	await _prepare_hand_gap(-1, -1, Vector2(36.0, 0.0))
	await _wait_physics_frames(2)
	var held_sides := _connection.get_connected_hand_sides()
	_expect(
		_connection.is_connected
		and not _connection.is_secondary_connected
		and _connection.get_active_connection_count() == 1
		and _connection.get_hold_mode() == "single",
		"both held bumpers latch exactly one hand pair"
	)
	_expect(
		held_sides[0] == -1 and held_sides[1] == -1,
		"the closest eligible pair is the pair that catches"
	)
	_expect(
		not _connection.is_dancer_primed(_left)
		and not _connection.is_dancer_primed(_right),
		"a successful catch consumes both primed states"
	)
	_expect(
		_connected_gap() <= _connection.maximum_hand_separation + 0.1
		and _connection.primary_allowed_separation
		<= _connection.maximum_hand_separation,
		"the catch enters the coop spring's hard fingertip tether"
	)

	_left.freeze = false
	_right.freeze = false
	_left.set_control_input(Vector2.LEFT, 1.0)
	_right.set_control_input(Vector2.RIGHT, 0.0)
	var peak_gap := 0.0
	var peak_force := 0.0
	var peak_elastic_blend := 0.0
	var tether_activated := false
	for _frame in 180:
		await physics_frame
		peak_gap = maxf(peak_gap, _connected_gap())
		peak_force = maxf(peak_force, _connection.connection_force)
		peak_elastic_blend = maxf(
			peak_elastic_blend,
			_connection.primary_elastic_blend
		)
		tether_activated = tether_activated or _connection.separation_limit_active
	print(
		"single spring stress: peak_gap=%.3f force=%.3f blend=%.3f tether=%s"
		% [peak_gap, peak_force, peak_elastic_blend, str(tether_activated)]
	)
	_expect(_connection.is_connected, "ordinary spring tension does not auto-release")
	_expect(peak_force > 10.0, "the hand spring produces a physical constraint response")
	_expect(
		peak_gap <= _connection.maximum_hand_separation + 0.1,
		"strong opposing movement remains inside the coop tether"
	)
	_expect(
		tether_activated or peak_gap < _connection.maximum_hand_separation,
		"the stress case is bounded before or through the hard projection"
	)
	_expect(
		peak_elastic_blend > 0.5,
		"fast one-hand movement opens the softer elastic response"
	)
	_expect(
		_left.get_arm_flexion(-1) > 0.99
		and _left.get_arm_flexion(1) > 0.99
		and _right.get_arm_flexion(-1) < 0.01
		and _right.get_arm_flexion(1) < 0.01,
		"the latched spring does not replace either dancer's trigger pose"
	)
	_expect(
		_left.linear_velocity.is_finite()
		and _right.linear_velocity.is_finite()
		and maxf(
			_left.linear_velocity.length(),
			_right.linear_velocity.length()
		) < 2000.0,
		"coupled motion remains finite and below emergency velocity"
	)

	_connection.set_dancer_grip_state(_left, false)
	_connection.set_dancer_grip_state(_right, false)
	_expect(
		_connection.has_any_connection()
		and _connection.is_release_tap_armed(_left, held_sides[0])
		and _connection.is_release_tap_armed(_right, held_sides[1]),
		"releasing the catch bumpers leaves the latch and arms the next tap"
	)
	var left_velocity_before_release := _left.linear_velocity
	var right_velocity_before_release := _right.linear_velocity
	var left_angular_before_release := _left.angular_velocity
	var right_angular_before_release := _right.angular_velocity
	_connection.set_dancer_grip_state(_left, true)
	_expect(
		not _connection.has_any_connection(),
		"a fresh tap of either dancer bumper releases the single hold"
	)
	_expect(
		_left.linear_velocity.is_equal_approx(left_velocity_before_release)
		and _right.linear_velocity.is_equal_approx(right_velocity_before_release)
		and is_equal_approx(_left.angular_velocity, left_angular_before_release)
		and is_equal_approx(_right.angular_velocity, right_angular_before_release),
		"release preserves both dancers' linear and angular momentum"
	)
	_expect(
		not _connection.is_dancer_primed(_left)
		and not _connection.is_dancer_primed(_right),
		"the release tap cannot immediately re-prime a hand"
	)
	_connection.set_dancer_grip_state(_left, false)

	await _wait_physics_frames(30)
	await _prepare_hand_gap(1, 1, Vector2(30.0, 0.0))
	_left.linear_velocity = Vector2(-150.0, 0.0)
	_right.linear_velocity = Vector2(150.0, 0.0)
	_connection.set_dancer_grip_state(_left, true)
	_connection.set_dancer_grip_state(_right, true)
	await _wait_physics_frames(1)
	_expect(
		not _connection.has_any_connection(),
		"closest hands above the relative-speed threshold do not catch"
	)
	_connection.set_dancer_grip_state(_left, false)
	_connection.set_dancer_grip_state(_right, false)

	_expect(
		not _debug_overlay.visible and not _pause_menu.visible,
		"telemetry and pause menu start hidden"
	)
	_pause_menu._pause()
	_expect(paused and _pause_menu.visible, "pause menu pauses the simulation")
	_pause_menu.telemetry_toggle.grab_focus()
	_pause_menu._input(_joy_button_event(JOY_BUTTON_A))
	_expect(
		_debug_overlay.visible
		and _pause_menu.telemetry_toggle.button_pressed,
		"gamepad A toggles telemetry while paused"
	)
	_expect(
		is_equal_approx(_root._apply_input_sensitivity(0.25, 2.0), 0.5)
		and is_equal_approx(_root._apply_input_sensitivity(0.25, 0.5), 0.0625),
		"input sensitivity preserves the established response curve"
	)
	_pause_menu._input(_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER))
	_expect(
		_pause_menu.tabs.current_tab == 1,
		"RB still switches to the tuning tab while paused"
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
		"runtime tuning updates both single-player dancers"
	)
	_pause_menu._resume()
	_expect(not paused and not _pause_menu.visible, "resume unpauses the game")

	if _failures.is_empty():
		print(
			"SINGLE-PLAYER SPRING MECHANICS: %d/%d checks passed"
			% [_checks, _checks]
		)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print(
			"SINGLE-PLAYER SPRING MECHANICS: %d failure(s) across %d checks"
			% [_failures.size(), _checks]
		)
		quit(1)


func _prepare_hand_gap(
	hand_a_side: int,
	hand_b_side: int,
	gap: Vector2
) -> void:
	_left.freeze = true
	_right.freeze = true
	_left.set_position_lock_enabled(false)
	_left.set_rotation_lock_enabled(false)
	_right.set_position_lock_enabled(false)
	_right.set_rotation_lock_enabled(false)
	_left.set_runtime_tuning(0.0, 1.0, 1.0)
	_right.set_runtime_tuning(0.0, 1.0, 1.0)
	_left.set_control_input(Vector2.ZERO, 0.0)
	_right.set_control_input(Vector2.ZERO, 0.0)
	for side in Dancer.HAND_SIDES:
		_left.set_current_arm_length(side, _left.maximum_arm_length)
		_right.set_current_arm_length(side, _right.maximum_arm_length)
	_left.global_position = Vector2(500.0, 360.0)
	_left.global_rotation = 0.0
	_right.global_rotation = PI
	_right.global_position = (
		_left.get_hand_world_position(hand_a_side)
		+ gap
		- _right.get_hand_offset(hand_b_side)
	)
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0
	await _wait_physics_frames(2)


func _connected_gap() -> float:
	var sides := _connection.get_connected_hand_sides()
	return _left.get_hand_world_position(sides[0]).distance_to(
		_right.get_hand_world_position(sides[1])
	)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _joy_button_event(
	button_index: int,
	device: int = 0,
	pressed: bool = true
) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button_index
	event.pressed = pressed
	return event


func _arm_segments_match(dancer: Dancer) -> bool:
	for side in Dancer.HAND_SIDES:
		var shoulder := dancer.get_shoulder_local_position(side)
		var elbow := dancer.get_elbow_local_position(side)
		var hand := dancer.get_hand_local_position(side)
		if not is_equal_approx(
			shoulder.distance_to(elbow),
			dancer.get_projected_upper_arm_length(side)
		):
			return false
		if not is_equal_approx(
			elbow.distance_to(hand),
			dancer.get_projected_forearm_length(side)
		):
			return false
	return true

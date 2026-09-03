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

	_expect(ProjectSettings.get_setting("display/window/size/mode") == 3, "project launches in fullscreen mode")
	_expect(_root.preferred_player_one_device == 0, "player one prefers the first controller")
	_expect(_root.preferred_player_two_device == 1, "player two prefers the second controller")
	_expect(_left.body_color.get_luminance() < 0.5, "player one controls the black dancer")
	_expect(_right.body_color.get_luminance() > 0.5, "player two controls the white dancer")
	_expect(_left.body_style == 0 and _right.body_style == 1, "the dancers use distinct top-down man and woman silhouettes")
	_expect(
		Dancer.BODY_REAR_Y >= Dancer.HEAD_CENTER.y - Dancer.HEAD_RADIUS
		and Dancer.BODY_FORWARD_Y <= Dancer.HEAD_CENTER.y + Dancer.HEAD_RADIUS,
		"the upright torso footprint stays completely beneath the head lengthwise"
	)
	_expect(
		Dancer.NOSE_TIP_Y > Dancer.HEAD_CENTER.y + Dancer.HEAD_RADIUS
		and Dancer.LOCAL_FORWARD_DIRECTION == Vector2.DOWN,
		"the nose projects from the corrected local-forward side of the head"
	)
	_expect(
		absf(wrapf(_right.global_rotation - _left.global_rotation - PI, -PI, PI)) < 0.01,
		"the dancers begin facing one another"
	)
	_expect(
		is_equal_approx(_left.get_node("CollisionShape2D").shape.radius, 12.0)
		and is_equal_approx(_right.get_node("CollisionShape2D").shape.radius, 12.0),
		"minimal torso colliders leave room for a close dance frame"
	)
	_expect(
		_left.physics_material_override.friction == 0.0
		and _right.physics_material_override.friction == 0.0,
		"frictionless dancer contacts preserve turning at walls"
	)
	_expect(
		is_equal_approx(_left.extended_forward_sweep_degrees, 25.0)
		and is_equal_approx(_right.extended_forward_sweep_degrees, 25.0),
		"released arms default to a forward-facing ballroom frame"
	)
	_expect(
		is_zero_approx(_connection.get_elastic_blend_for_speed(40.0))
		and is_equal_approx(_connection.get_elastic_blend_for_speed(600.0), 1.0),
		"the handhold selects weld response at low speed and elastic response at high speed"
	)

	await _wait_physics_frames(60)
	_expect(absf(_left.angular_velocity) < 0.05, "neutral RS does not create automatic black-dancer spin")
	_expect(absf(_right.angular_velocity) < 0.05, "neutral RS does not create automatic white-dancer spin")
	_expect(_arm_segments_match(_left) and _arm_segments_match(_right), "arm drawings use their side-specific projected segment lengths")
	_expect(_hands_are_mirrored(_left), "equal trigger values keep the black dancer's hands mirrored")

	_left.set_control_input(Vector2.ZERO, Vector2.RIGHT, 0.0, 0.0)
	await _wait_physics_frames(120)
	_expect(
		absf(wrapf(_left.global_rotation + PI * 0.5, -PI, PI)) < 0.2,
		"RS right turns the corrected nose toward screen right"
	)
	_expect(absf(_left.heading_error) < 0.2, "the facing motor converges on the requested heading")
	var retained_direction := _left.desired_facing_direction
	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_left.global_rotation = 0.0
	_left.angular_velocity = 0.0
	await _wait_physics_frames(60)
	_expect(_left.desired_facing_direction.is_equal_approx(retained_direction), "neutral RS retains the last input direction for diagnostics")
	_expect(
		absf(_left.global_rotation) < 0.05
		and is_zero_approx(_left.diagnostic_spin_torque),
		"neutral RS leaves its achieved heading without resisting partner-applied rotation"
	)

	for frame in 240:
		var aim_angle := -PI * 0.5 + TAU * float(frame) / 120.0
		_left.set_control_input(
			Vector2.ZERO,
			Vector2.from_angle(aim_angle),
			0.0,
			0.0
		)
		await physics_frame
	print("circular facing sample: error=%.3f deg angular=%.3f target=%.3f" % [
		rad_to_deg(_left.heading_error),
		_left.angular_velocity,
		_left.target_angular_velocity,
	])
	_expect(_left.global_rotation < INF and _left.angular_velocity < INF, "two continuous RS circles remain numerically finite")
	_expect(absf(_left.heading_error) < 0.9, "the facing motor tracks a sustained circular RS gesture")

	_left.angular_velocity = 0.0
	_left.set_control_input(Vector2.ZERO, Vector2.UP, 0.0, 0.0)
	_left.set_current_arm_length(-1, _left.maximum_arm_length)
	_left.set_current_arm_length(1, _left.maximum_arm_length)
	await _wait_physics_frames(30)
	var extended_inertia := _left.inertia
	var right_extended_hand := _left.get_hand_local_position(1)
	_left.set_control_input(Vector2.ZERO, Vector2.UP, 1.0, 0.0)
	await _wait_physics_frames(60)
	_expect(
		_left.get_current_arm_length(-1) < _left.minimum_arm_length + 0.1,
		"LT fully contracts only the left arm"
	)
	_expect(
		is_equal_approx(_left.get_current_arm_length(1), _left.maximum_arm_length),
		"LT leaves the right arm extended"
	)
	_expect(_left.get_arm_flexion(-1) > 0.99 and _left.get_arm_flexion(1) < 0.01, "left and right arm flexion are independent")
	_expect(_left.get_hand_local_position(1).is_equal_approx(right_extended_hand), "left-arm motion does not move the right hand")
	_expect(_left.inertia < extended_inertia, "contracting one arm lowers effective inertia")
	_expect(
		_left.get_turn_speed_limit() > _left.minimum_target_angular_velocity
		and _left.get_turn_speed_limit() < _left.maximum_target_angular_velocity,
		"one tucked arm produces an intermediate turn-speed limit"
	)
	_expect(_arm_segments_match(_left), "asymmetric trigger input preserves both arm chains")
	_expect(
		is_zero_approx(_left.get_projected_upper_arm_length(-1))
		and _left.get_projected_upper_arm_length(1) > _left.upper_arm_length * 0.95,
		"only the LT-controlled humerus adducts out of the top-down projection"
	)

	_left.set_control_input(Vector2.ZERO, Vector2.UP, 0.0, 0.0)
	_left.set_current_arm_length(-1, _left.maximum_arm_length)
	_left.set_current_arm_length(1, _left.maximum_arm_length)
	var default_extended_hand := _left.get_hand_local_position(1)
	_left.adjust_extended_arm_pose(1.0, 0.0, 1.0)
	var widened_hand := _left.get_hand_local_position(1)
	_expect(
		_left.extended_elbow_flexion_degrees
		== _left.minimum_extended_elbow_flexion_degrees
		and widened_hand.x > default_extended_hand.x,
		"D-pad right widens both fully extended arms within the elbow limit"
	)
	_left.extended_elbow_flexion_degrees = 12.0
	_left.adjust_extended_arm_pose(0.0, 1.0, 1.0)
	var forward_hand := _left.get_hand_local_position(1)
	_expect(
		_left.extended_forward_sweep_degrees
		== _left.maximum_extended_forward_sweep_degrees
		and forward_hand.y > default_extended_hand.y + 10.0,
		"D-pad up sweeps both fully extended arms toward local forward"
	)
	_left.adjust_extended_arm_pose(-1.0, 1.0, 10.0)
	_expect(
		_left.extended_elbow_flexion_degrees
		== _left.maximum_extended_elbow_flexion_degrees
		and _left.extended_forward_sweep_degrees
		== _left.maximum_extended_forward_sweep_degrees,
		"D-pad stance adjustment stops at its anatomical upper limits"
	)
	_expect(
		_left.get_hand_local_position(-1).x < 0.0
		and _left.get_hand_local_position(1).x > 0.0,
		"the narrowest forward stance cannot cross either hand over the centreline"
	)
	_left.set_current_arm_length(-1, _left.minimum_arm_length)
	_left.set_current_arm_length(1, _left.minimum_arm_length)
	_expect(
		is_zero_approx(_left.get_arm_forward_sweep_degrees(-1))
		and is_zero_approx(_left.get_arm_forward_sweep_degrees(1))
		and is_equal_approx(
			_left.get_elbow_flexion_degrees(1),
			_left.maximum_elbow_flexion_degrees
		),
		"full trigger removes D-pad stance influence at the authored tucked endpoint"
	)
	_left.extended_elbow_flexion_degrees = 12.0
	_left.extended_forward_sweep_degrees = 25.0

	_left.global_position = Vector2(360.0, 240.0)
	_left.linear_velocity = Vector2.ZERO
	_left.set_control_input(Vector2.RIGHT, Vector2.UP, 0.0, 0.0)
	await _wait_physics_frames(45)
	_expect(_left.global_position.x > 380.0, "LS moves its dancer in screen space independently of facing")
	_expect(_left.diagnostic_movement_force.x > 0.0, "LS right applies a rightward movement force")

	_left.global_position = Vector2(420.0, 260.0)
	_left.global_rotation = 0.0
	_left.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_left.set_control_input(Vector2.RIGHT, Vector2.RIGHT, 0.0, 0.0, true, false)
	var position_lock_origin := _left.global_position
	_left.apply_central_impulse(Vector2(45.0, -20.0))
	await _wait_physics_frames(90)
	_expect(
		_left.global_position.distance_to(position_lock_origin) < 1.0
		and _left.diagnostic_movement_force.is_zero_approx(),
		"an active L3 lock pins translation and suppresses the LS motor"
	)
	_expect(_left.global_rotation < -0.4, "an active L3 lock leaves corrected RS rotation free")

	_left.global_position = Vector2(420.0, 260.0)
	_left.global_rotation = 0.0
	_left.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_left.set_control_input(Vector2.RIGHT, Vector2.RIGHT, 0.0, 0.0, false, true)
	var rotation_lock_origin := _left.global_rotation
	_left.apply_torque_impulse(1200.0)
	await _wait_physics_frames(90)
	_expect(_left.global_position.x > 440.0, "an active R3 lock leaves LS translation free")
	_expect(
		absf(wrapf(_left.global_rotation - rotation_lock_origin, -PI, PI)) < 0.03
		and is_zero_approx(_left.diagnostic_spin_torque),
		"an active R3 lock pins orientation and suppresses the RS motor"
	)

	_left.global_position = Vector2(420.0, 260.0)
	_left.global_rotation = 0.0
	_left.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_left.set_control_input(Vector2.RIGHT, Vector2.RIGHT, 0.0, 0.0, true, true)
	var full_lock_position := _left.global_position
	var full_lock_rotation := _left.global_rotation
	_left.apply_central_impulse(Vector2(-30.0, 35.0))
	_left.apply_torque_impulse(-900.0)
	await _wait_physics_frames(90)
	_expect(
		_left.global_position.distance_to(full_lock_position) < 1.0
		and absf(wrapf(_left.global_rotation - full_lock_rotation, -PI, PI)) < 0.03,
		"active L3 and R3 locks together pin both physical axes"
	)

	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, false, false)
	_left.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0

	_prepare_far_apart()
	_connection.set_grip_button_state(_left, 1, true)
	_expect(_connection.is_hand_primed(_left, 1), "holding RB primes the black dancer's right hand")
	_expect(not _connection.has_any_connection(), "a held bumper waits when no partner hand is nearby")
	_place_hand_gap(1, 1, Vector2(45.0, 0.0))
	await _wait_physics_frames(2)
	_expect(not _connection.is_connected, "one willing hand cannot catch an unwilling partner")
	_connection.set_grip_button_state(_right, 1, true)
	await _wait_physics_frames(2)
	_expect(_connection.is_connected, "same-side willing hands can catch inside the assist radius")
	var primary_sides := _connection.get_connected_hand_sides()
	_expect(primary_sides[0] == 1, "the side-relevant RB grip owns the black dancer's right hand")
	_expect(
		not _connection.is_hand_primed(_left, primary_sides[0])
		and not _connection.is_hand_primed(_right, primary_sides[1])
		and _connection.is_grip_button_down(_left, primary_sides[0])
		and _connection.is_grip_button_down(_right, primary_sides[1]),
		"a successful catch consumes both primed states while the buttons remain down"
	)
	_expect(
		is_equal_approx(_connection.catch_radius, 54.0)
		and _connection.primary_snap_remaining > 0.0,
		"the catch begins a three-hand-width magnetic snap window"
	)

	_left.freeze = false
	_right.freeze = false
	var initial_snap_gap := _connected_gap(1)
	await _wait_physics_frames(30)
	var settled_snap_gap := _connected_gap(1)
	_expect(
		initial_snap_gap <= _connection.maximum_hand_separation + 0.1
		and settled_snap_gap <= _connection.maximum_hand_separation + 0.1,
		"a catch immediately enters the hard fingertip-tether distance"
	)
	_expect(
		_connection.primary_allowed_separation
		<= _connection.maximum_hand_separation,
		"the projected catch never authorizes separation beyond the hard tether"
	)

	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_right.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_left.angular_velocity = -0.75
	_right.angular_velocity = 0.75
	var single_tail_gap := 0.0
	var single_tail_relative_hand_speed := 0.0
	for frame in 180:
		await physics_frame
		if frame >= 120:
			single_tail_gap = maxf(single_tail_gap, _connected_gap(1))
			single_tail_relative_hand_speed = maxf(
				single_tail_relative_hand_speed,
				_connection.relative_hand_velocity
			)
	print("single neutral settle: gap=%.3f px hand_speed=%.3f px/s blend=%.3f" % [
		single_tail_gap,
		single_tail_relative_hand_speed,
		_connection.primary_elastic_blend,
	])
	_expect(
		single_tail_gap < 4.0
		and single_tail_relative_hand_speed < 5.0,
		"a slow neutral single hold settles as firm radial contact without jitter"
	)

	_left.global_rotation = 0.0
	_place_hand_gap(primary_sides[0], primary_sides[1], Vector2(0.0, -20.0))
	await _wait_physics_frames(3)
	var dorsal_gap := (
		_right.get_hand_world_position(primary_sides[1])
		- _left.get_hand_world_position(primary_sides[0])
	)
	print("single dorsal projection: component=%.3f px gap=%.3f px active=%s" % [
		dorsal_gap.dot(
			_left.get_dorsal_local_direction().rotated(_left.global_rotation)
		),
		dorsal_gap.length(),
		str(_connection.dorsal_limit_active),
	])
	_expect(
		dorsal_gap.length() > 15.0
		and dorsal_gap.length() <= _connection.maximum_hand_separation + 0.1
		and not _connection.dorsal_limit_active,
		"a hand may pass behind one dancer during an underarm-style pivot"
	)
	_left.freeze = true
	_right.freeze = true
	_left.global_rotation = 0.0
	_right.global_rotation = PI
	_right.global_position = (
		_left.get_hand_world_position(primary_sides[0])
		+ Vector2(0.0, -20.0)
		- _right.get_hand_offset(primary_sides[1])
	)
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0
	await _wait_physics_frames(1)
	var mutual_dorsal_gap := (
		_right.get_hand_world_position(primary_sides[1])
		- _left.get_hand_world_position(primary_sides[0])
	)
	_expect(
		mutual_dorsal_gap.length() <= _connection.welded_hand_separation + 0.1
		and _connection.dorsal_limit_active,
		"only dorsal-to-dorsal hand separation is fully blocked"
	)

	# One dancer may orbit and turn under the other dancer's anchored arm. The
	# single contact limits distance but owns no relative orientation.
	_left.global_position = Vector2(600.0, 360.0)
	_left.global_rotation = 0.0
	_right.global_rotation = PI
	_right.global_position = (
		_left.get_hand_world_position(primary_sides[0])
		+ Vector2(2.0, 0.0)
		- _right.get_hand_offset(primary_sides[1])
	)
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0
	_left.freeze = false
	_right.freeze = false
	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, true, false)
	_right.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	var anchored_position := _left.global_position
	var previous_orbit_angle := (
		_right.global_position - _left.global_position
	).angle()
	var orbit_travel := 0.0
	var underarm_peak_gap := 0.0
	for _frame in 180:
		var body_separation := _right.global_position - _left.global_position
		var tangent := body_separation.normalized().rotated(-PI * 0.5)
		_right.set_control_input(
			tangent,
			(-body_separation).normalized(),
			0.0,
			0.0
		)
		await physics_frame
		var orbit_angle := (
			_right.global_position - _left.global_position
		).angle()
		orbit_travel += absf(wrapf(
			orbit_angle - previous_orbit_angle,
			-PI,
			PI
		))
		previous_orbit_angle = orbit_angle
		underarm_peak_gap = maxf(underarm_peak_gap, _connected_gap(1))
	_expect(
		_connection.has_any_connection()
		and orbit_travel > 0.8
		and anchored_position.distance_to(_left.global_position) < 2.0
		and underarm_peak_gap <= _connection.maximum_hand_separation + 0.1,
		"a dancer can turn and orbit under one anchored hand without an orientation weld"
	)
	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, false, false)
	_right.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_right.set_control_input(Vector2.RIGHT, Vector2.ZERO, 0.0, 0.0)
	var guided_start := _left.global_position
	await _wait_physics_frames(45)
	_expect(
		_left.global_position.distance_to(guided_start) > 1.0
		and _left.diagnostic_movement_force.is_zero_approx()
		and is_zero_approx(_left.diagnostic_spin_torque),
		"a neutral dancer can be guided through a physical handhold"
	)
	_left.set_control_input(Vector2.LEFT, Vector2.UP, 0.0, 0.0)
	_right.set_control_input(Vector2.RIGHT, Vector2.UP, 0.0, 0.0)
	var peak_stress_gap := settled_snap_gap
	var separation_tether_activated := false
	var peak_stress_elastic_blend := 0.0
	for _frame in 180:
		await physics_frame
		peak_stress_gap = maxf(peak_stress_gap, _connected_gap(1))
		peak_stress_elastic_blend = maxf(
			peak_stress_elastic_blend,
			_connection.primary_elastic_blend
		)
		separation_tether_activated = (
			separation_tether_activated or _connection.separation_limit_active
		)
	print("single-hold stress sample: peak_gap=%.3f px blend=%.3f tether=%s" % [
		peak_stress_gap,
		peak_stress_elastic_blend,
		str(separation_tether_activated),
	])
	_expect(
		separation_tether_activated
		or peak_stress_gap <= _connection.maximum_hand_separation,
		"strong opposing LS input remains bounded before or through the firm tether"
	)
	_expect(
		peak_stress_gap <= _connection.maximum_hand_separation + 0.1,
		"the physical tether never exceeds the one-and-a-half-hand-width limit"
	)
	_expect(
		peak_stress_elastic_blend > 0.5,
		"fast separating motion shifts the live handhold toward elastic response"
	)

	_connection.set_grip_button_state(_right, primary_sides[1], false)
	_expect(
		_connection.has_any_connection()
		and _connection.is_release_tap_armed(_right, primary_sides[1]),
		"releasing a catch bumper keeps the hold latched and arms its next tap"
	)
	_connection.set_grip_button_state(_left, primary_sides[0], false)
	_expect(
		_connection.has_any_connection()
		and _connection.is_release_tap_armed(_left, primary_sides[0]),
		"both bumpers can be up while the physical handhold stays fixed"
	)
	var left_velocity_before_release := _left.linear_velocity
	var right_velocity_before_release := _right.linear_velocity
	_connection.set_grip_button_state(_right, primary_sides[1], true)
	_expect(not _connection.has_any_connection(), "a fresh tap from either endpoint releases that handhold")
	_expect(
		_left.linear_velocity.is_equal_approx(left_velocity_before_release)
		and _right.linear_velocity.is_equal_approx(right_velocity_before_release),
		"tap release preserves both dancers' momentum"
	)
	_expect(
		not _connection.is_hand_primed(_left, primary_sides[0])
		and not _connection.is_hand_primed(_right, primary_sides[1]),
		"the release tap is consumed instead of priming an immediate re-catch"
	)
	_connection.set_grip_button_state(_right, primary_sides[1], false)

	await _wait_physics_frames(50)
	await _prepare_double_hold_pose()
	var double_setup_body_distance := _left.global_position.distance_to(
		_right.global_position
	)
	print("double hold setup gaps: L-R=%.3f R-L=%.3f" % [
		_left.get_hand_world_position(-1).distance_to(_right.get_hand_world_position(1)),
		_left.get_hand_world_position(1).distance_to(_right.get_hand_world_position(-1)),
	])
	_expect(
		double_setup_body_distance
		> (
			_left.get_node("CollisionShape2D").shape.radius
			+ _right.get_node("CollisionShape2D").shape.radius
			+ 20.0
		),
		"the forward released-arm frame keeps a natural double hold clear of torso overlap"
	)
	_connection.set_grip_button_state(_left, -1, true)
	_connection.set_grip_button_state(_right, 1, true)
	_connection.set_grip_button_state(_left, 1, true)
	_connection.set_grip_button_state(_right, -1, true)
	await _wait_physics_frames(2)
	_expect(_connection.get_active_connection_count() == 2, "two mutually willing pairs create independent handholds")
	_expect(_connection.get_hold_mode() == "double", "two handholds report a double physical hold")
	_expect(
		not _left.get_collision_exceptions().has(_right)
		and not _right.get_collision_exceptions().has(_left),
		"double hold keeps the minimal torso collision as an anti-overlap guard"
	)
	_connection.set_grip_button_state(_left, -1, false)
	_connection.set_grip_button_state(_right, 1, false)
	_connection.set_grip_button_state(_left, 1, false)
	_connection.set_grip_button_state(_right, -1, false)
	_expect(
		_connection.get_active_connection_count() == 2,
		"releasing all four catch buttons leaves both handholds latched"
	)

	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_right.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = -6.0
	_right.angular_velocity = 6.0
	var neutral_peak_gap := 0.0
	var neutral_peak_gap_frame := 0
	var neutral_peak_body_distance := 0.0
	var neutral_peak_alignment_error := 0.0
	var neutral_tail_angular_error := 0.0
	var neutral_tail_relative_spin := 0.0
	var neutral_tail_orbital_speed := 0.0
	var neutral_tail_relative_hand_speed := 0.0
	var peak_joint_position_correction := 0.0
	var peak_joint_velocity_correction := 0.0
	for frame in 360:
		await physics_frame
		var current_peak_gap := maxf(_connected_gap(1), _connected_gap(2))
		if current_peak_gap > neutral_peak_gap:
			neutral_peak_gap = current_peak_gap
			neutral_peak_gap_frame = frame
			neutral_peak_body_distance = _left.global_position.distance_to(
				_right.global_position
			)
			neutral_peak_alignment_error = _connection.double_hold_alignment_error
		peak_joint_position_correction = maxf(
			peak_joint_position_correction,
			maxf(
				_connection.primary_position_correction,
				_connection.secondary_position_correction
			)
		)
		peak_joint_velocity_correction = maxf(
			peak_joint_velocity_correction,
			maxf(
				_connection.primary_velocity_correction,
				_connection.secondary_velocity_correction
			)
		)
		if frame >= 300:
			neutral_tail_angular_error = maxf(
				neutral_tail_angular_error,
				_connection.double_hold_alignment_error
			)
			neutral_tail_relative_spin = maxf(
				neutral_tail_relative_spin,
				absf(_right.angular_velocity - _left.angular_velocity)
			)
			neutral_tail_orbital_speed = maxf(
				neutral_tail_orbital_speed,
				absf(_connection.double_hold_orbital_angular_velocity)
			)
			neutral_tail_relative_hand_speed = maxf(
				neutral_tail_relative_hand_speed,
				_connection.relative_hand_velocity
			)
	print(
		"neutral double-hold settle: peak_gap=%.3f px frame=%d body_distance=%.3f px peak_alignment=%.3f rad tail_alignment=%.3f rad relative_spin=%.3f orbital=%.3f hand_speed=%.3f px/s position_correction=%.3f velocity_correction=%.3f"
		% [
			neutral_peak_gap,
			neutral_peak_gap_frame,
			neutral_peak_body_distance,
			neutral_peak_alignment_error,
			neutral_tail_angular_error,
			neutral_tail_relative_spin,
			neutral_tail_orbital_speed,
			neutral_tail_relative_hand_speed,
			peak_joint_position_correction,
			peak_joint_velocity_correction,
		]
	)
	_expect(
		peak_joint_position_correction > 0.0,
		"the hard fingertip limit corrects only an actual frame separation"
	)
	_expect(
		neutral_peak_gap <= _connection.maximum_hand_separation + 0.1,
		"counter-rotation remains inside both hand-separation limits"
	)
	_expect(
		neutral_tail_angular_error < deg_to_rad(3.0)
		and neutral_tail_relative_spin < 0.35
		and neutral_tail_relative_hand_speed < _connection.weld_speed_threshold,
		"a neutral double hold settles instead of sustaining visible jitter"
	)

	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_right.set_control_input(Vector2(-0.85, 0.53), Vector2.ZERO, 0.0, 0.0)
	var peak_double_hold_speed := 0.0
	var peak_double_hold_gap := 0.0
	for _frame in 240:
		await physics_frame
		peak_double_hold_speed = maxf(
			peak_double_hold_speed,
			maxf(_left.linear_velocity.length(), _right.linear_velocity.length())
		)
		peak_double_hold_gap = maxf(
			peak_double_hold_gap,
			maxf(_connected_gap(1), _connected_gap(2))
		)
	_expect(_left.movement_input == Vector2.ZERO and _right.movement_input.is_equal_approx(Vector2(-0.85, 0.53).normalized()), "double hold does not average or replace either player's LS input")
	_expect(_left.diagnostic_movement_force.is_zero_approx() and _right.diagnostic_movement_force.length() > 0.0, "a neutral dancer is guided by the other dancer's independent LS motor")
	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 0.0)
	_right.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	await _wait_physics_frames(60)
	_expect(_left.get_arm_flexion(-1) > 0.9 and _left.get_arm_flexion(1) < 0.1, "black dancer retains asymmetric arm control in a double hold")
	_expect(_right.get_arm_flexion(-1) < 0.1 and _right.get_arm_flexion(1) < 0.1, "white dancer's arms ignore the black dancer's trigger in a double hold")
	var coupled_primary := _connection.get_connected_hand_sides()
	var coupled_secondary := _connection.get_secondary_connected_hand_sides()
	_expect(
		absf(
			_left.get_arm_flexion(coupled_primary[0])
			- _right.get_arm_flexion(coupled_primary[1])
		) > 0.5
		or absf(
			_left.get_arm_flexion(coupled_secondary[0])
			- _right.get_arm_flexion(coupled_secondary[1])
		) > 0.5,
		"connected arm flexion remains independent across dancers"
	)
	_expect(
		_connection.get_solver_mode() == "spring"
		and _connection.primary_allowed_separation
		<= _connection.maximum_hand_separation
		and _connection.secondary_allowed_separation
		<= _connection.maximum_hand_separation,
		"a two-hand frame uses conservative independent springs inside the hard tether"
	)
	_expect(_connection.get_active_connection_count() == 2, "independent player motion does not auto-release either grip")
	_expect(_left.linear_velocity.is_finite() and _right.linear_velocity.is_finite(), "double-hold motion remains numerically finite")
	_expect(peak_double_hold_speed < 2000.0, "sustained opposing double-hold input stays below emergency velocity")
	print("double-hold stress sample: peak_gap=%.3f px peak_speed=%.3f px/s" % [
		peak_double_hold_gap,
		peak_double_hold_speed,
	])
	_expect(
		peak_double_hold_gap <= _connection.maximum_hand_separation + 0.1,
		"both connections respect the hand-separation limit throughout a double hold"
	)

	var release_primary := _connection.get_connected_hand_sides()
	var double_left_velocity := _left.linear_velocity
	var double_right_velocity := _right.linear_velocity
	_connection.set_grip_button_state(_left, release_primary[0], true)
	_expect(_connection.get_active_connection_count() == 1, "tapping one bumper leaves the other handhold intact")
	_expect(
		not _left.get_collision_exceptions().has(_right)
		and not _right.get_collision_exceptions().has(_left),
		"returning to one handhold keeps the minimal torso collision"
	)
	_expect(
		_left.linear_velocity.is_equal_approx(double_left_velocity)
		and _right.linear_velocity.is_equal_approx(double_right_velocity),
		"double-to-single release preserves the emergent motion"
	)
	_connection.set_grip_button_state(_left, release_primary[0], false)
	var release_secondary := _connection.get_secondary_connected_hand_sides()
	_connection.set_grip_button_state(_left, release_secondary[0], true)
	_expect(not _connection.has_any_connection(), "the remaining side-relevant tap releases the final hold")
	_connection.set_grip_button_state(_left, release_secondary[0], false)

	await _wait_physics_frames(30)
	_prepare_far_apart()
	_root._player_one_device = 5
	_root._player_two_device = 7
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_STICK, 5))
	_expect(
		_left.position_lock_active and not _right.position_lock_active,
		"controller one L3 toggles only the black dancer's position lock on"
	)
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_STICK, 5, false))
	_expect(
		_left.position_lock_active,
		"releasing L3 leaves the black dancer's position lock latched"
	)
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_STICK, 5))
	_expect(
		not _left.position_lock_active,
		"pressing controller one L3 again toggles its position lock off"
	)
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_STICK, 7))
	_expect(
		_right.rotation_lock_active and not _left.rotation_lock_active,
		"controller two R3 toggles only the white dancer's rotation lock on"
	)
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_STICK, 7, false))
	_expect(
		_right.rotation_lock_active,
		"releasing R3 leaves the white dancer's rotation lock latched"
	)
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_STICK, 7))
	_expect(
		not _right.rotation_lock_active,
		"pressing controller two R3 again toggles its rotation lock off"
	)
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_SHOULDER, 5))
	_expect(_connection.is_hand_primed(_left, -1), "controller one held LB primes only the black dancer's left hand")
	_expect(not _connection.is_hand_primed(_right, -1), "controller one cannot prime the white dancer's hand")
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER, 7))
	_expect(_connection.is_hand_primed(_right, 1), "controller two held RB primes only the white dancer's right hand")
	_root._input(_joy_button_event(JOY_BUTTON_LEFT_SHOULDER, 5, false))
	_root._input(_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER, 7, false))
	_expect(not _connection.is_hand_primed(_left, -1) and not _connection.is_hand_primed(_right, 1), "releasing an uncaught bumper removes that hand's priming")

	_expect(not _debug_overlay.visible and not _pause_menu.visible, "telemetry and pause menu start hidden")
	_pause_menu._pause()
	_expect(paused and _pause_menu.visible, "pause menu pauses the simulation")
	_pause_menu.telemetry_toggle.grab_focus()
	_pause_menu._input(_joy_button_event(JOY_BUTTON_A, 5))
	_expect(_debug_overlay.visible and _pause_menu.telemetry_toggle.button_pressed, "gamepad A toggles telemetry while paused")
	_expect(
		is_equal_approx(_root._apply_input_sensitivity(0.25, 2.0), 0.5)
		and is_equal_approx(_root._apply_input_sensitivity(0.25, 0.5), 0.0625),
		"input sensitivity changes response curvature without changing endpoints"
	)
	_pause_menu._input(_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER, 5))
	_expect(_pause_menu.tabs.current_tab == 1, "RB opens the tuning tab while gameplay is paused")
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
		"runtime tuning still updates both co-op dancers"
	)
	_pause_menu._resume()
	_expect(not paused and not _pause_menu.visible, "resume closes the menu and unpauses")

	# Exercise classic twin-stick steering on an isolated frozen dancer so this
	# focused probe cannot perturb the long-running handhold simulation above.
	var rs_probe := Dancer.new()
	get_root().add_child(rs_probe)
	rs_probe.freeze = true
	rs_probe.set_control_input(Vector2.ZERO, Vector2.RIGHT * 0.25, 0.0, 0.0)
	rs_probe._apply_facing_torque()
	var slight_rs_target := rs_probe.get_desired_facing_rotation()
	var slight_rs_step := rs_probe.global_rotation
	var slight_rs_target_speed := absf(rs_probe.target_angular_velocity)
	rs_probe.global_rotation = 0.0
	rs_probe.set_control_input(Vector2.ZERO, Vector2.RIGHT, 0.0, 0.0)
	rs_probe._apply_facing_torque()
	_expect(
		is_equal_approx(rs_probe.get_desired_facing_rotation(), slight_rs_target)
		and is_equal_approx(rs_probe.global_rotation, slight_rs_step)
		and is_equal_approx(
			absf(rs_probe.target_angular_velocity),
			slight_rs_target_speed
		)
		and rs_probe.facing_input.is_equal_approx(Vector2.RIGHT)
		and is_zero_approx(rs_probe.diagnostic_spin_torque),
		"partial and full RS travel at one angle produce the same inertialess turn"
	)
	_expect(
		_root._normalize_facing_stick(Vector2(0.2, -0.2)).is_equal_approx(
			Vector2(0.2, -0.2).normalized()
		)
		and _root._normalize_facing_stick(Vector2.ZERO) == Vector2.ZERO,
		"RS magnitude is discarded after the radial deadzone"
	)

	rs_probe.angular_velocity = 1.25
	rs_probe.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	var neutral_rotation := rs_probe.global_rotation
	rs_probe._apply_facing_torque()
	_expect(
		is_equal_approx(rs_probe.global_rotation, neutral_rotation)
		and is_equal_approx(rs_probe.angular_velocity, 1.25)
		and is_zero_approx(rs_probe.target_angular_velocity)
		and is_zero_approx(rs_probe.diagnostic_spin_torque),
		"centering RS stops its own turn without locking out partner-driven rotation"
	)
	rs_probe.queue_free()

	if _failures.is_empty():
		print("COOP PROTOTYPE MECHANICS: %d/%d checks passed" % [_checks, _checks])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("COOP PROTOTYPE MECHANICS: %d failure(s) across %d checks" % [_failures.size(), _checks])
		quit(1)


func _prepare_far_apart() -> void:
	_left.freeze = true
	_right.freeze = true
	_left.global_position = Vector2(320.0, 360.0)
	_right.global_position = Vector2(960.0, 360.0)
	_left.global_rotation = 0.0
	_right.global_rotation = 0.0
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0
	_left.set_control_input(Vector2.ZERO, Vector2.UP, 0.0, 0.0)
	_right.set_control_input(Vector2.ZERO, Vector2.UP, 0.0, 0.0)
	_left.set_current_arm_length(-1, _left.maximum_arm_length)
	_left.set_current_arm_length(1, _left.maximum_arm_length)
	_right.set_current_arm_length(-1, _right.maximum_arm_length)
	_right.set_current_arm_length(1, _right.maximum_arm_length)


func _place_hand_gap(hand_a_side: int, hand_b_side: int, gap: Vector2) -> void:
	_left.freeze = true
	_right.freeze = true
	_right.global_rotation = 0.0
	_right.global_position = (
		_left.get_hand_world_position(hand_a_side)
		+ gap
		- _right.get_hand_offset(hand_b_side)
	)
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0


func _prepare_double_hold_pose() -> void:
	_prepare_far_apart()
	await physics_frame
	_left.freeze = false
	_right.freeze = false
	await physics_frame
	_left.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_right.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	_set_double_hold_transform()
	await physics_frame
	_set_double_hold_transform()


func _set_double_hold_transform() -> void:
	_left.global_position = Vector2(640.0, 330.0)
	_left.global_rotation = 0.0
	_right.global_rotation = PI
	var translation_for_left_pair := (
		_left.get_hand_local_position(-1)
		- _right.get_hand_local_position(1).rotated(PI)
	)
	var translation_for_right_pair := (
		_left.get_hand_local_position(1)
		- _right.get_hand_local_position(-1).rotated(PI)
	)
	_right.global_position = _left.global_position + (
		translation_for_left_pair + translation_for_right_pair
	) * 0.5
	_left.linear_velocity = Vector2.ZERO
	_right.linear_velocity = Vector2.ZERO
	_left.angular_velocity = 0.0
	_right.angular_velocity = 0.0


func _connected_gap(slot: int) -> float:
	var sides := (
		_connection.get_connected_hand_sides()
		if slot == 1
		else _connection.get_secondary_connected_hand_sides()
	)
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
	device: int,
	pressed: bool = true
) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button_index
	event.pressed = pressed
	return event


func _arm_segments_match(dancer: Dancer) -> bool:
	for side in [-1, 1]:
		var shoulder := dancer.get_shoulder_local_position(side)
		var elbow := dancer.get_elbow_local_position(side)
		var hand := dancer.get_hand_local_position(side)
		if absf(shoulder.distance_to(elbow) - dancer.get_projected_upper_arm_length(side)) > 0.05:
			return false
		if absf(elbow.distance_to(hand) - dancer.get_projected_forearm_length(side)) > 0.05:
			return false
	return true


func _hands_are_mirrored(dancer: Dancer) -> bool:
	var left_hand := dancer.get_hand_local_position(-1)
	var right_hand := dancer.get_hand_local_position(1)
	return (
		is_equal_approx(left_hand.x, -right_hand.x)
		and is_equal_approx(left_hand.y, right_hand.y)
	)

extends SceneTree

var _root: PrototypeController
var _left: Dancer
var _right: Dancer
var _connection: HandConnection
var _failed := false
var _frame_observer: FrameObserver
var _previous_recorded_stance: Dictionary = {}


class FrameObserver extends Node:
	signal frame_completed

	func _physics_process(_delta: float) -> void:
		frame_completed.emit()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Pass one telemetry JSON path after --")
		quit(2)
		return
	var capture_path := ProjectSettings.globalize_path(arguments[0])
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(capture_path)
	)
	if not parsed is Dictionary or not parsed.has("samples"):
		push_error("Invalid telemetry capture: %s" % capture_path)
		quit(2)
		return
	var samples: Array = parsed["samples"]
	if samples.is_empty():
		push_error("Telemetry capture has no samples: %s" % capture_path)
		quit(2)
		return

	_root = load("res://prototype.tscn").instantiate()
	get_root().add_child(_root)
	_left = _root.get_node("LeftDancer")
	_right = _root.get_node("RightDancer")
	_connection = _root.get_node("HandConnection")
	_root.set_process_input(false)
	_root.set_physics_process(false)
	_root.get_node("TelemetryRecorder").process_mode = Node.PROCESS_MODE_DISABLED
	_frame_observer = FrameObserver.new()
	_frame_observer.process_physics_priority = 2000
	_root.add_child(_frame_observer)
	await process_frame
	for key in ["left_dancer", "right_dancer"]:
		var dancer: Dancer = _left if key == "left_dancer" else _right
		var configuration: Dictionary = parsed.get("configuration", {}).get(key, {})
		dancer.set_physical_weight_kg(float(configuration.get("weight_kg", 75.0)))

	_initialize_from_sample(samples[0])
	var maximum_gap := 0.0
	var maximum_settled_joint_gap := 0.0
	var settled_joint_frames := 0
	var maximum_relative_hand_speed := 0.0
	var maximum_body_speed := 0.0
	var minimum_body_distance := INF
	var maximum_position_correction := 0.0
	var geometry_limited_frames := 0
	var initial_alignment_sign := 0.0
	var changed_hold_side := false
	if _connection.get_active_connection_count() == 2:
		initial_alignment_sign = signf((_right.position - _left.position).dot(Dancer.LOCAL_FORWARD_DIRECTION.rotated(_left.rotation)))
	var maximum_absolute_spin := 0.0
	var maximum_spin_step := 0.0
	var spin_reversals := 0
	var previous_left_spin := _left.angular_velocity
	var previous_right_spin := _right.angular_velocity
	var finite_state := true

	for sample_index in samples.size() - 1:
		var sample: Dictionary = samples[sample_index]
		var next_sample: Dictionary = samples[sample_index + 1]
		_apply_recorded_input(sample)
		var frame_count := maxi(
			1,
			int(next_sample["physics_frame"]) - int(sample["physics_frame"])
		)
		for _physics_step in frame_count:
			await _frame_observer.frame_completed
			var current_gap := _maximum_connected_gap()
			maximum_gap = maxf(maximum_gap, current_gap)
			if _connection.has_any_connection() and _connection.primary_snap_remaining <= 0.0 \
					and _connection.secondary_snap_remaining <= 0.0:
				settled_joint_frames += 1
				maximum_settled_joint_gap = maxf(maximum_settled_joint_gap, current_gap)
			if _connection.get_active_connection_count() == 2:
				minimum_body_distance = minf(minimum_body_distance, _left.position.distance_to(_right.position))
				maximum_position_correction = maxf(maximum_position_correction,
					maxf(_connection.primary_position_correction, _connection.secondary_position_correction))
				if _connection.double_hold_pose_limited:
					geometry_limited_frames += 1
				changed_hold_side = changed_hold_side or initial_alignment_sign * \
					(_right.position - _left.position).dot(Dancer.LOCAL_FORWARD_DIRECTION.rotated(_left.rotation)) < 0.0
			maximum_relative_hand_speed = maxf(
				maximum_relative_hand_speed,
				_connection.relative_hand_velocity
			)
			maximum_body_speed = maxf(
				maximum_body_speed,
				maxf(_left.linear_velocity.length(), _right.linear_velocity.length())
			)
			maximum_absolute_spin = maxf(
				maximum_absolute_spin,
				maxf(absf(_left.angular_velocity), absf(_right.angular_velocity))
			)
			maximum_spin_step = maxf(
				maximum_spin_step,
				maxf(
					absf(_left.angular_velocity - previous_left_spin),
					absf(_right.angular_velocity - previous_right_spin)
				)
			)
			if (
				_left.angular_velocity * previous_left_spin < -0.25
				or _right.angular_velocity * previous_right_spin < -0.25
			):
				spin_reversals += 1
			previous_left_spin = _left.angular_velocity
			previous_right_spin = _right.angular_velocity
			finite_state = finite_state and (
				_left.global_position.is_finite()
				and _right.global_position.is_finite()
				and _left.linear_velocity.is_finite()
				and _right.linear_velocity.is_finite()
				and is_finite(_left.angular_velocity)
				and is_finite(_right.angular_velocity)
			)

	print(
		"TELEMETRY REPLAY %s solver=%s seed_gap=%.3f px settled_joint_gap=%.3f px max_hand_speed=%.3f px/s max_body_speed=%.3f px/s max_spin=%.3f rad/s max_spin_step=%.3f reversals=%d"
		% [
			capture_path.get_file(),
			_connection.get_solver_mode(),
			maximum_gap,
			maximum_settled_joint_gap,
			maximum_relative_hand_speed,
			maximum_body_speed,
			maximum_absolute_spin,
			maximum_spin_step,
			spin_reversals,
		]
	)
	_expect(finite_state, "replay remains numerically finite")
	if arguments.has("--check-pose-limits"):
		print("POSE REPLAY minimum_distance=%.4f max_correction=%.4f limited_frames=%d changed_hold_side=%s" % [
			minimum_body_distance, maximum_position_correction, geometry_limited_frames, changed_hold_side])
		_expect(minimum_body_distance >= 40.0, "pose replay retains torso clearance")
		_expect(not changed_hold_side, "pose replay does not switch front/rear hold")
		_expect(_connection.get_active_connection_count() == 2, "pose replay retains both holds")
		_expect(geometry_limited_frames > 0, "pose replay reaches and respects the geometry limit")
	_expect(
		settled_joint_frames == 0 or maximum_settled_joint_gap <= 0.25,
		"every replayed handhold settles to rigid fingertip contact"
	)
	_expect(maximum_body_speed < 2000.0, "replay avoids emergency body velocity")
	_expect(maximum_absolute_spin < 30.0, "replay avoids wild angular velocity")
	quit(1 if _failed else 0)


func _initialize_from_sample(sample: Dictionary) -> void:
	_left.freeze = true
	_right.freeze = true
	_apply_dancer_state(_left, sample["left_dancer"])
	_apply_dancer_state(_right, sample["right_dancer"])
	var hold: Dictionary = sample["hand_connection"]
	_connection.is_connected = bool(hold["connected"])
	_connection.is_secondary_connected = bool(hold["secondary_connected"])
	_connection._connected_hand_a = int(hold["left_dancer_hand_side"])
	_connection._connected_hand_b = int(hold["right_dancer_hand_side"])
	_connection._secondary_hand_a = int(hold["secondary_left_dancer_hand_side"])
	_connection._secondary_hand_b = int(hold["secondary_right_dancer_hand_side"])
	_connection.primary_snap_remaining = 0.0
	_connection.secondary_snap_remaining = 0.0
	_connection.primary_acquisition_progress = 1.0 if _connection.is_connected else 0.0
	_connection.secondary_acquisition_progress = (
		1.0 if _connection.is_secondary_connected else 0.0
	)
	_initialize_endpoint_state(_left, 1, sample["left_dancer"])
	_initialize_endpoint_state(_right, 2, sample["right_dancer"])
	_connection._update_dancer_collision_exception()
	_left.freeze = false
	_right.freeze = false
	_apply_recorded_input(sample)


func _apply_dancer_state(dancer: Dancer, state: Dictionary) -> void:
	dancer.global_position = _vector_from_json(state["position"])
	dancer.global_rotation = float(state["rotation_radians"])
	dancer._update_unwrapped_rotation()
	dancer.linear_velocity = _vector_from_json(state["linear_velocity"])
	dancer.angular_velocity = float(state["angular_velocity"])
	var arms: Dictionary = state["arms"]
	dancer.extended_elbow_flexion_degrees = float(
		arms["extended_stance"]["elbow_flexion_degrees"]
	)
	dancer.extended_forward_sweep_degrees = float(
		arms["extended_stance"]["forward_sweep_degrees"]
	)
	dancer.set_current_arm_length(-1, float(arms["left"]["current_length"]))
	dancer.set_current_arm_length(1, float(arms["right"]["current_length"]))


func _initialize_endpoint_state(
	dancer: Dancer,
	endpoint: int,
	state: Dictionary
) -> void:
	for side in [-1, 1]:
		var hand_name := "left" if side < 0 else "right"
		var hand: Dictionary = state["hands"][hand_name]
		_connection._set_button_down(endpoint, side, bool(hand["button_down"]))
		_connection._set_grip(endpoint, side, bool(hand["primed"]))
		_connection._set_release_tap_armed(
			endpoint,
			side,
			bool(hand["release_tap_armed"])
		)


func _apply_recorded_input(sample: Dictionary) -> void:
	_apply_dancer_input(_left, sample["left_dancer"])
	_apply_dancer_input(_right, sample["right_dancer"])
	_apply_recorded_buttons(_left, sample["left_dancer"])
	_apply_recorded_buttons(_right, sample["right_dancer"])


func _apply_dancer_input(dancer: Dancer, state: Dictionary) -> void:
	if state.has("weight_kg"):
		dancer.set_physical_weight_kg(float(state["weight_kg"]))
	if state.has("fit_weight_kg"):
		dancer.set_fit_weight_kg(float(state["fit_weight_kg"]))
	var input: Dictionary = state["input"]
	var arms: Dictionary = state["arms"]
	var stance := Vector2(float(arms["extended_stance"]["elbow_flexion_degrees"]),
		float(arms["extended_stance"]["forward_sweep_degrees"]))
	if OS.get_cmdline_user_args().has("--stance-deltas"):
		# Old captures have achieved stance angles, not raw D-pad buttons. Replay
		# their changes as requests; absolute angles would overwrite the new limit
		# and hide the player's immediate reversal behind rejected angle history.
		var previous: Vector2 = _previous_recorded_stance.get(dancer, stance)
		dancer.extended_elbow_flexion_degrees += stance.x - previous.x
		dancer.extended_forward_sweep_degrees += stance.y - previous.y
		_previous_recorded_stance[dancer] = stance
	else:
		dancer.extended_elbow_flexion_degrees = stance.x
		dancer.extended_forward_sweep_degrees = stance.y
	dancer.set_control_input(
		_vector_from_json(input["movement"]),
		_vector_from_json(input["facing"]),
		float(input["left_trigger"]),
		float(input["right_trigger"]),
		bool(input["position_lock"]),
		bool(input["rotation_lock"])
	)


func _apply_recorded_buttons(dancer: Dancer, state: Dictionary) -> void:
	for side in [-1, 1]:
		var hand_name := "left" if side < 0 else "right"
		_connection.set_grip_button_state(
			dancer,
			side,
			bool(state["hands"][hand_name]["button_down"])
		)


func _maximum_connected_gap() -> float:
	var result := 0.0
	if _connection.is_connected:
		var sides := _connection.get_connected_hand_sides()
		result = maxf(
			result,
			_left.get_hand_world_position(sides[0]).distance_to(
				_right.get_hand_world_position(sides[1])
			)
		)
	if _connection.is_secondary_connected:
		var sides := _connection.get_secondary_connected_hand_sides()
		result = maxf(
			result,
			_left.get_hand_world_position(sides[0]).distance_to(
				_right.get_hand_world_position(sides[1])
			)
		)
	return result


func _vector_from_json(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _expect(condition: bool, description: String) -> void:
	if condition:
		return
	_failed = true
	push_error(description)

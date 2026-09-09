extends SceneTree

var _failures: Array[String] = []
var _checks := 0
var _root: PrototypeController
var _recorder: TelemetryRecorder
var _pause_menu: PauseMenu


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root = load("res://prototype.tscn").instantiate()
	get_root().add_child(_root)
	_recorder = _root.get_node("TelemetryRecorder")
	_pause_menu = _root.get_node("PauseMenu")

	_expect(_recorder.capture_duration_seconds == 12.0, "capture keeps twelve seconds")
	_expect(_recorder.sample_rate_hz == 60.0, "capture samples at sixty hertz")
	_expect(_recorder.get_max_samples() == 720, "rolling buffer is capped at 720 samples")
	_expect(_recorder.capture_directory == "res://diagnostics", "captures target the project diagnostics folder")
	_expect(
		_recorder.left_dancer == _root.get_node("LeftDancer")
		and _recorder.right_dancer == _root.get_node("RightDancer")
		and _recorder.hand_connection == _root.get_node("HandConnection"),
		"recorder is wired to both dancers and the hand connection"
	)
	_expect(_pause_menu.telemetry_recorder == _recorder, "pause menu is wired to the recorder")

	_recorder.clear()
	await _wait_physics_frames(12)
	_expect(
		_recorder.get_sample_count() >= 5 and _recorder.get_sample_count() <= 7,
		"recorder continuously samples gameplay near sixty hertz"
	)

	_recorder.clear()
	for sample_id in 721:
		_recorder.append_sample({"id": sample_id})
	_expect(_recorder.get_sample_count() == 720, "old samples are discarded")
	_expect(int(_recorder.get_samples()[0]["id"]) == 1, "the most recent rolling window is retained")

	_recorder.clear()
	var left: Dancer = _root.get_node("LeftDancer")
	left.set_control_input(Vector2(0.25, -0.75), Vector2.RIGHT, 0.6, 0.2, true, false)
	left.diagnostic_movement_force = Vector2(225.0, -675.0)
	left.diagnostic_spin_torque = 1234.0
	left.diagnostic_position_lock_force = Vector2(-45.0, 12.0)
	left.extended_elbow_flexion_degrees = 23.0
	left.extended_forward_sweep_degrees = 15.0
	_recorder.hand_connection.set_grip_button_state(left, -1, true)
	_recorder.record_current_sample()
	var sample: Dictionary = _recorder.get_samples()[0]
	_expect(sample.has("left_dancer") and sample.has("right_dancer"), "each sample contains both dancers")
	_expect(sample.has("pair") and sample.has("hand_connection"), "each sample contains pair and connection state")
	_expect(
		sample["hand_connection"].has("connection_count")
		and sample["hand_connection"].has("hold_mode")
		and sample["hand_connection"].has("primary_snap_remaining")
		and sample["hand_connection"].has("secondary_snap_remaining")
		and sample["hand_connection"].has("primary_acquisition_progress")
		and sample["hand_connection"].has("secondary_acquisition_progress")
		and sample["hand_connection"].has("primary_hand_separation")
		and sample["hand_connection"].has("secondary_hand_separation")
		and sample["hand_connection"].has("primary_allowed_separation")
		and sample["hand_connection"].has("secondary_allowed_separation")
		and sample["hand_connection"].has("primary_position_correction")
		and sample["hand_connection"].has("secondary_position_correction")
		and sample["hand_connection"].has("primary_velocity_correction")
		and sample["hand_connection"].has("secondary_velocity_correction")
		and sample["hand_connection"].has("double_hold_orbital_angular_velocity")
		and sample["hand_connection"].has("double_hold_alignment_error")
		and sample["hand_connection"].has("double_hold_primary_permission")
		and sample["hand_connection"].has("double_hold_maximum_effort")
		and sample["hand_connection"]["solver_mode"] == "joint",
		"connection samples identify the all-rigid joint solver"
	)
	_expect(sample["left_dancer"]["input"]["movement"] == [0.25, -0.75], "effective LS input is recorded")
	_expect(sample["left_dancer"]["input"]["facing"] == [1.0, 0.0], "effective RS facing input is recorded")
	_expect(sample["left_dancer"]["facing_dial"]["active"]
		and sample["left_dancer"]["facing_dial"]["response_scale"] == 1.0
		and not sample["left_dancer"]["facing_dial"].has("pending_rotation_radians"),
		"RS telemetry records radial heading authority without queued turns")
	_expect(sample["left_dancer"]["fit_weight_kg"] == 75.0
		and sample["left_dancer"]["visual_weight_gain_kg"] == 0.0
		and sample["left_dancer"]["arms"]["left"].has("hand_roll_radians"),
		"samples record fit-relative appearance and achieved palm roll")
	_expect(
		float(sample["left_dancer"]["input"]["left_trigger"]) == 0.6
		and float(sample["left_dancer"]["input"]["right_trigger"]) == 0.2,
		"independent LT and RT inputs are recorded"
	)
	_expect(
		sample["left_dancer"]["input"]["position_lock"]
		and not sample["left_dancer"]["input"]["rotation_lock"],
		"active L3 and R3 toggle state is recorded"
	)
	_expect(sample["left_dancer"]["applied"]["movement_force"] == [225.0, -675.0], "applied movement force is recorded")
	_expect(float(sample["left_dancer"]["applied"]["turn_torque"]) == 1234.0, "applied facing torque is recorded")
	_expect(
		sample["left_dancer"]["applied"]["position_lock_force"] == [-45.0, 12.0]
		and sample["left_dancer"]["applied"].has("rotation_lock_torque"),
		"physical lock force and torque are recorded"
	)
	_expect(
		sample["left_dancer"]["arms"].has("left")
		and sample["left_dancer"]["arms"].has("right")
		and sample["left_dancer"]["arms"].has("extended_stance")
		and sample["left_dancer"]["arms"]["left"].has("double_hold_effort")
		and not sample["left_dancer"]["arms"]["left"].has("connected_flexion_target")
		and float(sample["left_dancer"]["arms"]["extended_stance"]["elbow_flexion_degrees"]) == 23.0
		and float(sample["left_dancer"]["arms"]["extended_stance"]["forward_sweep_degrees"]) == 15.0,
		"telemetry keeps separate arms and the shared D-pad stance"
	)
	_expect(
		sample["left_dancer"]["hands"]["left"]["button_down"]
		and sample["left_dancer"]["hands"]["left"]["primed"]
		and sample["left_dancer"]["hands"]["left"].has("release_tap_armed"),
		"each hand sample separates its button, priming, and release-tap state"
	)

	var payload: Dictionary = _recorder.build_capture_payload("automated_test")
	_expect(payload["schema"] == "dancers-coop-telemetry-v11", "payload uses the versioned co-op schema")
	_expect(int(payload["sample_count"]) == 1, "payload reports its sample count")
	_expect(payload["configuration"].has("controller"), "payload includes exact controller tuning")
	_expect(payload["configuration"]["controller"]["man_fit_weight_kg"] == 75.0
		and payload["configuration"]["controller"]["woman_fit_weight_kg"] == 75.0
		and payload["configuration"]["left_dancer"]["maximum_visual_weight_gain_kg"] == 30.0
		and payload["configuration"]["hand_connection"]["double_hold_body_clearance"]
		and payload["configuration"]["hand_connection"]["minimum_double_hold_body_distance"] == 40.0
		and payload["configuration"]["left_dancer"]["facing_mode"] == "radial_heading_response",
		"configuration identifies the combined rigid, radial RS and fit-weight behavior")
	_expect(
		payload["configuration"]["controller"].has("preferred_player_one_device")
		and payload["configuration"]["controller"].has("preferred_player_two_device")
		and payload["configuration"]["controller"].has("assigned_player_one_device")
		and payload["configuration"]["controller"].has("assigned_player_two_device"),
		"payload records preferred and live two-controller assignments"
	)
	_expect(
		payload["configuration"]["controller"].has("trigger_sensitivity")
		and payload["configuration"]["controller"].has("stick_sensitivity")
		and payload["configuration"]["controller"].has("man_weight_kg")
		and payload["configuration"]["controller"].has("woman_weight_kg")
		and not payload["configuration"]["controller"].has("spin_speed_scale"),
		"payload includes sensitivity and kilogram tuning without obsolete speed scales"
	)
	_expect(payload["configuration"].has("hand_connection"), "payload includes exact connection tuning")
	_expect(
		payload["configuration"]["left_dancer"].has("position_lock_stiffness")
		and payload["configuration"]["left_dancer"].has("rotation_lock_stiffness")
		and float(payload["configuration"]["left_dancer"]["weight_kg"]) == 75.0,
		"capture includes physical locks and real-world dancer weight"
	)
	_expect(
		payload["configuration"]["left_dancer"].has("minimum_extended_elbow_flexion_degrees")
		and payload["configuration"]["left_dancer"].has("maximum_extended_forward_sweep_degrees")
		and payload["configuration"]["left_dancer"].has("arm_stance_adjustment_rate_degrees"),
		"capture includes anatomical D-pad stance limits and adjustment rate"
	)
	_expect(
		float(payload["configuration"]["hand_connection"]["catch_radius"]) == 54.0
		and float(payload["configuration"]["hand_connection"]["snap_duration"]) == 0.22
		and int(payload["configuration"]["hand_connection"]["rigid_position_iterations"]) == 32
		and int(payload["configuration"]["hand_connection"]["rigid_velocity_iterations"]) == 6,
		"capture records the smooth acquisition and rigid joint solver"
	)
	_expect(
		not payload["configuration"]["hand_connection"].has("weld_speed_threshold")
		and not payload["configuration"]["hand_connection"].has("elastic_speed_threshold")
		and not payload["configuration"]["hand_connection"].has("maximum_hand_separation")
		and payload["configuration"]["hand_connection"].has("rigid_span_tolerance")
		and payload["configuration"]["hand_connection"]["solver_mode"] == "joint",
		"capture contains no spring or elastic hold tuning"
	)
	_expect(
		not payload["configuration"]["hand_connection"].has("closed_hold_minimum_body_distance"),
		"the removed automatic closed-hold frame is absent from telemetry"
	)

	_pause_menu._pause()
	_pause_menu.save_telemetry_button.grab_focus()
	_pause_menu._input(_joy_button_event(JOY_BUTTON_A))
	var saved_path: String = _recorder.last_capture_path
	var expected_directory := ProjectSettings.globalize_path("res://diagnostics")
	_expect(not saved_path.is_empty(), "gamepad A on the pause action saves a capture")
	_expect(saved_path.begins_with(expected_directory), "saved JSON stays inside the project")
	_expect(FileAccess.file_exists(saved_path), "saved JSON exists on disk")
	_expect(_pause_menu.capture_status.visible, "the pause menu reports the save result")
	await process_frame
	if FileAccess.file_exists(saved_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
		_expect(parsed is Dictionary, "saved capture is valid JSON")
		if parsed is Dictionary:
			_expect(parsed["schema"] == "dancers-coop-telemetry-v11", "saved JSON retains the co-op schema")
			_expect(int(parsed["sample_count"]) >= 1, "saved JSON contains telemetry samples")
		DirAccess.remove_absolute(saved_path)
	_pause_menu._resume()

	if _failures.is_empty():
		print("COOP TELEMETRY RECORDER: %d/%d checks passed" % [_checks, _checks])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("COOP TELEMETRY RECORDER: %d failure(s) across %d checks" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _joy_button_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event

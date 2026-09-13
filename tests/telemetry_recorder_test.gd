extends SceneTree

const TelemetryRecorderScript = preload("res://telemetry_recorder.gd")

var _failures: Array[String] = []
var _checks := 0
var _root: PrototypeController
var _recorder: Node
var _pause_menu: PauseMenu


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root = load("res://prototype.tscn").instantiate()
	get_root().add_child(_root)
	_recorder = _root.get_node("TelemetryRecorder")
	_pause_menu = _root.get_node("PauseMenu")

	_expect(
		_recorder.capture_duration_seconds == 12.0,
		"capture keeps twelve seconds"
	)
	_expect(_recorder.sample_rate_hz == 60.0, "capture samples at sixty hertz")
	_expect(
		_recorder.get_max_samples() == 720,
		"rolling buffer is capped at 720 samples"
	)
	_expect(
		_recorder.capture_directory == "res://diagnostics",
		"captures target the project diagnostics folder"
	)
	_expect(
		_recorder.left_dancer == _root.get_node("LeftDancer")
		and _recorder.right_dancer == _root.get_node("RightDancer")
		and _recorder.hand_connection == _root.get_node("HandConnection")
		and _recorder.controller == _root,
		"recorder is wired to the dancers, joint, and controller"
	)
	_expect(
		_pause_menu.telemetry_recorder == _recorder,
		"pause menu is wired to the recorder"
	)

	_recorder.clear()
	await _wait_physics_frames(12)
	_expect(
		_recorder.get_sample_count() >= 5
		and _recorder.get_sample_count() <= 7,
		"recorder samples gameplay near sixty hertz"
	)

	_recorder.clear()
	for sample_id in 721:
		_recorder.append_sample({"id": sample_id})
	_expect(_recorder.get_sample_count() == 720, "old samples are discarded")
	_expect(
		int(_recorder.get_samples()[0]["id"]) == 1,
		"the most recent rolling window is retained"
	)

	_recorder.clear()
	var left: Dancer = _root.get_node("LeftDancer")
	left.set_control_input(Vector2(0.25, -0.75), 0.6)
	left.diagnostic_movement_force = Vector2(225.0, -675.0)
	left.diagnostic_spin_torque = 1234.0
	_recorder.record_current_sample()
	var sample: Dictionary = _recorder.get_samples()[0]
	_expect(
		sample.has("left_dancer") and sample.has("right_dancer"),
		"each sample contains both dancers"
	)
	_expect(
		sample.has("pair") and sample.has("hand_connection"),
		"each sample contains pair and joint state"
	)
	_expect(
		sample["left_dancer"]["input"]["movement"] == [0.25, -0.75],
		"effective movement input is recorded"
	)
	_expect(
		float(sample["left_dancer"]["input"]["left_trigger"]) == 0.6
		and float(sample["left_dancer"]["input"]["right_trigger"]) == 0.6,
		"the single-player trigger mapping records both physical arms"
	)
	_expect(
		sample["left_dancer"]["applied"]["movement_force"]
		== [225.0, -675.0],
		"applied movement force is recorded"
	)
	_expect(
		float(sample["left_dancer"]["applied"]["spin_torque"]) == 1234.0,
		"applied spin torque is recorded"
	)
	_expect(
		sample["hand_connection"]["solver_mode"] == "joint"
		and sample["hand_connection"].has("primary_acquisition_progress")
		and sample["hand_connection"].has("primary_hand_separation")
		and sample["hand_connection"].has("primary_allowed_separation")
		and sample["hand_connection"].has("primary_position_correction")
		and sample["hand_connection"].has("primary_velocity_correction"),
		"connection samples expose the migrated joint response"
	)
	_expect(
		sample["left_dancer"]["hands"]["left"].has("button_down")
		and sample["left_dancer"]["hands"]["left"].has("primed")
		and sample["left_dancer"]["hands"]["left"].has("release_tap_armed"),
		"per-hand telemetry exposes bumper grip state"
	)

	var payload: Dictionary = _recorder.build_capture_payload("automated_test")
	_expect(
		payload["schema"] == "dancers-single-controller-telemetry-v2",
		"payload uses the versioned single-controller schema"
	)
	_expect(int(payload["sample_count"]) == 1, "payload reports its sample count")
	_expect(
		payload["configuration"].has("controller"),
		"payload includes exact controller tuning"
	)
	var controller_config: Dictionary = payload["configuration"]["controller"]
	_expect(
		controller_config["left_stick_dancer"] == "left"
		and controller_config["right_stick_dancer"] == "right"
		and controller_config["left_trigger_dancer"] == "left"
		and controller_config["right_trigger_dancer"] == "right"
		and controller_config["left_bumper_dancer"] == "left"
		and controller_config["right_bumper_dancer"] == "right"
		and controller_config["left_stick_button_spin_toggle"] == "left"
		and controller_config["right_stick_button_spin_toggle"] == "right"
		and controller_config["spin_requires_trigger"],
		"payload records the single-controller ownership map"
	)
	_expect(
		controller_config.has("spin_speed_scale")
		and controller_config.has("move_speed_scale")
		and controller_config.has("spin_move_ratio")
		and controller_config.has("trigger_sensitivity")
		and controller_config.has("stick_sensitivity"),
		"payload includes all live tuning controls"
	)
	var hand_config: Dictionary = payload["configuration"]["hand_connection"]
	_expect(
		is_equal_approx(float(hand_config["snap_duration"]), 0.22),
		"capture records the smooth acquisition duration"
	)
	_expect(
		hand_config["solver_mode"] == "joint"
		and hand_config.has("rigid_position_iterations")
		and hand_config.has("rigid_velocity_iterations"),
		"capture records the joint solver and response constants"
	)
	_expect(
		int(payload["configuration"]["left_dancer"]["intended_spin_direction"])
		== 1
		and int(
			payload["configuration"]["right_dancer"]["intended_spin_direction"]
		) == -1,
		"capture records each dancer's selected spin direction"
	)

	_pause_menu._pause()
	_pause_menu.save_telemetry_button.grab_focus()
	_pause_menu._input(_joy_button_event(JOY_BUTTON_A))
	var saved_path: String = _recorder.last_capture_path
	var expected_directory := ProjectSettings.globalize_path("res://diagnostics")
	_expect(
		not saved_path.is_empty(),
		"gamepad A on the pause action saves a capture"
	)
	_expect(
		saved_path.begins_with(expected_directory),
		"saved JSON stays inside the project"
	)
	_expect(FileAccess.file_exists(saved_path), "saved JSON exists on disk")
	_expect(
		_pause_menu.capture_status.visible,
		"the pause menu reports the save result"
	)
	await process_frame
	if FileAccess.file_exists(saved_path):
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(saved_path)
		)
		_expect(parsed is Dictionary, "saved capture is valid JSON")
		if parsed is Dictionary:
			_expect(
				parsed["schema"]
				== "dancers-single-controller-telemetry-v2",
				"saved JSON retains the schema"
			)
			_expect(
				int(parsed["sample_count"]) >= 1,
				"saved JSON contains telemetry samples"
			)
		DirAccess.remove_absolute(saved_path)
	_pause_menu._resume()

	if _failures.is_empty():
		print(
			"TELEMETRY RECORDER: %d/%d checks passed"
			% [_checks, _checks]
		)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print(
			"TELEMETRY RECORDER: %d failure(s) across %d checks"
			% [_failures.size(), _checks]
		)
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

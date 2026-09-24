extends SceneTree

var checks := 0
var failures := 0
var scene: PrototypeController
var a: Dancer
var b: Dancer
var hold: HandConnection
var controls: SinglePlayerControls
var observer: FrameObserver

class FrameObserver extends Node:
	signal completed
	func _physics_process(_delta: float) -> void:
		completed.emit()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	a = scene.left_dancer
	b = scene.right_dancer
	hold = scene.hand_connection
	controls = scene.single_controls
	observer = FrameObserver.new()
	observer.process_physics_priority = 2000
	scene.add_child(observer)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	await process_frame
	_check(paused and menu.entrance.single_player_button.visible and menu.entrance.dance_button.visible, "title offers both modes")
	menu.entrance.single_player_button.pressed.emit()
	_check(scene.is_single_player() and not paused, "Single player starts one-controller mode")
	_check(a.single_player_spin and b.single_player_spin, "both dancers use trigger spin")
	_check(a.intended_spin_direction == 1 and b.intended_spin_direction == -1, "original opposite spin defaults")
	_check(a.get_node("CollisionShape2D").shape.radius == 12.0 and b.get_node("CollisionShape2D").shape.radius == 12.0, "single colliders preserved")
	_check(b.shoulder_half_width == 16.0 and b.upper_arm_length == 38.5, "single partner dimensions preserved")
	_check(not menu.tabs.is_tab_hidden(3) and menu.single_tuning_sliders[0].visible, "single UI exposes its tuning and figures")
	scene.figure_demonstration.set_demonstration_visible(true)
	_check(scene.figure_demonstration.visible and scene.figure_demonstration is SingleFigureDemonstration, "single mode activates its own demonstrations")
	menu._pause()
	menu.tabs.current_tab = 2
	menu._switch_tab(1)
	_check(menu.tabs.current_tab == 3, "forward tab navigation reaches figures")
	menu._switch_tab(-1)
	_check(menu.tabs.current_tab == 2, "reverse tab navigation returns from figures")
	var fits := true
	for index in menu.tabs.get_tab_count():
		if menu.tabs.is_tab_hidden(index):
			continue
		menu.tabs.current_tab = index
		for frame in 3:
			await process_frame
		fits = fits and root.get_visible_rect().grow(1).encloses(menu.get_node("Center/Panel").get_global_rect())
	_check(fits, "all single-player panels fit the viewport")
	_check(root.get_visible_rect().encloses(menu.entrance.single_player_button.get_global_rect())
		and root.get_visible_rect().encloses(menu.entrance.connection_label.get_global_rect()), "title mode choices and controller status fit")
	menu._resume()
	# Enter confirms menus and also contracts white arms during keyboard play.
	Input.parse_input_event(_key(KEY_ENTER, true))
	Input.flush_buffered_events()
	scene.rearm_controls()
	scene._apply_single_player_input(1.0 / 120.0)
	_check(b.right_trigger_value == 0.0, "held menu Enter does not start spinning the white dancer")
	Input.parse_input_event(_key(KEY_ENTER, false))
	Input.flush_buffered_events()
	scene._apply_single_player_input(1.0 / 120.0)
	Input.parse_input_event(_key(KEY_ENTER, true))
	Input.flush_buffered_events()
	scene._apply_single_player_input(1.0 / 120.0)
	_check(b.right_trigger_value == 1.0, "fresh gameplay Enter contracts the white dancer")
	Input.parse_input_event(_key(KEY_ENTER, false))
	Input.flush_buffered_events()
	controls.apply_steering(a, b, Vector2.RIGHT, Vector2.UP, 0.25, 0.75)
	_check(a.movement_input == Vector2.RIGHT and b.movement_input == Vector2.UP, "sticks independently move both dancers")
	_check(a.left_trigger_value == 0.25 and a.right_trigger_value == 0.25 and b.left_trigger_value == 0.75 and b.right_trigger_value == 0.75, "each trigger operates both arms of its dancer")
	_check(not a.facing_dial_active and not b.facing_dial_active, "single steering never activates heading dial")
	scene._player_one_device = 42
	scene._input(_button(JOY_BUTTON_LEFT_STICK, 43))
	_check(a.intended_spin_direction == 1, "second controller cannot reverse single spin")
	scene._input(_button(JOY_BUTTON_LEFT_STICK, 42))
	scene._input(_button(JOY_BUTTON_RIGHT_STICK, 42))
	_check(a.intended_spin_direction == -1 and b.intended_spin_direction == 1, "stick clicks independently reverse spin")
	scene._input(_button(JOY_BUTTON_LEFT_STICK, 42, false))
	_check(a.intended_spin_direction == -1 and not a.position_lock_active and not b.rotation_lock_active, "button release does not reverse or lock")
	for first in 2:
		await _test_bumpers(first)
	await _test_spin_and_momentum()
	_test_waiting_and_limits()
	_test_mode_reset(menu)
	paused = false
	scene.queue_free()
	await process_frame
	await process_frame
	print("SINGLE PLAYER MODE: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _fixture() -> void:
	scene.start_session(PrototypeController.PlayMode.SINGLE)
	controls.update_hands(hold, false, false)
	a.reset_to_pose(Vector2(500, 350), 0.0)
	b.reset_to_pose(a.position + a.get_hand_local_position(1) - b.get_hand_local_position(-1).rotated(PI), PI)


func _press(bumper: int, pressed: bool = true) -> void:
	controls.update_hands(hold, pressed and bumper == 0, pressed and bumper == 1)


func _test_bumpers(first: int) -> void:
	_fixture()
	_press(first)
	_check(hold.get_active_connection_count() == 1 and controls.owned_slots[first] == 1, "either bumper alone can create first hold")
	for frame in 40:
		_press(first)
		await observer.completed
	_check(hold.get_active_connection_count() == 1, "holding catch bumper never adds or toggles another connection")
	_press(first, false)
	_check(hold.is_connected, "button-up leaves the catch latched")
	_press(1 - first)
	for frame in 40:
		await observer.completed
	_check(hold.get_active_connection_count() == 2, "other bumper can add a stable second connection")
	_check(controls.owned_slots[first] == 1 and controls.owned_slots[1 - first] == 2, "bumper ownership records both connections")
	_check(hold.primary_hand_separation < 0.1 and hold.secondary_hand_separation < 0.1, "shared solver closes both single-player handholds")
	_press(1 - first, false)
	_press(first)
	_check(not hold.is_connected and hold.is_secondary_connected, "original bumper releases only its own connection")
	_check(controls.owned_slots[1 - first] == 2, "remaining connection keeps its original bumper")
	for frame in 48:
		_press(first)
		await observer.completed
	_check(hold.get_active_connection_count() == 1, "held release cannot recatch after cooldown")
	_press(first, false)
	_press(first)
	_check(hold.is_connected and hold.is_secondary_connected and controls.owned_slots[first] == 1, "fresh press can recatch without renumbering other hold")
	_press(first, false)
	_press(1 - first)
	_check(hold.is_connected and not hold.is_secondary_connected, "second bumper independently releases second connection")
	_press(1 - first, false)
	var velocity_a := Vector2(30, -10)
	var velocity_b := Vector2(-20, 40)
	a.linear_velocity = velocity_a
	b.linear_velocity = velocity_b
	a.angular_velocity = 1.5
	b.angular_velocity = -2.0
	_press(first)
	_check(not hold.has_any_connection(), "original bumper releases remaining hold")
	_check(a.linear_velocity == velocity_a and b.linear_velocity == velocity_b and a.angular_velocity == 1.5 and b.angular_velocity == -2.0, "bumper release changes no linear or angular velocity")


func _test_spin_and_momentum() -> void:
	_fixture()
	controls.apply_steering(a, b, Vector2.ZERO, Vector2.ZERO, 0.8, 0.8)
	# Physical free-spin test, away from contacts.
	a.position = Vector2(300, 350)
	b.position = Vector2(980, 350)
	for frame in 90:
		await observer.completed
	_check(a.angular_velocity > 2.0 and b.angular_velocity < -2.0, "triggers physically spin the dancers in selected directions")
	_check(a.get_controlled_hand_velocity(1) == Vector2.ZERO, "trigger spin is not double-counted as heading motion")
	controls.apply_steering(a, b, Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	for frame in 90:
		await observer.completed
	_check(absf(a.angular_velocity) < 0.1 and absf(b.angular_velocity) < 0.1, "released triggers retain original spin braking")
	# Exercise simultaneous independent triggers and D-pad against a double hold.
	_fixture()
	_press(0)
	_press(0, false)
	_press(1)
	_press(1, false)
	var peak_gap := 0.0
	var finite_state := true
	for frame in 600:
		var phase := int(frame / 120)
		var lt: float = [0.0, 1.0, 0.3, 0.9, 0.0][phase]
		var rt: float = [0.0, 0.2, 1.0, 0.9, 0.0][phase]
		controls.apply_steering(a, b, Vector2.RIGHT * 0.15, Vector2.LEFT * 0.15, lt, rt)
		if frame == 300:
			a.reverse_spin()
		if phase == 3:
			scene._apply_arm_pose_inputs(Vector2.ONE, Vector2.ONE, 1.0 / 120.0)
		await observer.completed
		if frame > 40:
			peak_gap = maxf(peak_gap, maxf(hold.primary_hand_separation, hold.secondary_hand_separation))
		finite_state = finite_state and a.position.is_finite() and b.position.is_finite() and a.linear_velocity.is_finite() and b.linear_velocity.is_finite()
	_check(hold.get_active_connection_count() == 2 and finite_state, "two holds survive unequal trigger input, reversal and stance adjustment")
	_check(peak_gap < 0.1, "single two-hand stress stays within joint tolerance")
	print("single double-hold peak gap=%.5f" % peak_gap)
	# A physical spin transmits actual travel before the bumper release.
	_fixture()
	_press(0)
	_press(0, false)
	controls.apply_steering(a, b, Vector2.ZERO, Vector2.ZERO, 0.6, 0.0)
	for frame in 100:
		await observer.completed
	var speed := b.linear_velocity.length()
	var direction := b.linear_velocity.normalized()
	var before := b.position
	_press(0)
	a.add_collision_exception_with(b)
	b.add_collision_exception_with(a)
	for frame in 24:
		await observer.completed
	_check(speed > 5.0 and (b.position - before).dot(direction) > 0.5, "partner-transmitted spin produces post-release travel")
	_check(b.partner_carry_velocity.length() > 0.0, "single-player release uses shared partner carry")


func _test_waiting_and_limits() -> void:
	_fixture()
	b.position = Vector2(1100, 350)
	_press(1)
	_check(not hold.has_any_connection() and hold.shared_catch_waiting, "out-of-range bumper waits instead of snapping across ballroom")
	b.position = a.position + a.get_hand_local_position(1) - b.get_hand_local_position(-1).rotated(PI)
	_press(1)
	_check(hold.is_connected and controls.owned_slots[1] == 1, "held bumper catches when hands enter reach")
	_fixture()
	b.linear_velocity = Vector2(1000, 0)
	_press(0)
	_check(not hold.has_any_connection(), "shared catch respects maximum relative hand velocity")
	_fixture()
	controls.suspend(hold)
	_press(0)
	_check(not hold.has_any_connection(), "held menu bumper cannot catch on resume")
	_press(0, false)
	_press(0)
	_check(hold.is_connected, "fresh press rearms after pause")
	# Simulate a geometry-rejected second catch and reuse its now-free slot.
	_press(0, false)
	_press(1)
	hold.release_secondary_hands()
	_press(1)
	_check(controls.owned_slots[1] == 0 and hold.is_connected, "solver rejection clears only rejected bumper ownership")


func _test_mode_reset(menu: PauseMenu) -> void:
	scene.set_single_player_tuning(1.3, 0.8, 0.4)
	a.reverse_spin()
	a.linear_velocity = Vector2(200, 100)
	a.partner_carry_velocity = Vector2(100, 0)
	scene.get_node("TelemetryRecorder").record_current_sample()
	var payload: Dictionary = scene.get_node("TelemetryRecorder").build_capture_payload()
	_check(payload.play_mode == "single" and payload.configuration.left_dancer.facing_mode == "trigger_spin", "telemetry identifies single mode and rotation model")
	menu._show_title()
	menu.entrance.dance_button.pressed.emit()
	_check(not scene.is_single_player() and not a.single_player_spin, "Co-op restores heading controls")
	_check(a.get_node("CollisionShape2D").shape.radius == 20.0 and b.upper_arm_length == 36.4 and b.shoulder_half_width == 17.0, "co-op geometry restored")
	_check(not hold.has_any_connection() and controls.owned_slots == [0, 0], "new mode clears both holds and ownership")
	_check(a.linear_velocity == Vector2.ZERO and a.partner_carry_velocity == Vector2.ZERO and not a.position_lock_active, "new session clears movement, carry and locks")
	_check(scene.get_node("TelemetryRecorder").get_sample_count() == 0, "mode switch starts a fresh telemetry buffer")
	_check(not menu.tabs.is_tab_hidden(3) and not menu.single_tuning_sliders[0].visible, "co-op figures and tuning restored")
	scene.figure_demonstration.set_demonstration_visible(true)
	_check(scene.figure_demonstration.visible, "co-op demonstrations remain available")
	menu._show_title()
	menu.entrance.single_player_button.pressed.emit()
	_check(a.intended_spin_direction == 1 and b.intended_spin_direction == -1, "returning to single resets spin directions")
	_check(a.spin_speed_scale == 1.3 and a.move_speed_scale == 0.8, "single tuning survives mode changes")
	_check(not scene.figure_demonstration.visible and not scene.figure_demonstration._narrator.playing, "switching to single stops figures and narration")


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _button(index: JoyButton, device: int, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.device = device
	event.pressed = pressed
	return event


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

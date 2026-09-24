class_name PrototypeController
extends Node2D

signal mode_changed

enum PlayMode { COOP, SINGLE }
var play_mode := PlayMode.COOP
var single_controls := SinglePlayerControls.new()
var single_spin_speed_scale := 1.0
var single_move_speed_scale := 1.0
var single_spin_move_ratio := 1.0
var _coop_profiles: Array[Dictionary] = []
var _blocked_buttons: Dictionary = {}
var _blocked_keys: Dictionary = {}

@export_category("Input")
@export var preferred_player_one_device := 0
@export var preferred_player_two_device := 1
@export var stick_deadzone := 0.16

@export_category("Runtime Tuning")
@export_range(0.5, 2.0, 0.05) var trigger_sensitivity := 1.0
@export_range(0.5, 2.0, 0.05) var stick_sensitivity := 1.0
@export_range(40.0, 120.0, 1.0) var man_weight_kg := 75.0
@export_range(40.0, 120.0, 1.0) var woman_weight_kg := 75.0
@export_range(40.0, 120.0, 5.0) var man_fit_weight_kg := 75.0
@export_range(40.0, 120.0, 5.0) var woman_fit_weight_kg := 75.0

@onready var left_dancer: Dancer = $LeftDancer
@onready var right_dancer: Dancer = $RightDancer
@onready var hand_connection: HandConnection = $HandConnection
@onready var figure_demonstration: FigureDemonstration = $FigureDemonstration

var _player_one_device := -1
var _player_two_device := -1


func _ready() -> void:
	for dancer in [left_dancer, right_dancer]:
		var collider: CollisionShape2D = dancer.get_node("CollisionShape2D")
		collider.shape = collider.shape.duplicate()
		_coop_profiles.append({
			"minimum_target_angular_velocity": dancer.minimum_target_angular_velocity,
			"maximum_target_angular_velocity": dancer.maximum_target_angular_velocity,
			"shoulder_half_width": dancer.shoulder_half_width,
			"upper_arm_length": dancer.upper_arm_length,
			"forearm_length": dancer.forearm_length,
			"extended_elbow_flexion_degrees": dancer.extended_elbow_flexion_degrees,
			"extended_forward_sweep_degrees": dancer.extended_forward_sweep_degrees,
			"collider_radius": collider.shape.radius,
		})
	_select_gamepads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_apply_runtime_tuning()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_select_gamepads_if_needed()
	if is_single_player():
		_apply_single_player_input(delta)
		return
	_apply_player_input(left_dancer, _player_one_device, delta)
	_apply_player_input(right_dancer, _player_two_device, delta)
	_apply_arm_pose_inputs(_read_dpad(_player_one_device), _read_dpad(_player_two_device), delta)


func is_single_player() -> bool:
	return play_mode == PlayMode.SINGLE


func start_session(mode: PlayMode) -> void:
	play_mode = mode
	hand_connection.reset_connections()
	single_controls.reset()
	figure_demonstration.set_demonstration_visible(false)
	figure_demonstration = $SingleFigureDemonstration if is_single_player() else $FigureDemonstration
	figure_demonstration.set_demonstration_visible(false)
	for index in 2:
		var dancer: Dancer = left_dancer if index == 0 else right_dancer
		var profile := _coop_profiles[index]
		for key in profile:
			if key != "collider_radius":
				dancer.set(key, profile[key])
		dancer.single_player_spin = is_single_player()
		dancer.intended_spin_direction = 1 if index == 0 else -1
		var collider: CollisionShape2D = dancer.get_node("CollisionShape2D")
		collider.shape.radius = 12.0 if is_single_player() else profile["collider_radius"]
		if is_single_player():
			dancer.minimum_target_angular_velocity = 2.2
			dancer.maximum_target_angular_velocity = 5.0
			if index == 1:
				dancer.shoulder_half_width = 16.0
				dancer.upper_arm_length = 38.5
				dancer.forearm_length = 38.5
	_apply_runtime_tuning()
	reset_players_to_corners()
	$TelemetryRecorder.clear()
	rearm_controls()
	mode_changed.emit()


func rearm_controls() -> void:
	# Child menus become ready before this controller's onready references.
	if not is_instance_valid(hand_connection):
		return
	# Suppress buttons held across pause/title/device changes until released.
	single_controls.suspend(hand_connection)
	_blocked_buttons.clear()
	_blocked_keys.clear()
	for key in [KEY_Q, KEY_E, KEY_ENTER]:
		if Input.is_physical_key_pressed(key):
			_blocked_keys[key] = true
	for device in Input.get_connected_joypads():
		for button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
			if Input.is_joy_button_pressed(device, button):
				_blocked_buttons[Vector2i(device, button)] = true
	for dancer in [left_dancer, right_dancer]:
		for side in [-1, 1]:
			hand_connection.set_grip_button_state(dancer, side, false)


func _apply_single_player_input(delta: float) -> void:
	var device := _player_one_device
	var left_move := (_read_stick(device, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		+ _read_keyboard_vector(KEY_A, KEY_D, KEY_W, KEY_S)).limit_length(1.0)
	var right_move := (_read_stick(device, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		+ _read_keyboard_vector(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)).limit_length(1.0)
	var lt := maxf(_read_trigger(device, JOY_AXIS_TRIGGER_LEFT), float(Input.is_physical_key_pressed(KEY_SHIFT)))
	var rt := maxf(_read_trigger(device, JOY_AXIS_TRIGGER_RIGHT), float(_read_gameplay_key(KEY_ENTER)))
	single_controls.apply_steering(left_dancer, right_dancer, left_move, right_move, lt, rt)
	var dpad := _read_dpad(device)
	_apply_arm_pose_inputs(dpad, dpad, delta)
	single_controls.update_hands(hand_connection,
		_read_button(device, JOY_BUTTON_LEFT_SHOULDER) or _read_gameplay_key(KEY_Q),
		_read_button(device, JOY_BUTTON_RIGHT_SHOULDER) or _read_gameplay_key(KEY_E))


func _read_gameplay_key(key: Key) -> bool:
	var pressed := Input.is_physical_key_pressed(key)
	if _blocked_keys.has(key):
		if not pressed:
			_blocked_keys.erase(key)
		return false
	return pressed


func _read_keyboard_vector(left: Key, right: Key, up: Key, down: Key) -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(right)) - float(Input.is_physical_key_pressed(left)),
		float(Input.is_physical_key_pressed(down)) - float(Input.is_physical_key_pressed(up))
	).limit_length(1.0)


func set_single_player_tuning(spin_scale: float, move_scale: float, arm_move_ratio: float) -> void:
	single_spin_speed_scale = clampf(spin_scale, 0.5, 2.0)
	single_move_speed_scale = clampf(move_scale, 0.5, 2.0)
	single_spin_move_ratio = clampf(arm_move_ratio, 0.0, 1.5)
	_apply_runtime_tuning()


func reset_players_to_corners() -> void:
	hand_connection.reset_connections()
	single_controls.reset()
	left_dancer.reset_to_pose(Vector2(150, 570), -PI * 0.75)
	right_dancer.reset_to_pose(Vector2(1130, 570), PI * 0.75)


func _apply_arm_pose_inputs(left_input: Vector2, right_input: Vector2, delta: float) -> void:
	if get_tree().paused:
		return
	var agreed := Vector2(_agreed_pose_axis(left_input.x, right_input.x),
		_agreed_pose_axis(left_input.y, right_input.y))
	var step := minf(left_dancer.arm_stance_adjustment_rate_degrees,
		right_dancer.arm_stance_adjustment_rate_degrees) * maxf(delta, 0.0)
	var elbow_step := -agreed.x * step
	var sweep_step := agreed.y * step
	# Both dancers receive the same bounded adjustment. Either partner's limit
	# stops that axis, so a shared stance cannot drift apart at an endpoint.
	for dancer in [left_dancer, right_dancer]:
		elbow_step = clampf(elbow_step,
			dancer.minimum_extended_elbow_flexion_degrees - dancer.extended_elbow_flexion_degrees,
			dancer.maximum_extended_elbow_flexion_degrees - dancer.extended_elbow_flexion_degrees)
		sweep_step = clampf(sweep_step,
			dancer.minimum_extended_forward_sweep_degrees - dancer.extended_forward_sweep_degrees,
			dancer.maximum_extended_forward_sweep_degrees - dancer.extended_forward_sweep_degrees)
	for dancer in [left_dancer, right_dancer]:
		dancer.extended_elbow_flexion_degrees += elbow_step
		dancer.extended_forward_sweep_degrees += sweep_step
		dancer.queue_redraw()


func _agreed_pose_axis(left: float, right: float) -> float:
	if left * right <= 0.0:
		return 0.0
	return signf(left) * minf(minf(absf(left), absf(right)), 1.0)


func _input(event: InputEvent) -> void:
	if get_tree() != null and get_tree().paused:
		return
	if not (event is InputEventJoypadButton):
		return
	var button_key := Vector2i(event.device, event.button_index)
	if _blocked_buttons.has(button_key):
		if not event.pressed:
			_blocked_buttons.erase(button_key)
		return
	if is_single_player():
		if event.device == _player_one_device and event.pressed:
			if event.button_index == JOY_BUTTON_LEFT_STICK:
				left_dancer.reverse_spin()
			elif event.button_index == JOY_BUTTON_RIGHT_STICK:
				right_dancer.reverse_spin()
		return

	var dancer := _dancer_for_device(event.device)
	if not is_instance_valid(dancer):
		return
	match event.button_index:
		JOY_BUTTON_LEFT_SHOULDER:
			hand_connection.set_grip_button_state(dancer, -1, event.pressed)
		JOY_BUTTON_RIGHT_SHOULDER:
			hand_connection.set_grip_button_state(dancer, 1, event.pressed)
		JOY_BUTTON_LEFT_STICK:
			if event.pressed:
				dancer.toggle_position_lock()
		JOY_BUTTON_RIGHT_STICK:
			if event.pressed:
				dancer.toggle_rotation_lock()


func _apply_player_input(dancer: Dancer, device: int, _delta: float) -> void:
	if not is_instance_valid(dancer):
		return
	hand_connection.set_grip_button_state(
		dancer,
		-1,
		_read_button(device, JOY_BUTTON_LEFT_SHOULDER)
	)
	hand_connection.set_grip_button_state(
		dancer,
		1,
		_read_button(device, JOY_BUTTON_RIGHT_SHOULDER)
	)
	var facing_stick := _read_stick(
		device,
		JOY_AXIS_RIGHT_X,
		JOY_AXIS_RIGHT_Y,
		false
	)
	dancer.set_control_input(
		_read_stick(device, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y),
		facing_stick,
		_read_trigger(device, JOY_AXIS_TRIGGER_LEFT),
		_read_trigger(device, JOY_AXIS_TRIGGER_RIGHT),
		dancer.position_lock_active,
		dancer.rotation_lock_active
	)


func _read_stick(
	device: int, axis_x: int, axis_y: int, apply_sensitivity: bool = true
) -> Vector2:
	if device < 0:
		return Vector2.ZERO
	var value := Vector2(
		Input.get_joy_axis(device, axis_x),
		Input.get_joy_axis(device, axis_y)
	)
	var magnitude := value.length()
	if magnitude <= stick_deadzone:
		return Vector2.ZERO
	var scaled_magnitude := inverse_lerp(
		stick_deadzone,
		1.0,
		minf(magnitude, 1.0)
	)
	return value.normalized() * _apply_input_sensitivity(
		scaled_magnitude,
		stick_sensitivity if apply_sensitivity else 1.0
	)


func _read_trigger(device: int, axis: int) -> float:
	if device < 0:
		return 0.0
	return _apply_input_sensitivity(
		clampf(Input.get_joy_axis(device, axis), 0.0, 1.0),
		trigger_sensitivity
	)


func _read_button(device: int, button: int) -> bool:
	var pressed := device >= 0 and Input.is_joy_button_pressed(device, button)
	var key := Vector2i(device, button)
	if _blocked_buttons.has(key):
		if not pressed:
			_blocked_buttons.erase(key)
		return false
	return pressed


func _read_dpad(device: int) -> Vector2:
	if device < 0:
		return Vector2.ZERO
	return Vector2(
		float(
			int(_read_button(device, JOY_BUTTON_DPAD_RIGHT))
			- int(_read_button(device, JOY_BUTTON_DPAD_LEFT))
		),
		float(
			int(_read_button(device, JOY_BUTTON_DPAD_UP))
			- int(_read_button(device, JOY_BUTTON_DPAD_DOWN))
		)
	)


func set_runtime_tuning(
	new_trigger_sensitivity: float,
	new_stick_sensitivity: float,
	new_man_weight_kg: float,
	new_woman_weight_kg: float,
	new_man_fit_weight_kg: float = -1.0,
	new_woman_fit_weight_kg: float = -1.0
) -> void:
	trigger_sensitivity = clampf(new_trigger_sensitivity, 0.5, 2.0)
	stick_sensitivity = clampf(new_stick_sensitivity, 0.5, 2.0)
	man_weight_kg = new_man_weight_kg
	woman_weight_kg = new_woman_weight_kg
	if new_man_fit_weight_kg >= 0.0:
		man_fit_weight_kg = new_man_fit_weight_kg
	if new_woman_fit_weight_kg >= 0.0:
		woman_fit_weight_kg = new_woman_fit_weight_kg
	_apply_runtime_tuning()


func get_player_one_device() -> int:
	return _player_one_device


func get_player_two_device() -> int:
	return _player_two_device


func _apply_runtime_tuning() -> void:
	for dancer in [left_dancer, right_dancer]:
		dancer.spin_speed_scale = single_spin_speed_scale
		dancer.move_speed_scale = single_move_speed_scale
		dancer.spin_move_ratio = single_spin_move_ratio
	left_dancer.set_physical_weight_kg(man_weight_kg)
	right_dancer.set_physical_weight_kg(woman_weight_kg)
	left_dancer.set_fit_weight_kg(man_fit_weight_kg)
	right_dancer.set_fit_weight_kg(woman_fit_weight_kg)
	man_weight_kg = left_dancer.weight_kg
	woman_weight_kg = right_dancer.weight_kg
	man_fit_weight_kg = left_dancer.fit_weight_kg
	woman_fit_weight_kg = right_dancer.fit_weight_kg


func _apply_input_sensitivity(value: float, sensitivity: float) -> float:
	if value <= 0.0:
		return 0.0
	return pow(clampf(value, 0.0, 1.0), 1.0 / maxf(sensitivity, 0.001))


func _select_gamepads() -> void:
	var connected := Input.get_connected_joypads()
	_player_one_device = _select_preferred_or_first(
		connected,
		preferred_player_one_device,
		-1
	)
	_player_two_device = _select_preferred_or_first(
		connected,
		preferred_player_two_device,
		_player_one_device
	)


func _select_preferred_or_first(
	connected: Array[int],
	preferred: int,
	excluded: int
) -> int:
	if preferred != excluded and connected.has(preferred):
		return preferred
	for device in connected:
		if device != excluded:
			return device
	return -1


func _select_gamepads_if_needed() -> void:
	var connected := Input.get_connected_joypads()
	if (
		(_player_one_device >= 0 and not connected.has(_player_one_device))
		or (_player_two_device >= 0 and not connected.has(_player_two_device))
		or (_player_one_device < 0 and not connected.is_empty())
		or (_player_two_device < 0 and connected.size() >= 2)
	):
		_select_gamepads()


func _dancer_for_device(device: int) -> Dancer:
	if device == _player_one_device:
		return left_dancer
	if device == _player_two_device:
		return right_dancer
	return null


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_select_gamepads()
	rearm_controls()

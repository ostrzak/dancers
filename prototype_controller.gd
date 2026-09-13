class_name PrototypeController
extends Node2D

@export_category("Input")
@export var preferred_gamepad_device := 0
@export var stick_deadzone := 0.16

@export_category("Runtime Tuning")
@export_range(0.5, 2.0, 0.05) var spin_speed_scale := 1.0
@export_range(0.5, 2.0, 0.05) var move_speed_scale := 1.0
@export_range(0.0, 1.5, 0.05) var spin_move_ratio := 1.0
@export_range(0.5, 2.0, 0.05) var trigger_sensitivity := 1.0
@export_range(0.5, 2.0, 0.05) var stick_sensitivity := 1.0

@onready var left_dancer: Dancer = $LeftDancer
@onready var right_dancer: Dancer = $RightDancer
@onready var hand_connection: HandConnection = $HandConnection

var _gamepad_device := -1


func _ready() -> void:
	_select_gamepad()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_apply_runtime_tuning()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_select_gamepad_if_needed()

	var left_move := _read_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var right_move := _read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	left_move = (
		left_move
		+ _read_keyboard_vector(KEY_A, KEY_D, KEY_W, KEY_S)
	).limit_length(1.0)
	right_move = (
		right_move
		+ _read_keyboard_vector(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
	).limit_length(1.0)

	var left_trigger := maxf(
		_read_trigger(JOY_AXIS_TRIGGER_LEFT),
		1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.0
	)
	var right_trigger := maxf(
		_read_trigger(JOY_AXIS_TRIGGER_RIGHT),
		1.0 if Input.is_physical_key_pressed(KEY_ENTER) else 0.0
	)
	var dpad := _read_dpad()
	apply_control_state(
		left_move,
		right_move,
		left_trigger,
		right_trigger,
		dpad,
		delta
	)

	hand_connection.set_dancer_grip_state(
		left_dancer,
		_read_button(JOY_BUTTON_LEFT_SHOULDER)
		or Input.is_physical_key_pressed(KEY_Q)
	)
	hand_connection.set_dancer_grip_state(
		right_dancer,
		_read_button(JOY_BUTTON_RIGHT_SHOULDER)
		or Input.is_physical_key_pressed(KEY_E)
	)


func _input(event: InputEvent) -> void:
	if get_tree() != null and get_tree().paused:
		return
	if not (
		event is InputEventJoypadButton
		and event.pressed
	):
		return
	if _gamepad_device >= 0 and event.device != _gamepad_device:
		return
	match event.button_index:
		JOY_BUTTON_LEFT_STICK:
			left_dancer.reverse_spin()
		JOY_BUTTON_RIGHT_STICK:
			right_dancer.reverse_spin()


func apply_control_state(
	left_stick: Vector2,
	right_stick: Vector2,
	left_trigger: float,
	right_trigger: float,
	dpad: Vector2,
	delta: float
) -> void:
	left_dancer.set_control_input(left_stick, left_trigger)
	right_dancer.set_control_input(right_stick, right_trigger)
	_apply_arm_pose_inputs(dpad, delta)


func _apply_arm_pose_inputs(dpad: Vector2, delta: float) -> void:
	if get_tree() != null and get_tree().paused:
		return
	var agreed := dpad.clamp(Vector2(-1.0, -1.0), Vector2.ONE)
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


func _read_stick(axis_x: int, axis_y: int) -> Vector2:
	if _gamepad_device < 0:
		return Vector2.ZERO
	var value := Vector2(
		Input.get_joy_axis(_gamepad_device, axis_x),
		Input.get_joy_axis(_gamepad_device, axis_y)
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
		stick_sensitivity
	)


func _read_trigger(axis: int) -> float:
	if _gamepad_device < 0:
		return 0.0
	return _apply_input_sensitivity(
		clampf(Input.get_joy_axis(_gamepad_device, axis), 0.0, 1.0),
		trigger_sensitivity
	)


func _read_button(button: int) -> bool:
	return (
		_gamepad_device >= 0
		and Input.is_joy_button_pressed(_gamepad_device, button)
	)


func _read_dpad() -> Vector2:
	if _gamepad_device < 0:
		return Vector2.ZERO
	return Vector2(
		float(
			int(_read_button(JOY_BUTTON_DPAD_RIGHT))
			- int(_read_button(JOY_BUTTON_DPAD_LEFT))
		),
		float(
			int(_read_button(JOY_BUTTON_DPAD_UP))
			- int(_read_button(JOY_BUTTON_DPAD_DOWN))
		)
	)


func set_runtime_tuning(
	new_spin_speed_scale: float,
	new_move_speed_scale: float,
	new_spin_move_ratio: float,
	new_trigger_sensitivity: float,
	new_stick_sensitivity: float
) -> void:
	spin_speed_scale = clampf(new_spin_speed_scale, 0.5, 2.0)
	move_speed_scale = clampf(new_move_speed_scale, 0.5, 2.0)
	spin_move_ratio = clampf(new_spin_move_ratio, 0.0, 1.5)
	trigger_sensitivity = clampf(new_trigger_sensitivity, 0.5, 2.0)
	stick_sensitivity = clampf(new_stick_sensitivity, 0.5, 2.0)
	_apply_runtime_tuning()


func get_gamepad_device() -> int:
	return _gamepad_device


func _apply_runtime_tuning() -> void:
	left_dancer.set_runtime_tuning(
		spin_speed_scale,
		move_speed_scale,
		spin_move_ratio
	)
	right_dancer.set_runtime_tuning(
		spin_speed_scale,
		move_speed_scale,
		spin_move_ratio
	)


func _apply_input_sensitivity(value: float, sensitivity: float) -> float:
	if value <= 0.0:
		return 0.0
	return pow(clampf(value, 0.0, 1.0), 1.0 / maxf(sensitivity, 0.001))


func _read_keyboard_vector(left: int, right: int, up: int, down: int) -> Vector2:
	return Input.get_vector(
		_key_action(left), _key_action(right), _key_action(up), _key_action(down)
	)


func _key_action(key: int) -> StringName:
	var action := StringName("prototype_key_%d" % int(key))
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var input_event := InputEventKey.new()
		input_event.physical_keycode = key
		InputMap.action_add_event(action, input_event)
	return action


func _select_gamepad() -> void:
	var connected := Input.get_connected_joypads()
	if connected.has(preferred_gamepad_device):
		_gamepad_device = preferred_gamepad_device
	elif not connected.is_empty():
		_gamepad_device = connected[0]
	else:
		_gamepad_device = -1


func _select_gamepad_if_needed() -> void:
	if _gamepad_device < 0:
		_select_gamepad()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_select_gamepad()


func _draw() -> void:
	var arena := Rect2(20.0, 20.0, 1240.0, 680.0)
	draw_rect(arena, Color("858585"), true)
	draw_rect(arena, Color("555555"), false, 3.0)
	for x in range(60, 1260, 50):
		draw_line(
			Vector2(x, 20),
			Vector2(x, 700),
			Color(0.70, 0.70, 0.70, 0.34),
			1.0
		)
	for y in range(60, 700, 50):
		draw_line(
			Vector2(20, y),
			Vector2(1260, y),
			Color(0.70, 0.70, 0.70, 0.34),
			1.0
		)

class_name PrototypeController
extends Node2D

@export_category("Input")
@export var preferred_player_one_device := 0
@export var preferred_player_two_device := 1
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

var _player_one_device := -1
var _player_two_device := -1


func _ready() -> void:
	_select_gamepads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_apply_runtime_tuning()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_select_gamepads_if_needed()
	_apply_player_input(left_dancer, _player_one_device, delta)
	_apply_player_input(right_dancer, _player_two_device, delta)


func _input(event: InputEvent) -> void:
	if get_tree() != null and get_tree().paused:
		return
	if not (event is InputEventJoypadButton):
		return

	var dancer := _dancer_for_device(event.device)
	if not is_instance_valid(dancer):
		return
	match event.button_index:
		JOY_BUTTON_LEFT_SHOULDER:
			hand_connection.set_grip_button_state(dancer, -1, event.pressed)
		JOY_BUTTON_RIGHT_SHOULDER:
			hand_connection.set_grip_button_state(dancer, 1, event.pressed)


func _apply_player_input(dancer: Dancer, device: int, delta: float) -> void:
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
	var dpad := _read_dpad(device)
	dancer.adjust_extended_arm_pose(dpad.x, dpad.y, delta)
	dancer.set_control_input(
		_read_stick(device, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y),
		_read_stick(device, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y),
		_read_trigger(device, JOY_AXIS_TRIGGER_LEFT),
		_read_trigger(device, JOY_AXIS_TRIGGER_RIGHT),
		_read_button(device, JOY_BUTTON_LEFT_STICK),
		_read_button(device, JOY_BUTTON_RIGHT_STICK)
	)


func _read_stick(device: int, axis_x: int, axis_y: int) -> Vector2:
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
		stick_sensitivity
	)


func _read_trigger(device: int, axis: int) -> float:
	if device < 0:
		return 0.0
	return _apply_input_sensitivity(
		clampf(Input.get_joy_axis(device, axis), 0.0, 1.0),
		trigger_sensitivity
	)


func _read_button(device: int, button: int) -> bool:
	return device >= 0 and Input.is_joy_button_pressed(device, button)


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


func get_player_one_device() -> int:
	return _player_one_device


func get_player_two_device() -> int:
	return _player_two_device


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


func _draw() -> void:
	var arena := Rect2(20.0, 20.0, 1240.0, 680.0)
	draw_rect(arena, Color("858585"), true)
	draw_rect(arena, Color("555555"), false, 3.0)
	for x in range(60, 1260, 50):
		draw_line(Vector2(x, 20), Vector2(x, 700), Color(0.70, 0.70, 0.70, 0.34), 1.0)
	for y in range(60, 700, 50):
		draw_line(Vector2(20, y), Vector2(1260, y), Color(0.70, 0.70, 0.70, 0.34), 1.0)

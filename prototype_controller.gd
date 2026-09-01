class_name PrototypeController
extends Node2D

@export_category("Input")
@export var preferred_gamepad_device := 0
@export var stick_deadzone := 0.16
@export var bumper_chord_window := 0.085

@onready var left_dancer: Dancer = $LeftDancer
@onready var right_dancer: Dancer = $RightDancer
@onready var hand_connection: HandConnection = $HandConnection

var _gamepad_device := -1
var _pending_bumper := -1
var _pending_bumper_time := 0.0
var _previous_keyboard_left_bumper := false
var _previous_keyboard_right_bumper := false

const LEFT_BUMPER := 0
const RIGHT_BUMPER := 1


func _ready() -> void:
	_select_gamepad()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_select_gamepad_if_needed()
	var left_move := _read_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var right_move := _read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)

	# Keyboard fallbacks keep editor iteration possible without changing the
	# intended one-controller experiment: WASD/Shift/Q and arrows/Enter/E.
	left_move = (left_move + _read_keyboard_vector(KEY_A, KEY_D, KEY_W, KEY_S)).limit_length(1.0)
	right_move = (right_move + _read_keyboard_vector(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)).limit_length(1.0)
	var left_trigger := maxf(_read_trigger(JOY_AXIS_TRIGGER_LEFT), 1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.0)
	var right_trigger := maxf(_read_trigger(JOY_AXIS_TRIGGER_RIGHT), 1.0 if Input.is_physical_key_pressed(KEY_ENTER) else 0.0)

	left_dancer.set_control_input(left_move, left_trigger)
	right_dancer.set_control_input(right_move, right_trigger)
	_poll_keyboard_bumpers()
	_resolve_pending_bumper(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if _gamepad_device >= 0 and event.device != _gamepad_device:
			return
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_register_bumper_press(LEFT_BUMPER)
			JOY_BUTTON_RIGHT_SHOULDER:
				_register_bumper_press(RIGHT_BUMPER)
			JOY_BUTTON_A:
				hand_connection.release_hands()
	elif event is InputEventKey \
			and event.pressed \
			and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		hand_connection.release_hands()


func _register_bumper_press(bumper: int) -> void:
	if _pending_bumper == -1:
		_pending_bumper = bumper
		_pending_bumper_time = bumper_chord_window
	elif _pending_bumper != bumper and _pending_bumper_time > 0.0:
		_pending_bumper = -1
		_pending_bumper_time = 0.0
		left_dancer.reverse_spin()
		right_dancer.reverse_spin()
	elif _pending_bumper != bumper:
		_execute_pending_bumper()
		_pending_bumper = bumper
		_pending_bumper_time = bumper_chord_window


func _resolve_pending_bumper(delta: float) -> void:
	if _pending_bumper == -1:
		return
	_pending_bumper_time -= delta
	if _pending_bumper_time > 0.0:
		return
	_execute_pending_bumper()


func _execute_pending_bumper() -> void:
	if _pending_bumper == LEFT_BUMPER:
		left_dancer.reverse_spin()
	elif _pending_bumper == RIGHT_BUMPER:
		right_dancer.reverse_spin()
	_pending_bumper = -1
	_pending_bumper_time = 0.0


func _poll_keyboard_bumpers() -> void:
	var left_pressed := Input.is_physical_key_pressed(KEY_Q)
	var right_pressed := Input.is_physical_key_pressed(KEY_E)
	if left_pressed and not _previous_keyboard_left_bumper:
		_register_bumper_press(LEFT_BUMPER)
	if right_pressed and not _previous_keyboard_right_bumper:
		_register_bumper_press(RIGHT_BUMPER)
	_previous_keyboard_left_bumper = left_pressed
	_previous_keyboard_right_bumper = right_pressed


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
	var scaled_magnitude := inverse_lerp(stick_deadzone, 1.0, minf(magnitude, 1.0))
	return value.normalized() * scaled_magnitude


func _read_trigger(axis: int) -> float:
	if _gamepad_device < 0:
		return 0.0
	return clampf(Input.get_joy_axis(_gamepad_device, axis), 0.0, 1.0)


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
		draw_line(Vector2(x, 20), Vector2(x, 700), Color(0.70, 0.70, 0.70, 0.34), 1.0)
	for y in range(60, 700, 50):
		draw_line(Vector2(20, y), Vector2(1260, y), Color(0.70, 0.70, 0.70, 0.34), 1.0)

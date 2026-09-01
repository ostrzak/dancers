class_name PauseMenu
extends CanvasLayer

@export var debug_overlay: DebugOverlay

@onready var telemetry_toggle: CheckButton = $Center/Panel/Menu/Telemetry
@onready var resume_button: Button = $Center/Panel/Menu/Resume
@onready var quit_button: Button = $Center/Panel/Menu/Quit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_resume)
	quit_button.pressed.connect(_quit)
	telemetry_toggle.toggled.connect(_on_telemetry_toggled)
	telemetry_toggle.set_pressed_no_signal(debug_overlay.visible)


func _input(event: InputEvent) -> void:
	if event is InputEventKey \
			and event.pressed \
			and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif visible and event.button_index == JOY_BUTTON_B:
			_resume()
			get_viewport().set_input_as_handled()
		elif visible and event.button_index == JOY_BUTTON_A:
			_activate_focused_control()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	telemetry_toggle.set_pressed_no_signal(debug_overlay.visible)
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _on_telemetry_toggled(is_enabled: bool) -> void:
	debug_overlay.set_telemetry_visible(is_enabled)


func _activate_focused_control() -> void:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == telemetry_toggle:
		var is_enabled := not telemetry_toggle.button_pressed
		telemetry_toggle.set_pressed_no_signal(is_enabled)
		_on_telemetry_toggled(is_enabled)
	elif focused_control == resume_button:
		_resume()
	elif focused_control == quit_button:
		_quit()


func _quit() -> void:
	get_tree().quit()

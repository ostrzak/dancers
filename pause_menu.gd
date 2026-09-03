class_name PauseMenu
extends CanvasLayer

@export var debug_overlay: DebugOverlay
@export var telemetry_recorder: Node
@export var controller: PrototypeController

@onready var tabs: TabContainer = $Center/Panel/Menu/Tabs
@onready var telemetry_toggle: CheckButton = $Center/Panel/Menu/Tabs/GENERAL/Telemetry
@onready var resume_button: Button = $Center/Panel/Menu/Tabs/GENERAL/Resume
@onready var save_telemetry_button: Button = $Center/Panel/Menu/Tabs/GENERAL/SaveTelemetry
@onready var capture_status: Label = $Center/Panel/Menu/Tabs/GENERAL/CaptureStatus
@onready var quit_button: Button = $Center/Panel/Menu/Tabs/GENERAL/Quit
@onready var trigger_sensitivity_slider: HSlider = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/TriggerSensitivity
@onready var stick_sensitivity_slider: HSlider = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/StickSensitivity
@onready var man_weight_slider: HSlider = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/ManWeight
@onready var woman_weight_slider: HSlider = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/WomanWeight
@onready var trigger_sensitivity_value: Label = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/TriggerSensitivityValue
@onready var stick_sensitivity_value: Label = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/StickSensitivityValue
@onready var man_weight_value: Label = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/ManWeightValue
@onready var woman_weight_value: Label = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/WomanWeightValue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_resume)
	save_telemetry_button.pressed.connect(_on_save_telemetry_pressed)
	quit_button.pressed.connect(_quit)
	telemetry_toggle.toggled.connect(_on_telemetry_toggled)
	telemetry_toggle.set_pressed_no_signal(debug_overlay.visible)
	for slider: HSlider in [
		trigger_sensitivity_slider,
		stick_sensitivity_slider,
		man_weight_slider,
		woman_weight_slider,
	]:
		slider.value_changed.connect(_on_tuning_changed)
	_sync_tuning_controls()
	if is_instance_valid(telemetry_recorder):
		telemetry_recorder.capture_saved.connect(_on_capture_saved)
		telemetry_recorder.capture_failed.connect(_on_capture_failed)


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
		elif visible and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_tab(-1)
			get_viewport().set_input_as_handled()
		elif visible and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_tab(1)
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
	_sync_tuning_controls()
	tabs.current_tab = 0
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _on_telemetry_toggled(is_enabled: bool) -> void:
	debug_overlay.set_telemetry_visible(is_enabled)


func _switch_tab(direction: int) -> void:
	tabs.current_tab = wrapi(tabs.current_tab + direction, 0, tabs.get_tab_count())
	if tabs.current_tab == 0:
		resume_button.grab_focus()
	else:
		trigger_sensitivity_slider.grab_focus()


func _sync_tuning_controls() -> void:
	if not is_instance_valid(controller):
		return
	trigger_sensitivity_slider.set_value_no_signal(controller.trigger_sensitivity)
	stick_sensitivity_slider.set_value_no_signal(controller.stick_sensitivity)
	man_weight_slider.set_value_no_signal(controller.man_weight_kg)
	woman_weight_slider.set_value_no_signal(controller.woman_weight_kg)
	_refresh_tuning_labels()


func _on_tuning_changed(_value: float) -> void:
	if not is_instance_valid(controller):
		return
	controller.set_runtime_tuning(
		trigger_sensitivity_slider.value,
		stick_sensitivity_slider.value,
		man_weight_slider.value,
		woman_weight_slider.value
	)
	_refresh_tuning_labels()


func _refresh_tuning_labels() -> void:
	trigger_sensitivity_value.text = "%.2fx" % trigger_sensitivity_slider.value
	stick_sensitivity_value.text = "%.2fx" % stick_sensitivity_slider.value
	man_weight_value.text = "%d kg" % int(man_weight_slider.value)
	woman_weight_value.text = "%d kg" % int(woman_weight_slider.value)


func _activate_focused_control() -> void:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control == telemetry_toggle:
		var is_enabled := not telemetry_toggle.button_pressed
		telemetry_toggle.set_pressed_no_signal(is_enabled)
		_on_telemetry_toggled(is_enabled)
	elif focused_control == resume_button:
		_resume()
	elif focused_control == save_telemetry_button:
		_on_save_telemetry_pressed()
	elif focused_control == quit_button:
		_quit()


func _on_save_telemetry_pressed() -> void:
	if not is_instance_valid(telemetry_recorder):
		_on_capture_failed("Telemetry recorder is unavailable.")
		return
	telemetry_recorder.save_capture("manual")


func _on_capture_saved(path: String, _reason: String) -> void:
	capture_status.visible = true
	capture_status.text = "Saved %d telemetry samples:\n%s" % [
		telemetry_recorder.get_sample_count(),
		path,
	]


func _on_capture_failed(message: String) -> void:
	capture_status.visible = true
	capture_status.text = message


func _quit() -> void:
	get_tree().quit()

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
@onready var man_weight_slider: HSlider = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/ManWeight
@onready var woman_weight_slider: HSlider = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/WomanWeight
@onready var trigger_sensitivity_value: Label = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/TriggerSensitivityValue
@onready var stick_sensitivity_value: Label = $Center/Panel/Menu/Tabs/TUNING/TuningGrid/StickSensitivityValue
@onready var man_weight_value: Label = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/ManWeightValue
@onready var man_fit_weight_slider: HSlider = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/ManFitWeight
@onready var man_fit_weight_value: Label = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/ManFitWeightValue
@onready var woman_weight_value: Label = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/WomanWeightValue
@onready var woman_fit_weight_slider: HSlider = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/WomanFitWeight
@onready var woman_fit_weight_value: Label = $Center/Panel/Menu/Tabs/DANCERS/WeightGrid/WomanFitWeightValue
@onready var demonstration: FigureDemonstration = controller.get_node("FigureDemonstration")

var figure_toggle: CheckButton
var figure_name: Label
var figure_description: Label
var figure_previous: Button
var figure_next: Button
var figure_restart: Button
var figure_reset_players: Button
var figure_speed_buttons: Array[Button] = []


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
		man_fit_weight_slider,
		woman_fit_weight_slider,
	]:
		slider.value_changed.connect(_on_tuning_changed)
	_sync_tuning_controls()
	_build_figures_tab()
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
	elif tabs.current_tab == 1:
		trigger_sensitivity_slider.grab_focus()
	elif tabs.current_tab == 2:
		man_weight_slider.grab_focus()
	else:
		figure_toggle.grab_focus()


func _build_figures_tab() -> void:
	var panel := VBoxContainer.new()
	panel.name = "FIGURES"
	panel.add_theme_constant_override("separation", 12)
	tabs.add_child(panel)
	figure_toggle = CheckButton.new()
	figure_toggle.text = "SHOW DEMONSTRATION"
	figure_toggle.custom_minimum_size.y = 44
	figure_toggle.button_pressed = demonstration.visible
	figure_toggle.toggled.connect(demonstration.set_demonstration_visible)
	panel.add_child(figure_toggle)
	var selection := HBoxContainer.new()
	panel.add_child(selection)
	figure_previous = _figure_button(selection, "<", _select_previous_figure)
	figure_previous.custom_minimum_size.x = 48
	figure_name = Label.new()
	figure_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	figure_name.add_theme_font_size_override("font_size", 18)
	selection.add_child(figure_name)
	figure_next = _figure_button(selection, ">", _select_next_figure)
	figure_next.custom_minimum_size.x = 48
	figure_description = Label.new()
	figure_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	figure_description.custom_minimum_size.y = 64
	panel.add_child(figure_description)
	var speed_label := Label.new()
	speed_label.text = "DEMONSTRATION SPEED"
	panel.add_child(speed_label)
	var speeds := HBoxContainer.new()
	panel.add_child(speeds)
	var speed_group := ButtonGroup.new()
	for speed in [0.5, 0.75, 1.0]:
		var button := _figure_button(speeds, "%sx" % speed, _set_figure_speed.bind(speed))
		button.toggle_mode = true
		button.button_group = speed_group
		button.button_pressed = is_equal_approx(speed, demonstration.playback_speed)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		figure_speed_buttons.append(button)
	figure_restart = _figure_button(panel, "RESTART DEMONSTRATION", demonstration.restart)
	figure_reset_players = _figure_button(panel, "RESET PLAYERS TO CORNERS", controller.reset_players_to_corners)
	var hint := Label.new()
	hint.text = "Loops with a short pause. Watch, then try it your way."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	panel.add_child(hint)
	_refresh_figure_labels()


func _figure_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _select_previous_figure() -> void:
	_select_figure(-1)


func _select_next_figure() -> void:
	_select_figure(1)


func _select_figure(direction: int) -> void:
	demonstration.select_figure(demonstration.selected_index + direction)
	_refresh_figure_labels()


func _refresh_figure_labels() -> void:
	figure_name.text = "%s · %d/%d" % [demonstration.get_figure().title,
		demonstration.selected_index + 1, demonstration.FIGURES.size()]
	figure_description.text = demonstration.get_figure().description
	figure_previous.disabled = demonstration.FIGURES.size() < 2
	figure_next.disabled = demonstration.FIGURES.size() < 2


func _set_figure_speed(speed: float) -> void:
	demonstration.playback_speed = speed


func _sync_tuning_controls() -> void:
	if not is_instance_valid(controller):
		return
	trigger_sensitivity_slider.set_value_no_signal(controller.trigger_sensitivity)
	stick_sensitivity_slider.set_value_no_signal(controller.stick_sensitivity)
	man_weight_slider.set_value_no_signal(controller.man_weight_kg)
	woman_weight_slider.set_value_no_signal(controller.woman_weight_kg)
	man_fit_weight_slider.set_value_no_signal(controller.man_fit_weight_kg)
	woman_fit_weight_slider.set_value_no_signal(controller.woman_fit_weight_kg)
	_refresh_tuning_labels()


func _on_tuning_changed(_value: float) -> void:
	if not is_instance_valid(controller):
		return
	controller.set_runtime_tuning(
		trigger_sensitivity_slider.value,
		stick_sensitivity_slider.value,
		man_weight_slider.value,
		woman_weight_slider.value,
		man_fit_weight_slider.value,
		woman_fit_weight_slider.value
	)
	_refresh_tuning_labels()


func _refresh_tuning_labels() -> void:
	trigger_sensitivity_value.text = "%.2fx" % trigger_sensitivity_slider.value
	stick_sensitivity_value.text = "%.2fx" % stick_sensitivity_slider.value
	man_weight_value.text = "%d kg" % int(man_weight_slider.value)
	woman_weight_value.text = "%d kg" % int(woman_weight_slider.value)
	man_fit_weight_value.text = "%d kg" % int(man_fit_weight_slider.value)
	woman_fit_weight_value.text = "%d kg" % int(woman_fit_weight_slider.value)


func _activate_focused_control() -> void:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control is BaseButton and not focused_control.disabled:
		if focused_control.toggle_mode:
			if focused_control.button_group != null and not focused_control.button_group.allow_unpress:
				focused_control.button_pressed = true
			else:
				focused_control.button_pressed = not focused_control.button_pressed
		focused_control.pressed.emit()


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

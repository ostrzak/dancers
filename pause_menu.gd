class_name PauseMenu
extends CanvasLayer

@export var debug_overlay: DebugOverlay
@export var telemetry_recorder: Node
@export var controller: PrototypeController
@export var start_on_title := false

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
var figure_variant_row: HBoxContainer
var figure_variant_name: Label
var figure_variant_previous: Button
var figure_variant_next: Button
var figure_restart: Button
var figure_reset_players: Button
var figure_speed_buttons: Array[Button] = []
var entrance: EntranceScreen
var floor_art: BallroomFloor
var floor_buttons: Array[Button] = []
var floor_preview: TextureRect
var floor_description: Label
var grid_toggle: CheckButton
var appearance_status: Label
var ballroom_tab := 4
var title_context := false
var entrance_return_focus: Control
var transition: Tween
var back_button: Button
var music: BallroomMusic
var music_tab := 4
var music_previous: Button
var music_name: Label
var music_volume: HSlider
var music_volume_label: Label
var music_status: Label
var single_tuning_controls: Array[Control] = []
var single_tuning_sliders: Array[HSlider] = []
var single_tuning_values: Array[Label] = []
var controls_help: Label
var controls_tab := -1


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
	_build_single_tuning()
	_sync_tuning_controls()
	_build_figures_tab()
	music = BallroomMusic.new()
	music.title_mode = start_on_title
	add_child(music)
	_build_music_tab()
	floor_art = controller.get_node("BallroomFloor")
	_build_ballroom_tab()
	_style_menu()
	entrance = EntranceScreen.new()
	entrance.controller = controller
	entrance.floor_art = floor_art
	add_child(entrance)
	entrance.hide()
	entrance.dance_requested.connect(_start_dancing)
	entrance.single_player_requested.connect(_start_single_player)
	entrance.ballroom_requested.connect(_open_ballroom)
	entrance.settings_requested.connect(_open_settings)
	entrance.music_requested.connect(_open_music)
	entrance.quit_requested.connect(_quit)
	controller.mode_changed.connect(_refresh_mode_controls)
	_refresh_mode_controls()
	if start_on_title:
		_show_title()
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
			if not entrance.visible:
				_switch_tab(-1)
			get_viewport().set_input_as_handled()
		elif visible and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			if not entrance.visible:
				_switch_tab(1)
			get_viewport().set_input_as_handled()
		elif visible and event.button_index == JOY_BUTTON_A:
			_activate_focused_control()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if visible and entrance.visible:
		return
	if visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	controller.rearm_controls()
	title_context = false
	entrance.hide()
	$Dim.show()
	$Center.show()
	$Center/Panel/Menu/Title.text = "Paused"
	resume_button.text = "Resume"
	back_button.text = "Resume"
	telemetry_toggle.set_pressed_no_signal(debug_overlay.visible)
	_sync_tuning_controls()
	tabs.current_tab = 0
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()
	_fade_in($Center)


func _resume() -> void:
	if title_context:
		_show_title()
		return
	controller.rearm_controls()
	get_tree().paused = false
	visible = false


func _on_telemetry_toggled(is_enabled: bool) -> void:
	debug_overlay.set_telemetry_visible(is_enabled)


func _show_title() -> void:
	controller.rearm_controls()
	music.play_context(true)
	title_context = true
	visible = true
	get_tree().paused = true
	$Center.hide()
	$Dim.hide()
	entrance.show()
	if is_instance_valid(entrance_return_focus):
		entrance_return_focus.grab_focus()
	else:
		entrance.dance_button.grab_focus()
	_fade_in(entrance)


func _start_dancing() -> void:
	_start_mode(PrototypeController.PlayMode.COOP)


func _start_single_player() -> void:
	_start_mode(PrototypeController.PlayMode.SINGLE)


func _start_mode(mode: PrototypeController.PlayMode) -> void:
	controller.start_session(mode)
	music.play_context(false)
	title_context = false
	entrance_return_focus = null
	entrance.hide()
	_resume()


func _open_settings() -> void:
	_open_title_tab(1, entrance.settings_button)


func _open_ballroom() -> void:
	_open_title_tab(ballroom_tab, entrance.ballroom_button)


func _open_music() -> void:
	_open_title_tab(music_tab, entrance.music_button)


func _open_title_tab(index: int, return_focus: Control) -> void:
	_pause()
	title_context = true
	entrance_return_focus = return_focus
	$Center/Panel/Menu/Title.text = "Ballroom" if index == ballroom_tab else ("Music" if index == music_tab else "Settings")
	resume_button.text = "Back to title"
	back_button.text = "Back"
	_switch_tab(index)


func _fade_in(control: Control) -> void:
	if transition:
		transition.kill()
	control.modulate.a = 0.0
	transition = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition.tween_property(control, "modulate:a", 1.0, 0.18)


func _build_ballroom_tab() -> void:
	var panel := VBoxContainer.new()
	panel.name = "BALLROOM"
	panel.add_theme_constant_override("separation", 12)
	ballroom_tab = tabs.get_tab_count()
	tabs.add_child(panel)
	floor_preview = TextureRect.new()
	floor_preview.custom_minimum_size.y = 220
	floor_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(floor_preview)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	panel.add_child(choices)
	var group := ButtonGroup.new()
	for index in BallroomFloor.NAMES.size():
		var button := _figure_button(choices, BallroomFloor.NAMES[index], _select_floor.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		floor_buttons.append(button)
	floor_description = Label.new()
	floor_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(floor_description)
	grid_toggle = CheckButton.new()
	grid_toggle.text = "Practice grid"
	grid_toggle.custom_minimum_size.y = 44
	grid_toggle.toggled.connect(_set_practice_grid)
	panel.add_child(grid_toggle)
	var hint := Label.new()
	hint.text = "The practice grid is available on the studio floor."
	hint.add_theme_font_size_override("font_size", 15)
	panel.add_child(hint)
	appearance_status = Label.new()
	appearance_status.add_theme_font_size_override("font_size", 14)
	panel.add_child(appearance_status)
	floor_art.appearance_changed.connect(_refresh_floor_controls)
	_refresh_floor_controls()


func _build_music_tab() -> void:
	var panel := VBoxContainer.new()
	panel.name = "MUSIC"
	panel.add_theme_constant_override("separation", 12)
	music_tab = tabs.get_tab_count()
	tabs.add_child(panel)
	var heading := Label.new()
	heading.text = "Dance music"
	panel.add_child(heading)
	var row := HBoxContainer.new()
	panel.add_child(row)
	music_previous = _figure_button(row, "<", _select_music.bind(-1))
	music_previous.custom_minimum_size.x = 48
	music_name = Label.new()
	music_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(music_name)
	var next := _figure_button(row, ">", _select_music.bind(1))
	next.custom_minimum_size.x = 48
	music_volume_label = Label.new()
	panel.add_child(music_volume_label)
	music_volume = HSlider.new()
	music_volume.max_value = 100
	music_volume.step = 1
	music_volume.custom_minimum_size.y = 32
	music_volume.value = music.volume * 100
	music_volume.value_changed.connect(_set_music_volume)
	panel.add_child(music_volume)
	var credits := RichTextLabel.new()
	credits.text = BallroomMusic.CREDITS
	credits.custom_minimum_size.y = 160
	credits.add_theme_font_size_override("normal_font_size", 14)
	credits.focus_mode = Control.FOCUS_ALL
	panel.add_child(credits)
	music_status = Label.new()
	music_status.hide()
	music_status.add_theme_font_size_override("font_size", 14)
	panel.add_child(music_status)
	_refresh_music()


func _select_music(direction: int) -> void:
	music.select_track(music.selected_index + direction)
	_refresh_music()
	_save_music()


func _set_music_volume(value: float) -> void:
	music.volume = value / 100.0
	_refresh_music()
	_save_music()


func _refresh_music() -> void:
	music_name.text = BallroomMusic.TITLES[music.selected_index]
	music_volume_label.text = "Music volume · %d%%" % roundi(music.volume * 100)


func _save_music() -> void:
	var result := music.save_preferences()
	music_status.visible = result != OK
	music_status.text = "" if result == OK else "Could not save music settings: %s" % error_string(result)


func _select_floor(index: int) -> void:
	floor_art.select_floor(index)
	_save_appearance()


func _set_practice_grid(enabled: bool) -> void:
	floor_art.set_practice_grid(enabled)
	_save_appearance()


func _save_appearance() -> void:
	var result := floor_art.save_preferences()
	appearance_status.text = "Saved for your next dance." if result == OK else "Could not save appearance: %s" % error_string(result)


func _refresh_floor_controls() -> void:
	floor_preview.texture = BallroomFloor.TEXTURES[floor_art.selected_index]
	floor_description.text = BallroomFloor.DESCRIPTIONS[floor_art.selected_index]
	for index in floor_buttons.size():
		floor_buttons[index].set_pressed_no_signal(index == floor_art.selected_index)
	grid_toggle.set_pressed_no_signal(floor_art.practice_grid)
	grid_toggle.disabled = floor_art.selected_index != 2


func _style_menu() -> void:
	$Center.theme = BallroomTheme.create()
	$Center/Panel.custom_minimum_size = Vector2(710, 620)
	$Center/Panel/Menu/Title.add_theme_font_override("font", BallroomTheme.HEADING)
	$Center/Panel/Menu/Title.add_theme_font_size_override("font_size", 44)
	$Dim.color = Color(0.04, 0.07, 0.05, 0.62)
	_sentence_case_labels($Center)
	for index in tabs.get_tab_count():
		var original := tabs.get_tab_title(index)
		tabs.set_tab_title(index, original.capitalize())
	var hint: Label = $Center/Panel/Menu/TabHint
	hint.text = "LB / RB  Tabs     ·     A / Enter  Select     ·     B / Esc  Back"
	var footer := HBoxContainer.new()
	$Center/Panel/Menu.add_child(footer)
	hint.reparent(footer)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	back_button = _figure_button(footer, "Resume", _resume)
	back_button.custom_minimum_size.x = 90
	var title_button := _figure_button(tabs.get_tab_control(0), "Return to title", _show_title)
	tabs.get_tab_control(0).move_child(title_button, 1)
	var controls_panel := VBoxContainer.new()
	controls_panel.name = "Controls"
	tabs.add_child(controls_panel)
	controls_tab = tabs.get_tab_count() - 1
	controls_help = Label.new()
	controls_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_help.add_theme_font_size_override("font_size", 16)
	controls_panel.add_child(controls_help)
	# All overlays use the body face, including diagnostic readouts.
	for child in debug_overlay.get_children():
		if child is Control:
			child.theme = $Center.theme


func _sentence_case_labels(node: Node) -> void:
	if node is Label or node is Button:
		var value: String = node.text
		if not value.is_empty() and value == value.to_upper():
			node.text = value.left(1) + value.substr(1).to_lower()
		if node.has_theme_color_override("font_color"):
			node.remove_theme_color_override("font_color")
	for child in node.get_children():
		_sentence_case_labels(child)


func _switch_tab(direction: int) -> void:
	tabs.current_tab = wrapi(tabs.current_tab + direction, 0, tabs.get_tab_count())
	while tabs.is_tab_hidden(tabs.current_tab):
		tabs.current_tab = wrapi(tabs.current_tab + (1 if direction >= 0 else -1), 0, tabs.get_tab_count())
	if tabs.current_tab == 0:
		resume_button.grab_focus()
	elif tabs.current_tab == 1:
		trigger_sensitivity_slider.grab_focus()
	elif tabs.current_tab == 2:
		man_weight_slider.grab_focus()
	elif tabs.current_tab == 3:
		figure_toggle.grab_focus()
	elif tabs.current_tab == music_tab:
		music_previous.grab_focus()
	elif tabs.current_tab == controls_tab:
		back_button.grab_focus()
	else:
		floor_buttons[floor_art.selected_index].grab_focus()


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
	figure_variant_row = HBoxContainer.new()
	panel.add_child(figure_variant_row)
	figure_variant_previous = _figure_button(figure_variant_row, "<", _select_figure_variant.bind(-1))
	figure_variant_previous.custom_minimum_size.x = 48
	figure_variant_previous.tooltip_text = "Previous variant"
	figure_variant_name = Label.new()
	figure_variant_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure_variant_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	figure_variant_name.add_theme_font_size_override("font_size", 16)
	figure_variant_row.add_child(figure_variant_name)
	figure_variant_next = _figure_button(figure_variant_row, ">", _select_figure_variant.bind(1))
	figure_variant_next.custom_minimum_size.x = 48
	figure_variant_next.tooltip_text = "Next variant"
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
	hint.text = "Movement loops; narration plays once when available. Restart to hear it again."
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
	var has_variants := demonstration.get_variants().size() > 1
	figure_variant_row.visible = has_variants
	figure_variant_previous.disabled = not has_variants
	figure_variant_next.disabled = not has_variants
	figure_variant_name.text = "VARIANT · %s" % demonstration.get_figure().variant_label


func _select_figure_variant(direction: int) -> void:
	demonstration.select_variant(demonstration.selected_variant + direction)
	_refresh_figure_labels()


func _set_figure_speed(speed: float) -> void:
	demonstration.playback_speed = speed


func _build_single_tuning() -> void:
	var grid: GridContainer = $Center/Panel/Menu/Tabs/TUNING/TuningGrid
	for index in 3:
		var label := Label.new()
		label.text = ["Spin speed", "Move speed", "Arm / move ratio"][index]
		label.add_theme_font_size_override("font_size", 16)
		grid.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(300, 42)
		slider.min_value = 0.0 if index == 2 else 0.5
		slider.max_value = 1.5 if index == 2 else 2.0
		slider.step = 0.05
		slider.value = 1.0
		grid.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 62
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		single_tuning_controls.append_array([label, slider, value])
		single_tuning_sliders.append(slider)
		single_tuning_values.append(value)
		slider.value_changed.connect(_on_single_tuning_changed)


func _on_single_tuning_changed(_value: float) -> void:
	controller.set_single_player_tuning(single_tuning_sliders[0].value,
		single_tuning_sliders[1].value, single_tuning_sliders[2].value)
	_refresh_tuning_labels()


func _refresh_mode_controls() -> void:
	var single := controller.is_single_player()
	tabs.set_tab_hidden(3, single)
	if single and tabs.current_tab == 3:
		tabs.current_tab = 0
	figure_toggle.set_pressed_no_signal(demonstration.visible)
	for control in single_tuning_controls:
		control.visible = single
	$Center/Panel/Menu/Tabs/TUNING/Description.text = (
		"Sensitivity changes input response. Both sticks move dancers.\nTriggers contract arms and drive spin."
		if single else "Sensitivity changes input response without changing its endpoints.\nStick sensitivity affects LS; RS travel controls heading correction."
	)
	controls_help.text = (
		"Single player · One controller, both dancers\nLS / RS: move black / white · LT / RT: contract arms and spin\nL3 / R3: reverse black / white spin · D-pad: shared arm stance\nLB or RB: hold to catch; press again to release its connection.\nThe other bumper can catch the remaining hands.\nKeyboard: WASD / arrows move · Shift / Enter contract · Q / E catch"
		if single else "Co-op · One controller per dancer\nLS: move · RS: turn · LT / RT: left / right arm\nLB / RB: prime left / right hand; press again to release\nL3 / R3: position / rotation lock\nBoth D-pads together: shared arm stance"
	)
	_sync_tuning_controls()


func _sync_tuning_controls() -> void:
	if not is_instance_valid(controller):
		return
	trigger_sensitivity_slider.set_value_no_signal(controller.trigger_sensitivity)
	stick_sensitivity_slider.set_value_no_signal(controller.stick_sensitivity)
	man_weight_slider.set_value_no_signal(controller.man_weight_kg)
	woman_weight_slider.set_value_no_signal(controller.woman_weight_kg)
	man_fit_weight_slider.set_value_no_signal(controller.man_fit_weight_kg)
	woman_fit_weight_slider.set_value_no_signal(controller.woman_fit_weight_kg)
	if single_tuning_sliders.size() == 3:
		single_tuning_sliders[0].set_value_no_signal(controller.single_spin_speed_scale)
		single_tuning_sliders[1].set_value_no_signal(controller.single_move_speed_scale)
		single_tuning_sliders[2].set_value_no_signal(controller.single_spin_move_ratio)
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
	for index in single_tuning_sliders.size():
		single_tuning_values[index].text = "%.2f" % single_tuning_sliders[index].value
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

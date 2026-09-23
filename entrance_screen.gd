class_name EntranceScreen
extends Control

signal dance_requested
signal ballroom_requested
signal settings_requested
signal music_requested
signal quit_requested

var controller: PrototypeController
var floor_art: BallroomFloor
var dance_button: Button
var ballroom_button: Button
var settings_button: Button
var music_button: Button
var connection_label: Label
var background: TextureRect
var dance_stage: Control
var title_dance: TitleDance


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = BallroomTheme.create()
	background = TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color("141b18"))
	gradient.set_color(1, Color(0.08, 0.10, 0.08, 0.22))
	gradient.add_point(0.36, Color(0.08, 0.10, 0.08, 0.96))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 70)
	margin.add_child(columns)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 340
	menu.add_theme_constant_override("separation", 9)
	columns.add_child(menu)
	var title := _label(menu, "Embody\nDancers", 96)
	title.add_theme_font_override("font", BallroomTheme.HEADING)
	_space(menu, 24)
	dance_button = _button(menu, "Dance", dance_requested.emit)
	ballroom_button = _button(menu, "Ballroom", ballroom_requested.emit)
	music_button = _button(menu, "Music", music_requested.emit)
	settings_button = _button(menu, "Settings", settings_requested.emit)
	_button(menu, "Quit", quit_requested.emit)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(spacer)
	connection_label = _label(menu, "", 15, BallroomTheme.MUTED)
	dance_stage = Control.new()
	dance_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dance_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dance_stage.clip_contents = true
	columns.add_child(dance_stage)
	title_dance = TitleDance.new()
	dance_stage.add_child(title_dance)
	dance_stage.resized.connect(_layout_dance)
	_layout_dance()
	floor_art.appearance_changed.connect(_refresh_floor)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_floor()
	_refresh_connections.call_deferred()


func _refresh_floor() -> void:
	background.texture = BallroomFloor.TEXTURES[floor_art.selected_index]


func _layout_dance() -> void:
	title_dance.position = dance_stage.size * 0.5
	title_dance.scale = Vector2.ONE * minf(dance_stage.size.x / 540.0, dance_stage.size.y / 540.0)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_connections.call_deferred()


func _refresh_connections() -> void:
	connection_label.text = "Partner 1  ·  %s\nPartner 2  ·  %s" % [
		"Connected" if controller.get_player_one_device() >= 0 else "Connect a controller",
		"Connected" if controller.get_player_two_device() >= 0 else "Connect a controller",
	]


func _label(parent: Node, text: String, font_size: int, color: Color = BallroomTheme.IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 52
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _space(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

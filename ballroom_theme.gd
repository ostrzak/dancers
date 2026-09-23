class_name BallroomTheme
extends RefCounted

const BODY := preload("res://assets/fonts/body.tres")
const HEADING := preload("res://assets/fonts/heading.tres")
const IVORY := Color("eee4ce")
const MUTED := Color("b5aa95")
const BRASS := Color("c6a76c")


static func panel(fill: Color, border: Color, margin: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 18
	for type in ["Label", "Button", "CheckButton", "TabContainer", "TabBar"]:
		theme.set_color("font_color", type, IVORY)
		theme.set_color("font_hover_color", type, IVORY)
		theme.set_color("font_pressed_color", type, IVORY)
		theme.set_color("font_focus_color", type, IVORY)
		theme.set_color("font_disabled_color", type, Color("777063"))
	var normal := panel(Color("242620"), Color("575342"), 12)
	var hover := panel(Color("35362b"), BRASS, 12)
	var pressed := panel(Color("45402e"), BRASS, 12)
	for style in [normal, hover, pressed]:
		style.content_margin_top = 8
		style.content_margin_bottom = 8
	var focus := panel(Color(0, 0, 0, 0), BRASS, 0)
	focus.set_border_width_all(2)
	for type in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, normal)
		theme.set_stylebox("focus", type, focus)
	theme.set_stylebox("panel", "PanelContainer", panel(Color("1b201c"), Color("716349"), 24))
	theme.set_stylebox("panel", "TabContainer", panel(Color("1b201c"), Color(0, 0, 0, 0), 14))
	for type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, pressed)
		theme.set_stylebox("tab_unselected", type, normal)
		theme.set_stylebox("tab_hovered", type, hover)
		theme.set_stylebox("tab_focus", type, focus)
		theme.set_color("font_selected_color", type, IVORY)
		theme.set_color("font_unselected_color", type, MUTED)
	var track := panel(Color("414438"), Color(0, 0, 0, 0), 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = BRASS
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", preload("res://assets/ui/slider_knob.svg"))
	theme.set_icon("grabber_highlight", "HSlider", preload("res://assets/ui/slider_knob_focus.svg"))
	for icon in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		theme.set_icon(icon, "CheckButton", preload("res://assets/ui/toggle_on.svg"))
	for icon in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		theme.set_icon(icon, "CheckButton", preload("res://assets/ui/toggle_off.svg"))
	return theme

class_name BallroomFloor
extends Node2D

signal appearance_changed

const SETTINGS_PATH := "user://coop_appearance.cfg"
const NAMES := ["Classic parquet", "Grand ballroom", "Practice studio"]
const DESCRIPTIONS := [
	"Warm oak herringbone, framed in dark wood.",
	"Walnut parquet panels with a fine brass inlay.",
	"Quiet maple boards. Space to find your footing.",
]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/floors/classic_parquet.svg"),
	preload("res://assets/floors/grand_ballroom.svg"),
	preload("res://assets/floors/practice_studio.svg"),
]

var selected_index := 0
var practice_grid := false
@export var preferences_path := SETTINGS_PATH


func _ready() -> void:
	load_preferences()


func load_preferences(path: String = "") -> void:
	if path.is_empty():
		path = preferences_path
	var config := ConfigFile.new()
	selected_index = 0
	practice_grid = false
	if config.load(path) == OK:
		var saved_index: Variant = config.get_value("ballroom", "floor", 0)
		if saved_index is int:
			selected_index = clampi(saved_index, 0, TEXTURES.size() - 1)
		var saved_grid: Variant = config.get_value("ballroom", "practice_grid", false)
		if saved_grid is bool:
			practice_grid = saved_grid
	queue_redraw()
	appearance_changed.emit()


func select_floor(index: int) -> void:
	selected_index = clampi(index, 0, TEXTURES.size() - 1)
	queue_redraw()
	appearance_changed.emit()


func set_practice_grid(enabled: bool) -> void:
	practice_grid = enabled
	queue_redraw()
	appearance_changed.emit()


func save_preferences(path: String = "") -> Error:
	if path.is_empty():
		path = preferences_path
	var config := ConfigFile.new()
	config.set_value("ballroom", "floor", selected_index)
	config.set_value("ballroom", "practice_grid", practice_grid)
	return config.save(path)


func _draw() -> void:
	draw_texture_rect(TEXTURES[selected_index], Rect2(20, 20, 1240, 680), false)
	if selected_index == 2 and practice_grid:
		for x in range(60, 1260, 50):
			draw_line(Vector2(x, 45), Vector2(x, 675), Color(0.95, 0.90, 0.78, 0.16))
		for y in range(60, 680, 50):
			draw_line(Vector2(45, y), Vector2(1235, y), Color(0.95, 0.90, 0.78, 0.16))

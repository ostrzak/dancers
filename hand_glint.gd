class_name HandGlint
extends Node2D

const DURATION := 0.5
var points: Array[Vector2] = []
var age := DURATION


func _draw() -> void:
	for point in points:
		paint(self, point, age)


static func paint(canvas: CanvasItem, point: Vector2, seconds: float) -> void:
	if seconds < 0.0 or seconds >= DURATION:
		return
	var progress := seconds / DURATION
	var strength := sin(PI * progress)
	var radius := lerpf(7.0, 17.0, progress)
	canvas.draw_circle(point, radius, Color(1.0, 0.82, 0.42, strength * 0.18))
	canvas.draw_arc(point, radius, 0, TAU, 32, Color(1.0, 0.85, 0.51, strength * 0.65), 1.2, true)
	var ray := 9.0 * strength
	canvas.draw_line(point - Vector2(ray, 0), point + Vector2(ray, 0), Color(1, 0.96, 0.78, strength), 1.6, true)
	canvas.draw_line(point - Vector2(0, ray), point + Vector2(0, ray), Color(1, 0.96, 0.78, strength), 1.6, true)

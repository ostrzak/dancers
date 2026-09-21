class_name FigureDemonstration
extends Node2D

const FIGURES: Array[DanceFigure] = [
	preload("res://figures/travelling_turn.tres"),
	preload("res://figures/turn_in_place.tres"),
	preload("res://figures/alternating_sides.tres"),
	preload("res://figures/open_and_close.tres"),
]
const OPACITY := 0.48
const END_PAUSE := 0.8
const FADE_TIME := 0.3

var selected_index := 0
var playback_speed := 1.0
var elapsed := 0.0
var ghost_a: Dancer
var ghost_b: Dancer
var _art: CanvasGroup


func _ready() -> void:
	_art = CanvasGroup.new()
	add_child(_art)
	ghost_a = _make_ghost(0, Color("111111"), Color("f2f2f2"))
	ghost_b = _make_ghost(1, Color("f2f2f2"), Color("111111"))
	restart()


func _make_ghost(style: int, body: Color, detail: Color) -> Dancer:
	var ghost := Dancer.new()
	ghost.body_style = style
	ghost.body_color = body
	ghost.detail_color = detail
	ghost.freeze = true
	ghost.collision_layer = 0
	ghost.collision_mask = 0
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_art.add_child(ghost)
	return ghost


func _process(delta: float) -> void:
	if not visible:
		return
	var cycle := get_figure().duration + END_PAUSE + FADE_TIME * 2.0
	elapsed = fposmod(elapsed + delta * playback_speed, cycle)
	_update_pose()


func get_figure() -> DanceFigure:
	return FIGURES[selected_index]


func select_figure(index: int) -> void:
	selected_index = wrapi(index, 0, FIGURES.size())
	restart()


func set_demonstration_visible(enabled: bool) -> void:
	visible = enabled
	if enabled:
		restart()


func restart() -> void:
	elapsed = 0.0
	if is_instance_valid(_art):
		_update_pose()


func _update_pose() -> void:
	var figure := get_figure()
	var seconds := minf(elapsed, figure.duration)
	var fade_start := figure.duration + END_PAUSE
	var alpha := OPACITY
	if elapsed > fade_start + FADE_TIME:
		seconds = 0.0
		alpha *= clampf((elapsed - fade_start - FADE_TIME) / FADE_TIME, 0.0, 1.0)
	elif elapsed > fade_start:
		alpha *= 1.0 - (elapsed - fade_start) / FADE_TIME
	# Fade the composited artwork, keeping child shapes opaque so they still
	# cover hidden body details and the overlaps between arm segments.
	_art.self_modulate.a = alpha
	var pose := figure.sample(seconds)
	_apply_pose(pose.centre, pose.turn, pose.flexion, pose.get("secondary_flexion", 0.0))


func _apply_pose(centre: Vector2, turn: float, flexion: float, secondary_flexion: float = 0.0) -> void:
	ghost_a.set_current_arm_length(-1, lerpf(ghost_a.maximum_arm_length, ghost_a.minimum_arm_length, flexion))
	ghost_a.set_current_arm_length(1, lerpf(ghost_a.maximum_arm_length, ghost_a.minimum_arm_length, secondary_flexion))
	ghost_b.set_current_arm_length(1, lerpf(ghost_b.maximum_arm_length, ghost_b.minimum_arm_length, flexion))
	ghost_b.set_current_arm_length(-1, lerpf(ghost_b.maximum_arm_length, ghost_b.minimum_arm_length, secondary_flexion))
	# Align the two equal hand spans, then align the first contact. The other
	# contact coincides automatically, including throughout pose transitions.
	var a_hand := ghost_a.get_hand_local_position(-1)
	var b_hand := ghost_b.get_hand_local_position(1)
	var a_span := ghost_a.get_hand_local_position(1) - a_hand
	var b_span := ghost_b.get_hand_local_position(-1) - b_hand
	var relative_turn := a_span.angle() - b_span.angle()
	var offset := (a_hand - b_hand.rotated(relative_turn)).rotated(turn)
	ghost_a.position = centre - offset * 0.5
	ghost_b.position = centre + offset * 0.5
	ghost_a.rotation = turn
	ghost_b.rotation = turn + relative_turn
	ghost_a.queue_redraw()
	ghost_b.queue_redraw()

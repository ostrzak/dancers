class_name FigureDemonstration
extends Node2D

const FIGURES: Array[DanceFigure] = [
	preload("res://figures/travelling_turn.tres"),
	preload("res://figures/turn_in_place.tres"),
	preload("res://figures/alternating_sides.tres"),
	preload("res://figures/open_and_close.tres"),
	preload("res://figures/join_behind_back.tres"),
	preload("res://figures/connected_turn.tres"),
	preload("res://figures/connected_turn_reverse.tres"),
	preload("res://figures/release_turn_catch.tres"),
	preload("res://figures/open_out_return.tres"),
	preload("res://figures/progressive_twinkles.tres"),
	preload("res://figures/open_impetus.tres"),
	preload("res://figures/wing.tres"),
	preload("res://figures/weave_promenade.tres"),
	preload("res://figures/away_together.tres"),
	preload("res://figures/solo_turns.tres"),
	preload("res://figures/synchronous_spins.tres"),
	preload("res://figures/mirror_spins.tres"),
	preload("res://figures/two_planets.tres"),
	preload("res://figures/spinning_planets.tres"),
	preload("res://figures/do_si_do.tres"),
	preload("res://figures/travelling_turns.tres"),
	preload("res://figures/mirror_paths.tres"),
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
	visible = false
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
	for ghost in [ghost_a, ghost_b]:
		ghost.extended_forward_sweep_degrees = pose.get("forward_sweep", 25.0)
	if figure.no_hands:
		_apply_no_hand_pose(pose)
		return
	if figure.single_hand:
		_apply_single_hand_pose(pose, figure.anchor_first_body)
		return
	_apply_pose(pose.centre, pose.turn, pose.flexion, pose.get("secondary_flexion", 0.0))
	if figure.separate_body_distance > 0.0:
		var centre: Vector2 = pose.centre
		var separate_offset := Vector2(0.0, -figure.separate_body_distance).rotated(pose.turn)
		var joining: float = pose.get("join_progress", 1.0)
		ghost_a.position = (centre - separate_offset * 0.5).lerp(ghost_a.position, joining)
		ghost_b.position = (centre + separate_offset * 0.5).lerp(ghost_b.position, joining)


func _apply_independent_arms(pose: Dictionary) -> void:
	var side: int = pose.get("hand_side", -1)
	ghost_a.set_current_arm_length(side, lerpf(ghost_a.maximum_arm_length, ghost_a.minimum_arm_length, pose.flexion))
	ghost_b.set_current_arm_length(-side, lerpf(ghost_b.maximum_arm_length, ghost_b.minimum_arm_length, pose.partner_flexion))
	ghost_a.set_current_arm_length(-side, lerpf(ghost_a.maximum_arm_length, ghost_a.minimum_arm_length, pose.get("free_flexion", 0.65)))
	ghost_b.set_current_arm_length(side, lerpf(ghost_b.maximum_arm_length, ghost_b.minimum_arm_length, pose.get("partner_free_flexion", 0.65)))


func _apply_no_hand_pose(pose: Dictionary) -> void:
	_apply_independent_arms(pose)
	# Floor travel and body facing are independent: an orbit need not be a spin.
	ghost_a.position = pose.centre + (pose.position_a as Vector2).rotated(pose.get("path_turn", 0.0))
	ghost_b.position = pose.centre + (pose.position_b as Vector2).rotated(pose.get("path_turn", 0.0))
	ghost_a.rotation = pose.turn
	ghost_b.rotation = pose.partner_turn
	ghost_a.queue_redraw()
	ghost_b.queue_redraw()


func _apply_single_hand_pose(pose: Dictionary, anchor_first_body: bool) -> void:
	_apply_independent_arms(pose)
	var side: int = pose.get("hand_side", -1)
	ghost_a.rotation = pose.turn
	ghost_b.rotation = pose.partner_turn
	var offset := ghost_a.get_hand_local_position(side).rotated(ghost_a.rotation) \
		- ghost_b.get_hand_local_position(-side).rotated(ghost_b.rotation) \
		+ (pose.get("release_offset", Vector2.ZERO) as Vector2)
	ghost_a.position = pose.centre if anchor_first_body else pose.centre - offset * 0.5
	ghost_b.position = ghost_a.position + offset
	# While fully released, B follows a floor path independently of either hand.
	# Contact selection can change there without moving the body abruptly.
	ghost_b.position = ghost_b.position.lerp(pose.get("release_position", ghost_b.position), pose.get("release_weight", 0.0))
	ghost_a.queue_redraw()
	ghost_b.queue_redraw()


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

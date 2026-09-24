class_name FigureDemonstration
extends Node2D

var FIGURES: Array[DanceFigure] = [
	preload("res://figures/travelling_turn.tres"),
	preload("res://figures/turn_in_place.tres"),
	preload("res://figures/alternating_sides.tres"),
	preload("res://figures/open_and_close.tres"),
	preload("res://figures/join_behind_back.tres"),
	preload("res://figures/connected_turn.tres"),
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
var VARIANTS := {
	"travelling_turn": [preload("res://figures/travelling_turn_mirrored.tres")],
	"turn_in_place": [preload("res://figures/turn_in_place_mirrored.tres")],
	"connected_turn": [preload("res://figures/connected_turn_reverse.tres")],
	"release_turn_catch": [preload("res://figures/release_turn_catch_mirrored.tres")],
	"open_out_return": [preload("res://figures/open_out_return_mirrored.tres")],
	"progressive_twinkles": [preload("res://figures/progressive_twinkles_mirrored.tres")],
	"open_impetus": [preload("res://figures/open_impetus_mirrored.tres")],
	"wing": [preload("res://figures/wing_mirrored.tres")],
	"weave_promenade": [preload("res://figures/weave_promenade_mirrored.tres")],
	"away_together": [preload("res://figures/away_together_mirrored.tres")],
	"solo_turns": [preload("res://figures/solo_turns_mirrored.tres")],
	"synchronous_spins": [preload("res://figures/synchronous_spins_mirrored.tres")],
	"mirror_spins": [preload("res://figures/mirror_spins_mirrored.tres")],
	"two_planets": [preload("res://figures/two_planets_mirrored.tres")],
	"spinning_planets": [preload("res://figures/spinning_planets_mirrored.tres")],
	"do_si_do": [preload("res://figures/do_si_do_mirrored.tres")],
	"travelling_turns": [preload("res://figures/travelling_turns_mirrored.tres")],
}
const OPACITY := 0.48
const END_PAUSE := 0.8
const FADE_TIME := 0.3

var selected_index := 0
var selected_variant := 0
var _remembered_variants: Dictionary = {}
var playback_speed := 1.0
var elapsed := 0.0
var ghost_a: Dancer
var ghost_b: Dancer
var _art: CanvasGroup
var _figure_glint: HandGlint
var _narrator: AudioStreamPlayer
var _narration_pending := false
var _caption: CanvasLayer
var _caption_label: Label
var demonstrations_enabled := true


func _ready() -> void:
	visible = false
	_art = CanvasGroup.new()
	add_child(_art)
	ghost_a = _make_ghost(0, Color("111111"), Color("f2f2f2"))
	ghost_b = _make_ghost(1, Color("f2f2f2"), Color("111111"))
	_figure_glint = HandGlint.new()
	_art.add_child(_figure_glint)
	_narrator = AudioStreamPlayer.new()
	_narrator.name = "FigureNarrator"
	add_child(_narrator)
	_build_caption()
	restart()


func _build_caption() -> void:
	_caption = CanvasLayer.new()
	_caption.layer = 5
	add_child(_caption)
	var layout := Control.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	layout.add_child(panel)
	var caption_width := 0.0
	for index in FIGURES.size():
		for figure in get_variants(index):
			caption_width = maxf(caption_width, BallroomTheme.BODY.get_string_size(
				figure.get_caption(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	caption_width = ceilf(caption_width) + 20.0
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -caption_width * 0.5
	panel.offset_top = -62.0
	panel.offset_right = caption_width * 0.5
	panel.offset_bottom = -22.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", BallroomTheme.panel(
		Color(0.09, 0.10, 0.08, 0.88), Color(0.78, 0.65, 0.42, 0.4), 10.0))
	_caption_label = Label.new()
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.add_theme_font_override("font", BallroomTheme.BODY)
	_caption_label.add_theme_font_size_override("font_size", 18)
	_caption_label.add_theme_color_override("font_color", BallroomTheme.IVORY)
	panel.add_child(_caption_label)
	_refresh_caption()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_refresh_caption()


func _refresh_caption() -> void:
	if not is_instance_valid(_caption):
		return
	_caption.visible = visible and not get_tree().paused
	_caption_label.text = get_figure().get_caption()


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
	# Menu selections queue narration; only start after gameplay resumes.
	# The animation wraps below without re-arming this one-shot introduction.
	if _narration_pending and not get_tree().paused:
		_narration_pending = false
		if _narrator.stream != null:
			_narrator.play()
	var cycle := get_figure().duration + END_PAUSE + FADE_TIME * 2.0
	elapsed = fposmod(elapsed + delta * playback_speed, cycle)
	_update_pose()


func get_figure() -> DanceFigure:
	return get_variants()[selected_variant]


func get_variants(index: int = -1) -> Array[DanceFigure]:
	var base := FIGURES[selected_index if index < 0 else index]
	var result: Array[DanceFigure] = [base]
	result.append_array(VARIANTS.get(base.resource_path.get_file().get_basename(), []))
	return result


func select_figure(index: int) -> void:
	selected_index = wrapi(index, 0, FIGURES.size())
	selected_variant = _remembered_variants.get(selected_index, 0)
	restart()


func select_variant(index: int) -> void:
	selected_variant = wrapi(index, 0, get_variants().size())
	_remembered_variants[selected_index] = selected_variant
	restart()


func set_demonstration_visible(enabled: bool) -> void:
	enabled = enabled and demonstrations_enabled
	visible = enabled
	if enabled:
		restart()
	else:
		_narration_pending = false
		_narrator.stop()
	_refresh_caption()


func restart() -> void:
	elapsed = 0.0
	if is_instance_valid(_art):
		_update_pose()
	if is_instance_valid(_narrator):
		_narrator.stop()
		_narrator.stream = get_figure().narration
		_narration_pending = visible and _narrator.stream != null
	_refresh_caption()


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
		_update_connection_glint(figure, pose, seconds)
		return
	if figure.single_hand:
		_apply_single_hand_pose(pose, figure.anchor_first_body)
		_update_connection_glint(figure, pose, seconds)
		return
	_apply_pose(pose.centre, pose.turn, pose.flexion, pose.get("secondary_flexion", 0.0))
	if figure.separate_body_distance > 0.0:
		var centre: Vector2 = pose.centre
		var separate_offset := Vector2(0.0, -figure.separate_body_distance).rotated(pose.turn)
		var joining: float = pose.get("join_progress", 1.0)
		ghost_a.position = (centre - separate_offset * 0.5).lerp(ghost_a.position, joining)
		ghost_b.position = (centre + separate_offset * 0.5).lerp(ghost_b.position, joining)
	_update_connection_glint(figure, pose, seconds)


func _update_connection_glint(figure: DanceFigure, pose: Dictionary, seconds: float) -> void:
	_figure_glint.points.clear()
	_figure_glint.queue_redraw()
	if not _pose_has_connection(figure, pose, seconds):
		return
	# Derive catches from the figure timeline so seeking, restarting and looping
	# produce the same cue, including a catch after a release or hand change.
	var catch_time := 0.0
	var was_joined := false
	var previous_side := 0
	for key in figure.get_keys():
		if float(key.time) > seconds:
			break
		var joined := _pose_has_connection(figure, key, float(key.time))
		var side := int(key.get("hand_side", -1))
		if joined and (not was_joined or (figure.single_hand and side != previous_side)):
			catch_time = float(key.time)
		was_joined = joined
		previous_side = side
	_figure_glint.age = (elapsed - catch_time) / maxf(playback_speed, 0.01)
	var sides: Array = [int(pose.get("hand_side", -1))] if figure.single_hand else [-1, 1]
	for side in sides:
		_figure_glint.points.append(_figure_glint.to_local(ghost_a.to_global(ghost_a.get_hand_local_position(side))))


func _pose_has_connection(figure: DanceFigure, pose: Dictionary, seconds: float) -> bool:
	return not figure.no_hands and seconds >= figure.joined_from \
		and is_equal_approx(float(pose.get("join_progress", 1.0)), 1.0) \
		and is_zero_approx(float(pose.get("release_weight", 0.0))) \
		and (pose.get("release_offset", Vector2.ZERO) as Vector2).is_zero_approx()


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

class_name SingleFigureDemonstration
extends FigureDemonstration


func _init() -> void:
	FIGURES = [
		preload("res://single_figures/two_planets.tres"),
		preload("res://single_figures/spinning_planets.tres"),
		preload("res://single_figures/do_si_do.tres"),
		preload("res://single_figures/mirror_slalom.tres"),
		preload("res://single_figures/passing_spirals.tres"),
		preload("res://single_figures/pendulum.tres"),
		preload("res://single_figures/moving_sun.tres"),
		preload("res://single_figures/open_out_return.tres"),
		preload("res://single_figures/travelling_wheel.tres"),
		preload("res://single_figures/release_spin_catch.tres"),
		preload("res://single_figures/alternating_catches.tres"),
		preload("res://single_figures/back_promenade.tres"),
		preload("res://single_figures/back_wheel.tres"),
		preload("res://single_figures/back_face_catch.tres"),
		preload("res://single_figures/open_close.tres"),
		preload("res://single_figures/turning_open_close.tres"),
		preload("res://single_figures/concertina.tres"),
		preload("res://single_figures/side_sway.tres"),
		preload("res://single_figures/two_to_one.tres"),
	]
	VARIANTS = {
		"two_planets": [preload("res://single_figures/two_planets_mirrored.tres")],
		"spinning_planets": [preload("res://single_figures/spinning_planets_mirrored.tres"), preload("res://single_figures/spinning_planets_reverse_spins.tres"), preload("res://single_figures/spinning_planets_reverse_spins_mirrored.tres"), preload("res://single_figures/spinning_planets_opposite.tres"), preload("res://single_figures/spinning_planets_opposite_mirrored.tres"), preload("res://single_figures/spinning_planets_opposite_reverse.tres"), preload("res://single_figures/spinning_planets_opposite_reverse_mirrored.tres")],
		"do_si_do": [preload("res://single_figures/do_si_do_mirrored.tres")],
		"mirror_slalom": [preload("res://single_figures/mirror_slalom_mirrored.tres")],
		"passing_spirals": [preload("res://single_figures/passing_spirals_mirrored.tres")],
		"pendulum": [preload("res://single_figures/pendulum_mirrored.tres")],
		"moving_sun": [preload("res://single_figures/moving_sun_mirrored.tres")],
		"open_out_return": [preload("res://single_figures/open_out_return_mirrored.tres")],
		"travelling_wheel": [preload("res://single_figures/travelling_wheel_mirrored.tres")],
		"release_spin_catch": [preload("res://single_figures/release_spin_catch_mirrored.tres")],
		"alternating_catches": [preload("res://single_figures/alternating_catches_mirrored.tres")],
		"back_promenade": [preload("res://single_figures/back_promenade_mirrored.tres")],
		"back_wheel": [preload("res://single_figures/back_wheel_mirrored.tres")],
		"back_face_catch": [preload("res://single_figures/back_face_catch_mirrored.tres")],
		"turning_open_close": [preload("res://single_figures/turning_open_close_mirrored.tres")],
		"concertina": [preload("res://single_figures/concertina_mirrored.tres")],
		"side_sway": [preload("res://single_figures/side_sway_mirrored.tres")],
		"two_to_one": [preload("res://single_figures/two_to_one_mirrored.tres")],
	}


func _make_ghost(style: int, body: Color, detail: Color) -> Dancer:
	var ghost := Dancer.new()
	ghost.body_style = style
	ghost.body_color = body
	ghost.detail_color = detail
	if style == 1:
		ghost.shoulder_half_width = 16.0
		ghost.upper_arm_length = 38.5
		ghost.forearm_length = 38.5
	ghost.single_player_spin = true
	ghost.freeze = true
	ghost.collision_layer = 0
	ghost.collision_mask = 0
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_art.add_child(ghost)
	return ghost



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
	var sides: Array = [int(pose.get("hand_side", -1))] if figure.single_hand and float(pose.get("double_weight", 0.0)) < 0.999 else [-1, 1]
	for side in sides:
		_figure_glint.points.append(_figure_glint.to_local(ghost_a.to_global(ghost_a.get_hand_local_position(side))))



func _apply_independent_arms(pose: Dictionary) -> void:
	# One trigger per dancer: both arms always have the same contraction.
	for side in [-1, 1]:
		ghost_a.set_current_arm_length(side, lerpf(ghost_a.maximum_arm_length, ghost_a.minimum_arm_length, pose.flexion))
		ghost_b.set_current_arm_length(side, lerpf(ghost_b.maximum_arm_length, ghost_b.minimum_arm_length, pose.get("partner_flexion", 0.0)))



func _apply_single_hand_pose(pose: Dictionary, anchor_first_body: bool) -> void:
	_apply_independent_arms(pose)
	var side: int = pose.get("hand_side", -1)
	ghost_a.rotation = pose.turn
	ghost_b.rotation = pose.partner_turn
	var offset := ghost_a.get_hand_local_position(side).rotated(ghost_a.rotation) \
		- ghost_b.get_hand_local_position(-side).rotated(ghost_b.rotation) \
		+ (pose.get("release_offset", Vector2.ZERO) as Vector2)
	ghost_a.position = pose.centre if anchor_first_body else pose.centre - offset * float(pose.get("anchor_weight", 0.5))
	ghost_b.position = ghost_a.position + offset
	# While fully released, B follows a floor path independently of either hand.
	# Contact selection can change there without moving the body abruptly.
	ghost_b.position = ghost_b.position.lerp(pose.get("release_position", ghost_b.position), pose.get("release_weight", 0.0))
	var double_weight: float = pose.get("double_weight", 0.0)
	if double_weight > 0.0:
		var a_rotation := ghost_a.rotation
		var b_rotation := ghost_b.rotation
		var b_length := ghost_b.get_current_arm_length(-1)
		_apply_pose(pose.centre, pose.get("double_turn", 0.0), pose.flexion)
		var fitted_length := ghost_b.get_current_arm_length(-1)
		for arm_side in [-1, 1]:
			ghost_b.set_current_arm_length(arm_side, lerpf(b_length, fitted_length, double_weight))
		ghost_a.rotation = lerp_angle(a_rotation, ghost_a.rotation, double_weight)
		ghost_b.rotation = lerp_angle(b_rotation, ghost_b.rotation, double_weight)
		# Keep the retained hand exact throughout second-hand acquisition/release.
		offset = ghost_a.get_hand_local_position(side).rotated(ghost_a.rotation) \
			- ghost_b.get_hand_local_position(-side).rotated(ghost_b.rotation)
		ghost_a.position = pose.centre - offset * 0.5
		ghost_b.position = pose.centre + offset * 0.5
	ghost_a.queue_redraw()
	ghost_b.queue_redraw()



func _apply_pose(centre: Vector2, turn: float, flexion: float, _secondary_flexion: float = 0.0) -> void:
	for side in [-1, 1]:
		ghost_a.set_current_arm_length(side, lerpf(ghost_a.maximum_arm_length, ghost_a.minimum_arm_length, flexion))
	var target_span := ghost_a.get_hand_local_position(-1).distance_to(ghost_a.get_hand_local_position(1))
	var low := 0.0
	var high := 1.0
	for iteration in 24:
		var blend := (low + high) * 0.5
		for side in [-1, 1]:
			ghost_b.set_current_arm_length(side, lerpf(ghost_b.maximum_arm_length, ghost_b.minimum_arm_length, blend))
		var span := ghost_b.get_hand_local_position(-1).distance_to(ghost_b.get_hand_local_position(1))
		if span > target_span:
			low = blend
		else:
			high = blend
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


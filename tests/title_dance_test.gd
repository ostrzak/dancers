extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	var dance: TitleDance = menu.entrance.title_dance
	dance.set_process(false)
	for _frame in 3:
		await process_frame
	dance.elapsed = 0
	dance._update_pose()
	var initial_distance := dance.ghost_a.position.distance_to(dance.ghost_b.position)
	_expect(initial_distance > 250.0, "intro begins with clearly separated dancers")
	var last_a := dance.ghost_a.position
	var last_b := dance.ghost_b.position
	var previous_distance := initial_distance
	var approaching := true
	var largest_step := 0.0
	var largest_gap := 0.0
	var smallest_body_gap := INF
	var all_in_stage := true
	for frame in range(1, 60 * 120 + 1):
		dance.elapsed = frame / 120.0
		dance._update_pose()
		var body_gap := dance.ghost_a.position.distance_to(dance.ghost_b.position)
		if dance.elapsed <= dance.APPROACH_TIME:
			approaching = approaching and body_gap <= previous_distance + 0.001
		previous_distance = body_gap
		smallest_body_gap = minf(smallest_body_gap, body_gap)
		largest_step = maxf(largest_step, maxf(last_a.distance_to(dance.ghost_a.position), last_b.distance_to(dance.ghost_b.position)))
		last_a = dance.ghost_a.position
		last_b = dance.ghost_b.position
		for side in [-1, 1]:
			if dance.elapsed >= dance.APPROACH_TIME:
				largest_gap = maxf(largest_gap, dance.ghost_a.to_global(dance.ghost_a.get_hand_local_position(side)).distance_to(dance.ghost_b.to_global(dance.ghost_b.get_hand_local_position(-side))))
			for ghost in [dance.ghost_a, dance.ghost_b]:
				var point: Vector2 = menu.entrance.dance_stage.get_global_transform().affine_inverse() * ghost.to_global(ghost.get_hand_local_position(side))
				all_in_stage = all_in_stage and Rect2(Vector2.ZERO, menu.entrance.dance_stage.size).grow(-12).has_point(point)
		for ghost in [dance.ghost_a, dance.ghost_b]:
			var body_point: Vector2 = menu.entrance.dance_stage.get_global_transform().affine_inverse() * ghost.global_position
			all_in_stage = all_in_stage and Rect2(Vector2.ZERO, menu.entrance.dance_stage.size).grow(-30 * dance.scale.x).has_point(body_point)
	_expect(approaching, "partners approach continuously before joining")
	_expect(largest_step < 2.0, "intro, hand connection and orbit have no position jumps")
	_expect(largest_gap < 0.001, "both handholds stay closed throughout the travelling turn")
	_expect(smallest_body_gap >= 40.0, "dancer torsos never overlap")
	_expect(all_in_stage, "the entire dance stays inside the right-hand display area")
	dance.elapsed = dance.TRAVEL_START + dance.SPEED_RAMP + 2.0
	dance._update_pose()
	var loop_a := dance.ghost_a.position
	var loop_b := dance.ghost_b.position
	var rotation_a := dance.ghost_a.rotation
	dance.elapsed += dance.LAP_TIME
	dance._update_pose()
	_expect(loop_a.distance_to(dance.ghost_a.position) < 0.001 and loop_b.distance_to(dance.ghost_b.position) < 0.001
		and absf(angle_difference(rotation_a, dance.ghost_a.rotation)) < 0.001, "each lap returns to the same pose without a reset")
	_expect(dance.ghost_a.freeze and dance.ghost_b.freeze and dance.ghost_a.collision_layer == 0 and dance.ghost_b.collision_mask == 0,
		"title dancers are isolated from gameplay physics")
	var prior := dance.elapsed
	dance._process(0.1)
	_expect(paused and dance.elapsed > prior, "title dance advances while gameplay is paused")
	_expect(is_equal_approx(dance.elapsed - prior, 0.15), "title dance plays fifty percent faster")
	menu.entrance.hide()
	prior = dance.elapsed
	dance._process(0.1)
	_expect(dance.elapsed == prior, "hidden title dance stops updating")
	paused = false
	scene.free()
	print("TITLE DANCE: %d/%d checks passed; max hand gap %.6f; max step %.3f" % [checks - failures, checks, largest_gap, largest_step])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

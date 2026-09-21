extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var demo := scene.figure_demonstration
	demo.set_process(false)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	var original_a := scene.left_dancer.position
	var original_b := scene.right_dancer.position
	_expect(not demo.visible and not menu.figure_toggle.button_pressed, "demonstrations start disabled in scene and menu")
	_expect(original_a == Vector2(150, 570) and original_b == Vector2(1130, 570), "players retain corner starts")
	var peak_gap := 0.0
	var minimum_distance := INF
	for index in demo.FIGURES.size():
		demo.select_figure(index)
		var figure_gap := 0.0
		var figure_clearance := INF
		var free_hand_clearance := INF
		var stays_on_floor := true
		var largest_step := 0.0
		var last_a := demo.ghost_a.position
		var last_b := demo.ghost_b.position
		var last_hands: Array[Vector2] = []
		for ghost in [demo.ghost_a, demo.ghost_b]:
			for side in [-1, 1]:
				last_hands.append(ghost.get_hand_world_position(side))
		for frame in range(int(demo.get_figure().duration * 120.0) + 1):
			demo.elapsed = frame / 120.0
			demo._update_pose()
			for side in [-1, 1]:
				var pose := demo.get_figure().sample(demo.elapsed)
				var check_contact: bool = not demo.get_figure().single_hand or (side == pose.get("hand_side", -1)
					and (pose.get("release_offset", Vector2.ZERO) as Vector2).is_zero_approx()
					and is_zero_approx(pose.get("release_weight", 0.0)))
				if check_contact and not demo.get_figure().no_hands and demo.elapsed >= demo.get_figure().joined_from:
					figure_gap = maxf(figure_gap, demo.ghost_a.get_hand_world_position(side).distance_to(
						demo.ghost_b.get_hand_world_position(-side)))
				for ghost in [demo.ghost_a, demo.ghost_b]:
					stays_on_floor = stays_on_floor and Rect2(30, 30, 1220, 660).has_point(ghost.get_hand_world_position(side))
				if demo.get_figure().no_hands:
					for other_side in [-1, 1]:
						free_hand_clearance = minf(free_hand_clearance, demo.ghost_a.get_hand_world_position(side).distance_to(
							demo.ghost_b.get_hand_world_position(other_side)))
			figure_clearance = minf(figure_clearance, demo.ghost_a.position.distance_to(demo.ghost_b.position))
			largest_step = maxf(largest_step, maxf(last_a.distance_to(demo.ghost_a.position), last_b.distance_to(demo.ghost_b.position)))
			last_a = demo.ghost_a.position
			last_b = demo.ghost_b.position
			var hand_index := 0
			for ghost in [demo.ghost_a, demo.ghost_b]:
				for side in [-1, 1]:
					var hand: Vector2 = ghost.get_hand_world_position(side)
					largest_step = maxf(largest_step, last_hands[hand_index].distance_to(hand))
					last_hands[hand_index] = hand
					hand_index += 1
		_expect(largest_step < 4.0, "%s: movement remains continuous (largest step %.3f px)" % [demo.get_figure().title, largest_step])
		_expect(figure_gap < 0.001, "%s: intended ghost handholds stay closed" % demo.get_figure().title)
		_expect(figure_clearance >= 40.0, "%s: ghost torsos never overlap" % demo.get_figure().title)
		_expect(stays_on_floor, "%s: all hands remain on the floor" % demo.get_figure().title)
		if demo.get_figure().no_hands:
			_expect(free_hand_clearance > 30.0, "%s: all four possible hand pairings remain visibly separate" % demo.get_figure().title)
		peak_gap = maxf(peak_gap, figure_gap)
		minimum_distance = minf(minimum_distance, figure_clearance)
	# Check the intended actions, not only contact geometry.
	for index in [5, 6, 7]:
		demo.select_figure(index)
		var fixed_position := demo.ghost_a.position
		var initial_turn := demo.ghost_b.rotation
		var fixed_throughout := true
		for frame in range(721):
			demo.elapsed = frame / 120.0
			demo._update_pose()
			fixed_throughout = fixed_throughout and demo.ghost_a.position.is_equal_approx(fixed_position)
		_expect(fixed_throughout, "%s: dark dancer stays in place" % demo.get_figure().title)
		_expect(is_equal_approx(demo.ghost_b.rotation - initial_turn, -TAU if index == 6 else TAU),
			"%s: light dancer completes a full turn" % demo.get_figure().title)
	for index in [5, 6]:
		demo.select_figure(index)
		var arms_closed := true
		for frame in range(156, 553):
			demo.elapsed = frame / 120.0
			demo._update_pose()
			arms_closed = arms_closed and demo.ghost_b.get_arm_flexion(-1) > 0.99 and demo.ghost_b.get_arm_flexion(1) > 0.99
		_expect(arms_closed, "%s: both turning arms remain fully closed throughout rotation" % demo.get_figure().title)
	demo.select_figure(7)
	_expect(absf(demo.ghost_a.position.x - demo.ghost_b.position.x) > 30.0,
		"release turn begins to one side of the partner")
	var passage_start := demo.ghost_b.position - demo.ghost_a.position
	demo.elapsed = 3.0
	demo._update_pose()
	_expect(demo.ghost_a.get_hand_world_position(-1).distance_to(demo.ghost_b.get_hand_world_position(1)) > 80.0,
		"release turn has a clearly separated free-spin interval")
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(demo.ghost_a.get_hand_world_position(1).distance_to(demo.ghost_b.get_hand_world_position(-1)) < 0.001
		and is_zero_approx(demo.ghost_b.get_arm_flexion(-1)), "release turn finishes extended and catches the opposite hand pair")
	_expect(passage_start.x < -50.0 and demo.ghost_b.position.x - demo.ghost_a.position.x > 50.0,
		"passage finishes on the opposite side of the partner")
	demo.select_figure(demo.FIGURES.find(load("res://figures/open_out_return.tres")))
	var open_start_a := demo.ghost_a.position
	var open_start_b := demo.ghost_b.position
	demo.elapsed = 3.0
	demo._update_pose()
	_expect(demo.ghost_a.position.distance_to(demo.ghost_b.position) > open_start_a.distance_to(open_start_b) + 50.0,
		"open out visibly widens the pair")
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(demo.ghost_a.position.is_equal_approx(open_start_a) and demo.ghost_b.position.is_equal_approx(open_start_b),
		"open out returns to its starting pose")
	# Figure-specific checks catch valid-looking but wrongly authored motion.
	_expect(demo.FIGURES.size() == 22, "seven no-hand additions bring the collection to twenty-two figures")
	_check_no_hand_figures(demo)
	var twinkles: DanceFigure = load("res://figures/progressive_twinkles.tres")
	demo.select_figure(demo.FIGURES.find(twinkles))
	var twinkle_initial := demo.ghost_b.position - demo.ghost_a.position
	demo.elapsed = 2.7
	demo._update_pose()
	var twinkle_other := demo.ghost_b.position - demo.ghost_a.position
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(twinkle_initial.x < -50 and twinkle_other.x > 50 and demo.ghost_b.position.x < demo.ghost_a.position.x - 50,
		"progressive twinkles alternate sides twice")
	_expect(demo.ghost_a.position.y > twinkles.sample(0.0).centre.y + 100,
		"twinkles progress down the floor")
	demo.select_figure(demo.FIGURES.find(load("res://figures/open_impetus.tres")))
	demo.elapsed = 4.1
	demo._update_pose()
	var impetus_forward_a := Dancer.LOCAL_FORWARD_DIRECTION.rotated(demo.ghost_a.rotation)
	var impetus_forward_b := Dancer.LOCAL_FORWARD_DIRECTION.rotated(demo.ghost_b.rotation)
	_expect(absf(impetus_forward_a.dot(impetus_forward_b)) < 0.01,
		"open impetus finishes in an open V")
	demo.select_figure(demo.FIGURES.find(load("res://figures/wing.tres")))
	var wing_start := demo.ghost_b.position - demo.ghost_a.position
	demo.elapsed = 3.0
	demo._update_pose()
	_expect(demo.ghost_b.position.y > demo.ghost_a.position.y + 100, "wing passes in front with clearance")
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(wing_start.x > 100 and demo.ghost_b.position.x < demo.ghost_a.position.x - 30,
		"wing crosses from right to left")
	demo.select_figure(demo.FIGURES.find(load("res://figures/weave_promenade.tres")))
	var weave_start := (demo.ghost_a.position + demo.ghost_b.position) * 0.5
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(((demo.ghost_a.position + demo.ghost_b.position) * 0.5).x > weave_start.x + 250
		and is_equal_approx(absf(demo.ghost_a.rotation - demo.ghost_b.rotation), PI),
		"weave travels across the floor and closes face-to-face")
	for resource_name in ["away_together", "solo_turns"]:
		demo.select_figure(demo.FIGURES.find(load("res://figures/%s.tres" % resource_name)))
		var initial_a := demo.ghost_a.position
		var initial_b := demo.ghost_b.position
		demo.elapsed = 3.0
		demo._update_pose()
		_expect(demo.ghost_a.position.distance_to(demo.ghost_b.position) > 150, "%s: dancers separate" % resource_name)
		demo.elapsed = 6.0
		demo._update_pose()
		_expect(demo.ghost_a.position.distance_to(initial_a) < 0.001 and demo.ghost_b.position.distance_to(initial_b) < 0.001,
			"%s: dancers return and reconnect" % resource_name)
		if resource_name == "solo_turns":
			_expect(is_equal_approx(demo.ghost_a.rotation, TAU) and is_equal_approx(demo.ghost_b.rotation, -PI),
				"solo turns complete opposite full revolutions")
	demo.select_figure(1)
	var turn_start := demo.get_figure().sample(0.0)
	var turn_end := demo.get_figure().sample(6.0)
	_expect(turn_start.centre == turn_end.centre and is_equal_approx(turn_end.turn - turn_start.turn, TAU),
		"turn in place completes one full revolution at a fixed centre")
	demo.select_figure(2)
	var first_side := demo.get_figure().sample(1.0)
	var other_side := demo.get_figure().sample(3.0)
	_expect(first_side.flexion == 0.5 and first_side.secondary_flexion == 0.0
		and other_side.flexion == 0.0 and other_side.secondary_flexion == 0.5,
		"alternating sides swaps the contracted contact")
	demo.select_figure(3)
	var closed := demo.get_figure().sample(1.5)
	var opened := demo.get_figure().sample(3.0)
	_expect(closed.flexion == 0.6 and closed.secondary_flexion == 0.6
		and opened.flexion == 0.0 and opened.secondary_flexion == 0.0
		and closed.centre != opened.centre, "open and close contracts both contacts while travelling")
	demo.select_figure(4)
	var apart_a := demo.ghost_a.position
	var apart_b := demo.ghost_b.position
	_expect(apart_a.distance_to(apart_b) > 100.0, "rear joining starts apart")
	demo.elapsed = 3.0
	demo._update_pose()
	_expect(demo.ghost_a.position == apart_a and demo.ghost_b.position == apart_b
		and demo.ghost_a.extended_forward_sweep_degrees == -25.0,
		"arms sweep backward before the bodies approach")
	demo.elapsed = 4.5
	demo._update_pose()
	var joined_a := demo.ghost_a.position
	var joined_b := demo.ghost_b.position
	_expect((joined_b - joined_a).dot(Dancer.LOCAL_FORWARD_DIRECTION.rotated(demo.ghost_a.rotation)) < 0.0,
		"joining finishes back-to-back")
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(demo.ghost_a.position == joined_a and demo.ghost_b.position == joined_b,
		"joined rear hold stays still")
	demo.select_figure(0)
	_expect(demo.ghost_a.extended_forward_sweep_degrees == 25.0, "switching figures restores the normal forward stance")
	_expect(scene.left_dancer.position == original_a and scene.right_dancer.position == original_b,
		"demonstration does not move players")
	_expect(demo.ghost_a.freeze and demo.ghost_b.freeze
		and demo.ghost_a.collision_layer == 0 and demo.ghost_a.collision_mask == 0
		and demo.ghost_b.collision_layer == 0 and demo.ghost_b.collision_mask == 0,
		"ghosts cannot participate in player physics")
	demo.elapsed = 3.0
	demo._update_pose()
	_expect(is_equal_approx(demo.ghost_a.get_arm_flexion(-1), 0.5)
		and is_equal_approx(demo.ghost_b.get_arm_flexion(1), 0.5), "joined side reaches half contraction")
	menu._pause()
	menu._switch_tab(3)
	_expect(menu.tabs.get_current_tab_control().name == "FIGURES"
		and root.gui_get_focus_owner() == menu.figure_toggle, "bumper tab navigation focuses demonstration toggle")
	_expect(not menu.figure_next.disabled and not menu.figure_previous.disabled, "multiple figures enable navigation")
	menu.figure_next.grab_focus()
	menu._activate_focused_control()
	_expect(demo.selected_index == 1 and menu.figure_name.text.contains("Turn in place")
		and menu.figure_description.text == demo.get_figure().description, "next selects figure and updates its instructions")
	menu.figure_previous.grab_focus()
	menu._activate_focused_control()
	menu._activate_focused_control()
	_expect(demo.selected_index == demo.FIGURES.size() - 1, "previous wraps to last figure")
	menu.figure_next.grab_focus()
	menu._activate_focused_control()
	_expect(demo.selected_index == 0 and demo.elapsed == 0.0, "next wraps to first figure and restarts")
	menu.figure_toggle.grab_focus()
	menu._activate_focused_control()
	_expect(demo.visible and demo.elapsed == 0.0, "controller confirm enables demonstration from the default off state")
	menu._activate_focused_control()
	_expect(not demo.visible, "controller confirm hides demonstration")
	menu._activate_focused_control()
	_expect(demo.visible and demo.elapsed == 0.0, "enabling demonstration restarts it")
	menu.figure_speed_buttons[0].grab_focus()
	menu._activate_focused_control()
	_expect(demo.playback_speed == 0.5, "controller confirm selects half speed")
	demo._process(2.0)
	_expect(is_equal_approx(demo.elapsed, 1.0), "half speed changes demonstration time only")
	menu.figure_restart.grab_focus()
	menu._activate_focused_control()
	_expect(demo.elapsed == 0.0, "restart button rewinds demonstration")
	demo.elapsed = 7.39
	demo._process(0.04)
	_expect(demo.elapsed < 0.02, "playback loops after hold and fade")
	menu._resume()
	demo.set_process(true)
	menu._pause()
	var paused_time := demo.elapsed
	for frame in 3:
		await process_frame
	_expect(demo.elapsed == paused_time, "opening pause menu pauses ghost playback")
	demo.select_figure(demo.FIGURES.size())
	_expect(demo.selected_index == 0 and scene.left_dancer.position == original_a,
		"figure selection wraps without resetting players")
	# Establish real double contacts, locks and momentum before using menu reset.
	scene.left_dancer.position = Vector2(600, 320)
	scene.left_dancer.rotation = 0.0
	scene.right_dancer.rotation = PI
	scene.right_dancer.position = scene.left_dancer.position + scene.left_dancer.get_hand_local_position(-1) \
		- scene.right_dancer.get_hand_local_position(1).rotated(PI)
	for side in [-1, 1]:
		scene.hand_connection.set_grip_button_state(scene.left_dancer, side, true)
		scene.hand_connection.set_grip_button_state(scene.right_dancer, -side, true)
	_expect(scene.hand_connection.get_active_connection_count() == 2, "reset scenario begins with two real holds")
	for dancer in [scene.left_dancer, scene.right_dancer]:
		dancer.set_position_lock_enabled(true)
		dancer.set_rotation_lock_enabled(true)
		dancer.linear_velocity = Vector2(100, 50)
		dancer.angular_velocity = 2.0
	menu.figure_reset_players.grab_focus()
	menu._activate_focused_control()
	_expect(not scene.hand_connection.has_any_connection(), "corner reset releases both real holds")
	_expect(scene.left_dancer.position == original_a and scene.right_dancer.position == original_b,
		"corner reset returns both players to spawn")
	for dancer in [scene.left_dancer, scene.right_dancer]:
		_expect(dancer.linear_velocity == Vector2.ZERO and dancer.angular_velocity == 0.0
			and not dancer.position_lock_active and not dancer.rotation_lock_active,
			"corner reset clears momentum and both locks")
	menu._resume()
	for frame in 8:
		await physics_frame
	_expect(scene.left_dancer.position.distance_to(original_a) < 0.1
		and scene.right_dancer.position.distance_to(original_b) < 0.1,
		"reset positions remain stable after physics resumes")
	print("FIGURE DEMONSTRATION: %d/%d checks passed; peak hand gap %.6f px; minimum torso distance %.3f px" % [checks - failures, checks, peak_gap, minimum_distance])
	quit(0 if failures == 0 else 1)


func _check_no_hand_figures(demo: FigureDemonstration) -> void:
	for name in ["synchronous_spins", "mirror_spins"]:
		demo.select_figure(demo.FIGURES.find(load("res://figures/%s.tres" % name)))
		var initial_a := demo.ghost_a.position
		var initial_b := demo.ghost_b.position
		var initial_turn_a := demo.ghost_a.rotation
		var initial_turn_b := demo.ghost_b.rotation
		var fixed_bodies := true
		for frame in range(721):
			demo.elapsed = frame / 120.0
			demo._update_pose()
			fixed_bodies = fixed_bodies and demo.ghost_a.position == initial_a and demo.ghost_b.position == initial_b
		_expect(fixed_bodies, "%s: both dancers stay in their own places" % name)
		_expect(is_equal_approx(demo.ghost_a.rotation - initial_turn_a, TAU)
			and is_equal_approx(demo.ghost_b.rotation - initial_turn_b, -TAU if name == "mirror_spins" else TAU),
			"%s: both full turns have the intended directions" % name)
	for name in ["two_planets", "spinning_planets"]:
		demo.select_figure(demo.FIGURES.find(load("res://figures/%s.tres" % name)))
		var initial_a := demo.ghost_a.position
		var initial_b := demo.ghost_b.position
		var initial_turn := demo.ghost_a.rotation
		var circular := true
		var faces_partner := true
		for frame in range(721):
			demo.elapsed = frame / 120.0
			demo._update_pose()
			circular = circular and absf(demo.ghost_a.position.distance_to(Vector2(640, 330)) - 110.0) < 0.001 \
				and absf(demo.ghost_a.position.distance_to(demo.ghost_b.position) - 220.0) < 0.001
			var toward_b := (demo.ghost_b.position - demo.ghost_a.position).normalized()
			faces_partner = faces_partner and toward_b.dot(Dancer.LOCAL_FORWARD_DIRECTION.rotated(demo.ghost_a.rotation)) > 0.999 \
				and -toward_b.dot(Dancer.LOCAL_FORWARD_DIRECTION.rotated(demo.ghost_b.rotation)) > 0.999
		_expect(circular and demo.ghost_a.position.distance_to(initial_a) < 0.001
			and demo.ghost_b.position.distance_to(initial_b) < 0.001, "%s: full circular orbit preserves spacing" % name)
		_expect(faces_partner == (name == "two_planets"), "%s: body facing distinguishes orbit from spin" % name)
		_expect(is_equal_approx(demo.ghost_a.rotation - initial_turn, TAU if name == "two_planets" else 2.0 * TAU),
			"%s: intended body revolutions" % name)
		demo.elapsed = 3.0
		demo._update_pose()
		_expect(demo.ghost_a.position.distance_to(initial_b) < 0.001, "%s: half an orbit reaches the opposite side" % name)
	demo.select_figure(demo.FIGURES.find(load("res://figures/do_si_do.tres")))
	var dosado_start_a := demo.ghost_a.position
	var dosado_start_b := demo.ghost_b.position
	var fixed_facing := true
	for frame in range(721):
		demo.elapsed = frame / 120.0
		demo._update_pose()
		fixed_facing = fixed_facing and is_zero_approx(demo.ghost_a.rotation) and is_equal_approx(demo.ghost_b.rotation, PI)
	_expect(fixed_facing and demo.ghost_a.position.distance_to(dosado_start_a) < 0.001
		and demo.ghost_b.position.distance_to(dosado_start_b) < 0.001, "do-si-do returns without turning the bodies")
	demo.elapsed = 3.0
	demo._update_pose()
	_expect(demo.ghost_a.position.distance_to(dosado_start_b) < 0.001
		and demo.ghost_b.position.distance_to(dosado_start_a) < 0.001, "do-si-do passes behind the partner halfway through")
	demo.select_figure(demo.FIGURES.find(load("res://figures/travelling_turns.tres")))
	var travel_start := demo.ghost_a.position
	demo.elapsed = 6.0
	demo._update_pose()
	_expect(demo.ghost_a.position.x - travel_start.x > 350.0
		and is_equal_approx(demo.ghost_a.rotation, TAU) and is_equal_approx(demo.ghost_b.rotation, TAU),
		"travelling turns move across the floor while both spin")
	demo.select_figure(demo.FIGURES.find(load("res://figures/mirror_paths.tres")))
	var mirrored := true
	var smallest_gap := INF
	var largest_gap := 0.0
	for frame in range(721):
		demo.elapsed = frame / 120.0
		demo._update_pose()
		mirrored = mirrored and absf(demo.ghost_a.position.x + demo.ghost_b.position.x - 1280.0) < 0.001 \
			and absf(demo.ghost_a.position.y - demo.ghost_b.position.y) < 0.001
		var gap := demo.ghost_a.position.distance_to(demo.ghost_b.position)
		smallest_gap = minf(smallest_gap, gap)
		largest_gap = maxf(largest_gap, gap)
	_expect(mirrored and largest_gap - smallest_gap > 150.0, "mirror paths remain symmetric while approaching and separating")


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

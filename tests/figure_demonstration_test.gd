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
	var peak_gap := 0.0
	var minimum_distance := INF
	for index in demo.FIGURES.size():
		demo.select_figure(index)
		var figure_gap := 0.0
		var figure_clearance := INF
		var stays_on_floor := true
		for frame in range(int(demo.get_figure().duration * 120.0) + 1):
			demo.elapsed = frame / 120.0
			demo._update_pose()
			for side in [-1, 1]:
				figure_gap = maxf(figure_gap, demo.ghost_a.get_hand_world_position(side).distance_to(
					demo.ghost_b.get_hand_world_position(-side)))
				for ghost in [demo.ghost_a, demo.ghost_b]:
					stays_on_floor = stays_on_floor and Rect2(30, 30, 1220, 660).has_point(ghost.get_hand_world_position(side))
			figure_clearance = minf(figure_clearance, demo.ghost_a.position.distance_to(demo.ghost_b.position))
		_expect(figure_gap < 0.001, "%s: both ghost handholds close throughout playback" % demo.get_figure().title)
		_expect(figure_clearance >= 40.0, "%s: ghost torsos never overlap" % demo.get_figure().title)
		_expect(stays_on_floor, "%s: all hands remain on the floor" % demo.get_figure().title)
		peak_gap = maxf(peak_gap, figure_gap)
		minimum_distance = minf(minimum_distance, figure_clearance)
	# Figure-specific checks catch valid-looking but wrongly authored motion.
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
	demo.select_figure(0)
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


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

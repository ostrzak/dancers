extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var demo := scene.figure_demonstration
	demo.set_process(false)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	var player_a := scene.left_dancer.position
	var player_b := scene.right_dancer.position
	var total := 0
	for index in demo.FIGURES.size():
		demo.select_figure(index)
		var variants := demo.get_variants()
		total += variants.size()
		for variant in variants.size():
			demo.select_variant(variant)
			var figure := demo.get_figure()
			_expect(variants.size() == 1 or not figure.variant_label.is_empty(), "%s has a variant label" % figure.title)
			_expect(not figure.description.is_empty(), "%s has instructions" % figure.get_caption())
			_expect(not figure.description.contains("dark dancer") and not figure.description.contains("light dancer"),
				"%s uses ballroom roles" % figure.get_caption())
			if figure.mirror_of == null:
				continue
			var reflected := true
			var hands_reflected := true
			for frame in range(25):
				var seconds := figure.duration * frame / 24.0
				demo.select_variant(0)
				demo.elapsed = seconds
				demo._update_pose()
				var bodies: Array[Vector2] = [demo.ghost_a.position, demo.ghost_b.position]
				var facing: Array[Vector2] = [Vector2.DOWN.rotated(demo.ghost_a.rotation), Vector2.DOWN.rotated(demo.ghost_b.rotation)]
				var hands: Array[Vector2] = []
				for ghost in [demo.ghost_a, demo.ghost_b]:
					for side in [-1, 1]:
						hands.append(ghost.get_hand_world_position(side))
				demo.select_variant(variant)
				demo.elapsed = seconds
				demo._update_pose()
				for partner in 2:
					var ghost: Dancer = demo.ghost_a if partner == 0 else demo.ghost_b
					reflected = reflected and ghost.position.distance_to(Vector2(1280.0 - bodies[partner].x, bodies[partner].y)) < 0.001
					reflected = reflected and Vector2.DOWN.rotated(ghost.rotation).distance_to(Vector2(-facing[partner].x, facing[partner].y)) < 0.001
					for hand in 2:
						var original := hands[partner * 2 + hand]
						var actual := ghost.get_hand_world_position(1 if hand == 0 else -1)
						hands_reflected = hands_reflected and actual.distance_to(Vector2(1280.0 - original.x, original.y)) < 0.001
			_expect(reflected, "%s reflects paths and facing throughout the movement" % figure.get_caption())
			_expect(hands_reflected, "%s reflects anatomical hands and catches" % figure.get_caption())
			demo.select_variant(0)
	_expect(total == 38, "21 figure entries contain 38 demonstrations")
	# Connected turn reverses rotation without exchanging hands or starting pose.
	demo.select_figure(5)
	demo.select_variant(0)
	var clockwise := demo.get_figure()
	demo.select_variant(1)
	var counterclockwise := demo.get_figure()
	_expect(clockwise.sample(0.0) == counterclockwise.sample(0.0), "Connected turns share exactly the same starting pose")
	_expect(is_equal_approx(counterclockwise.sample(counterclockwise.duration).partner_turn - counterclockwise.sample(0.0).partner_turn, -TAU),
		"Connected counterclockwise variant performs a negative full turn")
	_expect(clockwise.narration == null and counterclockwise.narration == null, "Outdated colour-based recordings are detached")
	# Exercise the actual menu controls, including retained selections and silence.
	menu._pause()
	menu._switch_tab(3)
	# Let containers lay out before testing native focus navigation and bounds.
	await process_frame
	await process_frame
	var layouts_fit := true
	for index in demo.FIGURES.size():
		demo.select_figure(index)
		for variant in demo.get_variants().size():
			demo.select_variant(variant)
			menu._refresh_figure_labels()
			await process_frame
			await process_frame
			var panel: Control = menu.get_node("Center/Panel")
			var bounds := panel.get_global_rect()
			layouts_fit = layouts_fit and bounds.position.y >= -0.1 and bounds.end.y <= root.get_visible_rect().size.y + 0.1
			layouts_fit = layouts_fit and menu.figure_description.get_line_count() == menu.figure_description.get_visible_line_count()
	_expect(layouts_fit, "All variant descriptions and menu controls fit the viewport")
	demo.select_figure(0)
	demo.select_variant(0)
	demo.set_demonstration_visible(true)
	demo.playback_speed = 0.75
	demo.elapsed = 2.0
	menu._refresh_figure_labels()
	await process_frame
	await process_frame
	menu.figure_previous.grab_focus()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down)
	_expect(menu.figure_variant_previous.has_focus(), "Native Down navigation reaches the variant selector")
	down.pressed = false
	root.push_input(down)
	menu.figure_variant_next.grab_focus()
	menu._activate_focused_control()
	_expect(demo.selected_variant == 1 and demo.elapsed == 0.0 and demo.playback_speed == 0.75,
		"Controller activation switches variant, restarts, and preserves speed")
	_expect(menu.figure_description.text == demo.get_figure().description and menu.figure_variant_name.text.contains("Counterclockwise"),
		"Variant label and instructions follow selection")
	_expect(demo._caption_label.text == "Travelling turn · Counterclockwise" and not demo._caption.visible,
		"Caption identifies variant and remains hidden in menu")
	_expect(not demo._narrator.playing and demo._narration_pending, "Variant narration waits for resume")
	menu._resume()
	demo._process(0.0)
	_expect(demo._narrator.playing and demo._caption.visible, "Resuming plays compatible narration and shows variant caption")
	menu._pause()
	menu._select_figure(1)
	menu._select_figure(-1)
	_expect(demo.selected_variant == 1, "Returning to a figure remembers its variant")
	menu.figure_variant_next.grab_focus()
	menu._activate_focused_control()
	_expect(demo.selected_variant == 0, "Next variant wraps")
	menu.figure_variant_previous.grab_focus()
	menu._activate_focused_control()
	_expect(demo.selected_variant == 1, "Previous variant wraps")
	demo.select_figure(2)
	menu._refresh_figure_labels()
	_expect(not menu.figure_variant_row.visible and menu.figure_variant_next.disabled, "Single-version figure hides variant controls")
	demo.select_figure(5)
	menu._refresh_figure_labels()
	menu._select_figure_variant(1)
	menu._resume()
	demo._process(0.1)
	_expect(not demo._narrator.playing and not demo._narration_pending and demo.elapsed > 0.0,
		"Unrecorded variant plays silently without falling back to outdated narration")
	_expect(scene.left_dancer.position == player_a and scene.right_dancer.position == player_b,
		"Variant selection never moves players")
	print("FIGURE VARIANTS: %d/%d checks passed" % [checks - failures, checks])
	scene.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)

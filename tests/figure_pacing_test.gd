extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var demo := FigureDemonstration.new()
	root.add_child(demo)
	demo.set_process(false)
	for index in demo.FIGURES.size():
		demo.select_figure(index)
		for variant in demo.get_variants().size():
			demo.select_variant(variant)
			var figure := demo.get_figure()
			var body_speed := 0.0
			var hand_speed := 0.0
			var turn_speed := 0.0
			var positions: Array[Vector2] = []
			var turns: Array[float] = []
			for frame in range(int(figure.duration * 240) + 1):
				demo.elapsed = frame / 240.0
				demo._update_pose()
				var current: Array[Vector2] = []
				var rotations: Array[float] = []
				for ghost in [demo.ghost_a, demo.ghost_b]:
					current.append(ghost.position)
					current.append(ghost.get_hand_world_position(-1))
					current.append(ghost.get_hand_world_position(1))
					rotations.append(ghost.rotation)
				if frame > 0:
					for p in current.size():
						var speed := current[p].distance_to(positions[p]) * 240.0
						if p % 3 == 0:
							body_speed = maxf(body_speed, speed)
						else:
							hand_speed = maxf(hand_speed, speed)
					for p in rotations.size():
						turn_speed = maxf(turn_speed, absf(wrapf(rotations[p] - turns[p], -PI, PI)) * 240.0)
				positions = current
				turns = rotations
			_expect(body_speed <= 150.5, figure.get_caption() + ": body speed stays readable")
			_expect(hand_speed <= 180.5, figure.get_caption() + ": hand motion stays readable")
			_expect(rad_to_deg(turn_speed) <= 110.5, figure.get_caption() + ": turns stay readable")
			_expect(is_equal_approx(float(figure.get_keys()[-1].time), figure.duration), figure.get_caption() + ": timeline ends with the loop")
			if figure.mirror_of != null:
				_expect(figure.duration == figure.mirror_of.duration, figure.get_caption() + ": mirrored timing matches")
			print("PACE %s body=%.1f hands=%.1f turn=%.1f duration=%.1f" % [figure.resource_path.get_file(), body_speed, hand_speed, rad_to_deg(turn_speed), figure.duration])
	demo.free()
	print("FIGURE PACING: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

extends SceneTree

var failures := 0


class FrameObserver extends Node:
	signal frame_completed

	func _physics_process(_delta: float) -> void:
		frame_completed.emit()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scenario in [[75, 75, false], [120, 40, false], [40, 120, false], [75, 75, true]]:
		var weights := Vector2(scenario[0], scenario[1])
		var same_sides: bool = scenario[2]
		if OS.get_cmdline_user_args().has("--same-sides-only") and not same_sides:
			continue
		var scene: PrototypeController = load("res://prototype.tscn").instantiate()
		get_root().add_child(scene)
		scene.set_physics_process(false)
		scene.set_process_input(false)
		scene.get_node("TelemetryRecorder").set_physics_process(false)
		var man := scene.left_dancer
		var woman := scene.right_dancer
		var hold := scene.hand_connection
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--position-iterations="):
				hold.rigid_position_iterations = int(argument.get_slice("=", 1))
		var observer := FrameObserver.new()
		observer.process_physics_priority = 2000
		scene.add_child(observer)
		man.set_weight_kg(weights.x)
		woman.set_weight_kg(weights.y)
		man.position = Vector2(640, 320)
		woman.rotation = PI
		woman.position = man.position + man.get_hand_local_position(1) - woman.get_hand_local_position(-1).rotated(PI)
		if same_sides:
			woman.rotation = 0.0
			woman.position = man.position + Vector2(0, 45)
		for dancer in [man, woman]:
			dancer._update_unwrapped_rotation()
		for side in [-1, 1]:
			hold.set_grip_button_state(man, side, true)
			hold.set_grip_button_state(woman, side if same_sides else -side, true)
		var peak_gap := 0.0
		var peak_gap_frame := 0
		var peak_span_error := 0.0
		var peak_flexions := Vector4.ZERO
		var minimum_body_distance := INF
		var maximum_speed := 0.0
		var maximum_effort := 0.0
		var finite_state := true
		for frame in 840:
			var phase := int(frame / 120)
			var target := Vector2.from_angle(float(frame) * 0.025)
			match phase:
				0:
					man.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
					woman.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
				1:
					man.set_control_input(Vector2.RIGHT, target, 0.4, 0.4)
					woman.set_control_input(Vector2.LEFT, -target * 0.3, 0.4, 0.4)
				2:
					man.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 0.0)
					woman.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
				3:
					man.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0)
					woman.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0)
				4:
					man.adjust_extended_arm_pose(0.6, 0.3, 1.0 / 120.0)
					woman.adjust_extended_arm_pose(-0.6, -0.3, 1.0 / 120.0)
					man.set_control_input(Vector2.ZERO, target, 0.2, 0.4)
					woman.set_control_input(Vector2.ZERO, -target, 0.4, 0.2)
				_:
					man.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
					woman.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
			await observer.frame_completed
			if frame >= 30:
				var gap := _maximum_gap(hold)
				if gap > peak_gap:
					peak_gap = gap
					peak_gap_frame = frame
					peak_span_error = hold._get_double_hold_span_error()
					peak_flexions = Vector4(man.get_arm_flexion(-1), man.get_arm_flexion(1), woman.get_arm_flexion(-1), woman.get_arm_flexion(1))
				minimum_body_distance = minf(minimum_body_distance, man.position.distance_to(woman.position))
			maximum_speed = maxf(maximum_speed, maxf(man.linear_velocity.length(), woman.linear_velocity.length()))
			maximum_effort = maxf(maximum_effort, hold.double_hold_maximum_effort)
			finite_state = finite_state and man.position.is_finite() and woman.position.is_finite()
			finite_state = finite_state and man.linear_velocity.is_finite() and woman.linear_velocity.is_finite()
		var previous_spin := Vector2(man.angular_velocity, woman.angular_velocity)
		var squared_spin_steps := 0.0
		for frame in 480:
			await observer.frame_completed
			var spin := Vector2(man.angular_velocity, woman.angular_velocity)
			if frame >= 360:
				squared_spin_steps += (spin - previous_spin).length_squared()
			previous_spin = spin
		var tail_rms := sqrt(squared_spin_steps / 120.0)
		print("COMBINED HOLD weights=%s same_sides=%s gap=%.4f minimum_body_distance=%.4f max_speed=%.3f max_effort=%.3f tail_spin_step_rms=%.6f" % [
			weights, same_sides, peak_gap, minimum_body_distance, maximum_speed, maximum_effort, tail_rms])
		print("peak gap frame=%d span_error=%.5f flexions=%s" % [peak_gap_frame, peak_span_error, peak_flexions])
		_check(hold.get_active_connection_count() == 2 and finite_state, "combined input preserves both holds and finite state")
		_check(peak_gap <= 0.25, "radial RS, trigger changes and independent D-pad keep both rigid contacts closed")
		_check(minimum_body_distance >= 39.0, "full flexion respects the fixed torso circles")
		_check(maximum_speed < 2000.0 and tail_rms < 0.15, "extreme weights settle without sustained jitter")
		_check(maximum_effort > 0.9, "unmatched trigger pressure restores strong red-arm feedback")
		observer.set_physics_process(false)
		scene.queue_free()
		await process_frame
	print("COMBINED HOLD: %d failures" % failures)
	quit(1 if failures else 0)


func _maximum_gap(hold: HandConnection) -> float:
	var maximum := 0.0
	for sides in [hold.get_connected_hand_sides(), hold.get_secondary_connected_hand_sides()]:
		maximum = maxf(maximum, hold.dancer_a.get_hand_world_position(sides[0]).distance_to(
			hold.dancer_b.get_hand_world_position(sides[1])))
	return maximum


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

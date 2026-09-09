extends SceneTree

const CAPTURE := "res://tests/fixtures/handhold-stability-2026-09-09.json"

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAPTURE))
	var samples: Array = capture.samples
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	get_root().add_child(scene)
	scene.set_physics_process(false)
	scene.get_node("TelemetryRecorder").set_physics_process(false)
	var dancers: Array[Dancer] = [scene.left_dancer, scene.right_dancer]
	var reference := OS.get_cmdline_user_args().has("--reference-mass")
	var extreme := OS.get_cmdline_user_args().has("--extreme-weights")
	for index in 2:
		var dancer := dancers[index]
		var sample: Dictionary = samples[0]["left_dancer" if index == 0 else "right_dancer"]
		dancer.freeze = true
		dancer.position = _vector(sample.position)
		dancer.rotation = sample.rotation_radians
		if extreme:
			dancer.set_weight_kg(120.0 if index == 0 else 40.0)
		elif not reference:
			# The exact captured input was recorded with 85/60 kg dancers.
			dancer.set_weight_kg(85.0 if index == 0 else 60.0)
		if reference:
			# Reproduce pre-weight physics: both bodies 1.2, unscaled arm inertia.
			dancer.weight_kg = 75.0
			dancer.mass = 1.2
			dancer._update_effective_inertia()
	await physics_frame
	for index in 2:
		var sample: Dictionary = samples[0]["left_dancer" if index == 0 else "right_dancer"]
		dancers[index].freeze = false
		dancers[index].linear_velocity = _vector(sample.linear_velocity)
		dancers[index].angular_velocity = sample.angular_velocity
	var cursor := 0
	var first_frame := int(samples[0].physics_frame)
	var last_frame := int(samples[-1].physics_frame)
	var peak_gap := 0.0
	var settled_peak_gap := 0.0
	var tail_delta_squared := 0.0
	var tail_samples := 0
	var previous_spin := Vector2.ZERO
	for frame in range(first_frame, last_frame + 1):
		while cursor + 1 < samples.size() and int(samples[cursor + 1].physics_frame) <= frame:
			cursor += 1
		for index in 2:
			var dancer := dancers[index]
			var sample: Dictionary = samples[cursor]["left_dancer" if index == 0 else "right_dancer"]
			var input: Dictionary = sample.input
			dancer.set_control_input(_vector(input.movement), _vector(input.facing),
				input.left_trigger, input.right_trigger, input.position_lock, input.rotation_lock)
			for side in [-1, 1]:
				scene.hand_connection.set_grip_button_state(dancer, side,
					sample.hands["left" if side == -1 else "right"].button_down)
		await physics_frame
		if scene.hand_connection.is_connected:
			var sides := scene.hand_connection.get_connected_hand_sides()
			peak_gap = maxf(peak_gap, dancers[0].get_hand_world_position(sides[0]).distance_to(
				dancers[1].get_hand_world_position(sides[1])))
			if scene.hand_connection.primary_snap_remaining <= 0.0:
				settled_peak_gap = maxf(settled_peak_gap, dancers[0].get_hand_world_position(sides[0]).distance_to(
					dancers[1].get_hand_world_position(sides[1])))
		var spin := Vector2(dancers[0].angular_velocity, dancers[1].angular_velocity)
		if frame > last_frame - 240:
			tail_delta_squared += (spin - previous_spin).length_squared()
			tail_samples += 1
		previous_spin = spin
	var tail_rms := sqrt(tail_delta_squared / maxf(tail_samples, 1))
	print("CAPTURE REPLAY reference_mass=%s extreme=%s acquisition_gap=%.4f settled_gap=%.4f tail_spin_step_rms=%.4f final_spin=%s holds=%d" % [
		reference, extreme, peak_gap, settled_peak_gap, tail_rms, previous_spin, scene.hand_connection.get_active_connection_count()])
	var passed := settled_peak_gap <= 0.25 and tail_rms < 0.15 and scene.hand_connection.get_active_connection_count() == 1
	quit(0 if passed else 1)


func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

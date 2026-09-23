extends SceneTree

var checks := 0
var failures := 0

class FrameObserver extends Node:
	signal completed
	func _physics_process(_delta: float) -> void:
		completed.emit()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in ["res://tests/fixtures/single-rear-catches-2026-09-23.json", "res://tests/fixtures/single-rear-placement-2026-09-23.json"]:
		var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for sample in capture.samples:
			await _rear_catch(sample)
	await _walking_speed()
	print("SINGLE REAR HOLD / SPEED: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _rear_catch(sample: Dictionary) -> void:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.start_session(PrototypeController.PlayMode.SINGLE)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	var observer := FrameObserver.new()
	observer.process_physics_priority = 2000
	scene.add_child(observer)
	var a := scene.left_dancer
	var b := scene.right_dancer
	var hold := scene.hand_connection
	for item in [[a, sample.left_dancer], [b, sample.right_dancer]]:
		var dancer: Dancer = item[0]
		var state: Dictionary = item[1]
		dancer.reset_to_pose(_vector(state.position), state.rotation_radians)
		dancer.linear_velocity = _vector(state.linear_velocity)
		dancer.angular_velocity = state.angular_velocity
		dancer.intended_spin_direction = state.intended_spin_direction
		dancer.extended_elbow_flexion_degrees = state.stance.elbow_flexion_degrees
		dancer.extended_forward_sweep_degrees = state.stance.forward_sweep_degrees
		for side in [-1, 1]:
			dancer.set_current_arm_length(side, state.arm_lengths[0 if side == -1 else 1])
	# Restore the already settled RB hold; LB is the failed second catch.
	hold._connect_pair(sample.hand_connection.left_dancer_hand_side,
		sample.hand_connection.right_dancer_hand_side, false)
	hold.primary_snap_remaining = 0.0
	hold._primary_catch_separation = 0.0
	scene.single_controls.owned_slots[1] = 1
	scene.single_controls.update_hands(hold, false, false)
	scene.single_controls.update_hands(hold, true, false)
	_check(hold.get_active_connection_count() == 2, "captured second pair is within catch limits")
	var peak_gap := 0.0
	var minimum_distance := INF
	var stayed_rear := true
	var peak_arm_asymmetry := 0.0
	var peak_neutral_spin_request := 0.0
	for frame in 360:
		if frame == 120:
			scene.single_controls.apply_steering(a, b, Vector2.ZERO, Vector2.ZERO, 0.4, 0.8)
		if frame >= 240:
			scene.single_controls.apply_steering(a, b, Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
			scene._apply_arm_pose_inputs(Vector2.UP, Vector2.UP, 1.0 / 120.0)
		await observer.completed
		minimum_distance = minf(minimum_distance, a.position.distance_to(b.position))
		stayed_rear = stayed_rear and (b.position - a.position).rotated(-a.rotation).y < 0.0
		if frame > 30:
			peak_gap = maxf(peak_gap, maxf(hold.primary_hand_separation, hold.secondary_hand_separation))
			for dancer in [a, b]:
				peak_arm_asymmetry = maxf(peak_arm_asymmetry, absf(dancer.get_arm_flexion(-1) - dancer.get_arm_flexion(1)))
				if frame < 120 or frame >= 240:
					peak_neutral_spin_request = maxf(peak_neutral_spin_request, absf(dancer.target_angular_velocity))
	_check(hold.get_active_connection_count() == 2, "captured rear second catch remains connected")
	_check(stayed_rear, "rear catch never flips through partners into front hold")
	_check(minimum_distance >= 23.99, "rear catch keeps torso clearance")
	_check(peak_gap < 0.1, "rear catch settles both hands within tolerance")
	_check(a.position.is_finite() and b.position.is_finite(), "rear hold remains finite")
	_check(scene.single_controls.owned_slots == [2, 1], "rear catch retains LB/RB ownership")
	_check(peak_arm_asymmetry < 0.00001, "single-player rear solve keeps each dancer's arms paired")
	_check(peak_neutral_spin_request == 0.0, "rear compatibility flexion never commands unrequested spin")
	print("captured frame=%d rear_hold_count=%d gap=%.5f min_distance=%.4f" % [sample.physics_frame, hold.get_active_connection_count(), peak_gap, minimum_distance])
	scene.queue_free()
	await process_frame


func _walking_speed() -> void:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	var observer := FrameObserver.new()
	observer.process_physics_priority = 2000
	scene.add_child(observer)
	var speeds: Array[float] = []
	for mode in [PrototypeController.PlayMode.COOP, PrototypeController.PlayMode.SINGLE]:
		scene.start_session(mode)
		var dancer := scene.left_dancer
		dancer.reset_to_pose(Vector2(200, 350), 0.0)
		dancer.set_control_input(Vector2.RIGHT, Vector2.ZERO, 0.0, 0.0)
		for frame in 90:
			await observer.completed
		speeds.append(dancer.linear_velocity.x)
		# Identical held state must continue receiving the original input force.
		dancer.hand_connection_count = 1
		dancer._free_movement_blend = 0.0
		dancer.linear_velocity = Vector2.ZERO
		dancer._apply_movement_force()
		_check(dancer.diagnostic_movement_force.is_equal_approx(Vector2(900, 0)), "held movement force is unchanged in either mode")
	_check(absf(speeds[0] - 360.0) < 2.0, "co-op free walking stays at 360 px/s")
	_check(absf(speeds[1] - 234.0) < 2.0, "single free walking settles at 234 px/s")
	# Carry is added after the walking reduction, so an idle released dancer
	# never has its inherited velocity scaled down by the free-speed setting.
	var dancer := scene.left_dancer
	dancer._free_movement_blend = 1.0
	dancer.movement_input = Vector2.ZERO
	dancer.linear_velocity = Vector2(100, 0)
	dancer.partner_carry_velocity = Vector2(100, 0)
	dancer._apply_movement_force()
	_check(dancer.diagnostic_movement_force.is_zero_approx(), "free-speed scale does not brake received partner carry")
	print("free walking coop=%.2f single=%.2f" % [speeds[0], speeds[1]])
	scene.queue_free()
	await process_frame


func _vector(value: Array) -> Vector2:
	return Vector2(value[0], value[1])


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

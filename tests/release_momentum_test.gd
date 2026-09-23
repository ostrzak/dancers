extends SceneTree

var failures := 0
var checks := 0


class FrameObserver extends Node:
	signal frame_completed

	func _physics_process(_delta: float) -> void:
		frame_completed.emit()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for weights in [Vector2(75, 75), Vector2(120, 40), Vector2(40, 120)]:
		for direction in [-1.0, 1.0]:
			var results: Array[float] = []
			for input_sign in [0.0, 1.0, -1.0]:
				results.append(await _release_scenario(weights, direction, input_sign))
			_check(results[1] > results[0], "LS along release direction extends travel")
			_check(results[2] < results[0], "opposite LS brakes released travel")
	for direction in [-1.0, 1.0]:
		await _release_scenario(Vector2(75, 75), direction, 0.0, true)
	print("RELEASE MOMENTUM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _release_scenario(weights: Vector2, direction: float, input_sign: float, anchored: bool = false) -> float:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	scene.get_node("TelemetryRecorder").set_physics_process(false)
	var leader := scene.left_dancer
	var partner := scene.right_dancer
	var hold := scene.hand_connection
	var observer := FrameObserver.new()
	observer.process_physics_priority = 2000
	scene.add_child(observer)
	leader.set_weight_kg(weights.x)
	partner.set_weight_kg(weights.y)
	var flexion := 0.0 if anchored else 0.6
	for dancer in [leader, partner]:
		for side in [-1, 1]:
			dancer.set_current_arm_length(side, lerpf(dancer.maximum_arm_length, dancer.minimum_arm_length, flexion))
		dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, flexion, flexion)
	leader.position = Vector2(640, 360)
	leader.rotation = 0.0
	partner.rotation = PI
	partner.position = leader.position + leader.get_hand_offset(1) - partner.get_hand_offset(-1)
	for dancer in [leader, partner]:
		dancer._update_unwrapped_rotation()
	leader.set_position_lock_enabled(anchored)
	hold.set_grip_button_state(leader, 1, true)
	hold.set_grip_button_state(partner, -1, true)
	for frame in 40:
		await observer.frame_completed
	_check(hold.is_connected, "short-arm pair catches before circling")
	var previous_position := partner.position
	var observed_velocity := Vector2.ZERO
	var peak_gap := 0.0
	var peak_speed := 0.0
	for frame in (360 if anchored else 120):
		leader.set_control_input(Vector2.ZERO, Vector2.DOWN.rotated(direction * float(frame + 1) * (0.07 if anchored else 0.025)), flexion, flexion, anchored)
		previous_position = partner.position
		await observer.frame_completed
		observed_velocity = (partner.position - previous_position) * 120.0
		peak_gap = maxf(peak_gap, leader.get_hand_world_position(1).distance_to(partner.get_hand_world_position(-1)))
		peak_speed = maxf(peak_speed, partner.linear_velocity.length())
	var release_velocity := partner.linear_velocity
	var leader_velocity := leader.linear_velocity
	var release_spin := Vector2(leader.angular_velocity, partner.angular_velocity)
	_check(peak_speed < 550.0, "connected turning cannot build the recorded runaway travelling speed")
	_check(release_velocity.length() > 10.0, "RS circling builds real partner travel with neutral LS")
	_check(peak_gap < 0.1, "circling keeps the settled handhold closed")
	_check(observed_velocity.normalized().dot(release_velocity.normalized()) > 0.8,
		"release velocity follows the visible travelling direction")
	if input_sign == 0.0:
		print("weights=%s turn=%s speed=%.2f observed=%.2f alignment=%.3f gap=%.4f spins=%s" % [
			weights, direction, release_velocity.length(), observed_velocity.length(),
			observed_velocity.normalized().dot(release_velocity.normalized()), peak_gap, release_spin])
	hold.release_hands()
	_check(partner.linear_velocity == release_velocity and leader.linear_velocity == leader_velocity
		and Vector2(leader.angular_velocity, partner.angular_velocity) == release_spin,
		"release changes neither dancer's velocity or spin")
	# Isolate free coasting/braking from a possible collision with the other
	# released body. Production release retains the normal torso collisions.
	leader.add_collision_exception_with(partner)
	partner.add_collision_exception_with(leader)
	leader.set_control_input(Vector2.ZERO, Vector2.ZERO, flexion, flexion, anchored)
	partner.set_control_input(release_velocity.normalized() * input_sign, Vector2.ZERO, flexion, flexion)
	var release_position := partner.position
	for frame in 30:
		await observer.frame_completed
	var along_speed := partner.linear_velocity.dot(release_velocity.normalized())
	if input_sign == 0.0:
		print("coast ratio=%.3f carry=%.2f" % [along_speed / release_velocity.length(), partner.partner_carry_velocity.length()])
		_check(along_speed > release_velocity.length() * 0.2 and along_speed < release_velocity.length() * 0.65,
			"neutral LS coasts and gradually loses speed")
		_check((partner.position - release_position).dot(release_velocity.normalized()) > 1.0,
			"released partner continues travelling")
	scene.queue_free()
	await process_frame
	return along_speed


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

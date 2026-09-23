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
	for weight in [40.0, 75.0, 120.0]:
		var scene: PrototypeController = load("res://prototype.tscn").instantiate()
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.set_process_input(false)
		var dancer := scene.left_dancer
		var observer := FrameObserver.new()
		observer.process_physics_priority = 2000
		scene.add_child(observer)
		dancer.set_physical_weight_kg(weight)
		dancer.reset_to_pose(Vector2(300, 350), 0.0)
		dancer.set_control_input(Vector2.RIGHT, Vector2.ZERO, 0.0, 0.0)
		for frame in 60:
			await observer.frame_completed
		_check(dancer.linear_velocity.x > 300.0, "solo LS reaches deliberate walking speed")
		_check(dancer.partner_carry_velocity.is_zero_approx(), "solo walking never creates partner carry")
		var stop_position := dancer.position
		dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
		for frame in 24:
			await observer.frame_completed
		print("SOLO weight=%.0f stopping_distance=%.2f speed_after_0.2s=%.2f" % [
			weight, dancer.position.distance_to(stop_position), dancer.linear_velocity.length()])
		_check(dancer.position.distance_to(stop_position) < 35.0, "centred solo LS stops within a short step")
		_check(dancer.linear_velocity.length() < 15.0, "solo movement settles promptly")
		# Reaction bookkeeping cannot protect velocity which a wall or blocking
		# partner has removed. No physical velocity is manufactured by this helper.
		dancer.linear_velocity = Vector2.ZERO
		dancer.record_partner_impulse(Vector2(-300, 0))
		dancer.reconcile_partner_carry()
		_check(dancer.partner_carry_velocity.is_zero_approx(), "blocked walking cannot bank a release kick")
		dancer.linear_velocity = Vector2(20, 0)
		dancer.partner_carry_velocity = Vector2(300, 0)
		dancer.reconcile_partner_carry()
		_check(dancer.partner_carry_velocity == Vector2(20, 0), "collisions remove unavailable carry")
		dancer.partner_carry_velocity = Vector2(-20, 0)
		dancer.reconcile_partner_carry()
		_check(dancer.partner_carry_velocity.is_zero_approx(), "opposing constraint reactions do not invent reverse carry")
		scene.queue_free()
		await process_frame
	await _test_hold_transitions()
	print("GROUNDED MOVEMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_hold_transitions() -> void:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	var a := scene.left_dancer
	var b := scene.right_dancer
	var hold := scene.hand_connection
	var observer := FrameObserver.new()
	observer.process_physics_priority = 2000
	scene.add_child(observer)
	a.reset_to_pose(Vector2(500, 350), 0.0)
	b.reset_to_pose(a.position + a.get_hand_local_position(1) - b.get_hand_local_position(-1).rotated(PI), PI)
	for side in [-1, 1]:
		hold.set_grip_button_state(a, side, true)
		hold.set_grip_button_state(b, -side, true)
	for frame in 40:
		await observer.frame_completed
	_check(a.hand_connection_count == 2 and b.hand_connection_count == 2, "both dancers know the double hold")
	a.set_control_input(Vector2.RIGHT, Vector2.ZERO, 0.0, 0.0)
	for frame in 45:
		await observer.frame_completed
	var moving_speed := maxf(a.linear_velocity.length(), b.linear_velocity.length())
	a.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	for frame in 24:
		await observer.frame_completed
	var stopped_speed := maxf(a.linear_velocity.length(), b.linear_velocity.length())
	print("DOUBLE HOLD speed=%.2f -> %.2f after 0.2s neutral" % [moving_speed, stopped_speed])
	_check(moving_speed > 50.0 and stopped_speed < moving_speed * 0.7
		and stopped_speed > moving_speed * 0.5,
		"neutral double-hold travel retains the original gradual damping")
	var velocities := [a.linear_velocity, b.linear_velocity]
	var carry := [a.partner_carry_velocity, b.partner_carry_velocity]
	hold.release_secondary_hands()
	_check(a.hand_connection_count == 1 and b.hand_connection_count == 1,
		"releasing one hand leaves a single hold")
	_check([a.linear_velocity, b.linear_velocity] == velocities and [a.partner_carry_velocity, b.partner_carry_velocity] == carry,
		"double-to-single release neither injects nor removes motion")
	hold.release_hands()
	_check(a.hand_connection_count == 0 and b.hand_connection_count == 0,
		"final release restores free movement")
	_check([a.linear_velocity, b.linear_velocity] == velocities and [a.partner_carry_velocity, b.partner_carry_velocity] == carry,
		"final release preserves existing carry without a throw impulse")
	for frame in 60:
		await observer.frame_completed
	velocities = [a.linear_velocity, b.linear_velocity]
	carry = [a.partner_carry_velocity, b.partner_carry_velocity]
	hold.set_grip_button_state(a, 1, false)
	hold.set_grip_button_state(b, -1, false)
	hold.set_grip_button_state(a, 1, true)
	hold.set_grip_button_state(b, -1, true)
	hold._try_connect_waiting_hands()
	_check(hold.has_any_connection(), "nearby dancers can catch again after cooldown")
	_check([a.linear_velocity, b.linear_velocity] == velocities and [a.partner_carry_velocity, b.partner_carry_velocity] == carry,
		"catching does not reset or add travelling velocity")
	scene.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

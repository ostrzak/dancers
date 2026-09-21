extends SceneTree

var failures := 0
var checks := 0
var scene: PrototypeController
var observer: FrameObserver
var minimum_distance := INF
var peak_gap := 0.0
var peak_correction := 0.0
var peak_flexion_step := 0.0
var peak_body_step := 0.0
var previous_a := Vector2.ZERO
var previous_b := Vector2.ZERO
var initial_facing := 1.0
var flipped := false
var limited_frames := 0
var previous_flexions := Vector4.ZERO

class FrameObserver extends Node:
	signal frame_completed
	func _physics_process(_delta: float) -> void:
		frame_completed.emit()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for scenario in ["front_dpad", "rear_dpad", "rear_one_trigger", "rear_both_triggers", "front_both_triggers"]:
		await _setup(scenario.begins_with("rear"))
		for frame in 300:
			match scenario:
				"front_dpad":
					scene._apply_arm_pose_inputs(Vector2.UP, Vector2.UP, 1.0 / 120.0)
				"rear_dpad":
					scene._apply_arm_pose_inputs(Vector2.DOWN, Vector2.DOWN, 1.0 / 120.0)
				"rear_one_trigger":
					scene.left_dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 0.0)
					scene.right_dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 1.0)
				_:
					for dancer in [scene.left_dancer, scene.right_dancer]:
						dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0)
			await _frame()
		_expect(scene.hand_connection.get_active_connection_count() == 2, scenario + ": both holds retained")
		_expect(minimum_distance >= 40.0, scenario + ": torso clearance retained")
		_expect(peak_gap <= 0.1, scenario + ": hands stay closed")
		_expect(not flipped, scenario + ": no front/rear switch")
		_expect(peak_body_step < 4.0 and peak_flexion_step < 0.03, scenario + ": no discontinuous pose correction")
		_expect(limited_frames > 0, scenario + ": reports reachable limit")
		var limited_flexion := scene.left_dancer.get_arm_flexion(-1)
		var limited_sweep := scene.left_dancer.extended_forward_sweep_degrees
		if OS.get_cmdline_user_args().has("--preview"):
			await process_frame
			await RenderingServer.frame_post_draw
			var path := OS.get_environment("TEMP").path_join("dancers-limit-%s.png" % scenario)
			_expect(root.get_texture().get_image().save_png(path) == OK, "save pose-limit preview")
			print("POSE LIMIT PREVIEW: " + path)
		if scenario.ends_with("dpad"):
			_expect(scene.left_dancer.get_average_arm_flexion() < 0.001
				and scene.right_dancer.get_average_arm_flexion() < 0.001, scenario + ": no unrequested trigger contraction")
			var reverse := Vector2.DOWN if scenario == "front_dpad" else Vector2.UP
			scene._apply_arm_pose_inputs(reverse, reverse, 1.0 / 120.0)
		else:
			for dancer in [scene.left_dancer, scene.right_dancer]:
				dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
		await _frame()
		if scenario.ends_with("dpad"):
			_expect(absf(scene.left_dancer.extended_forward_sweep_degrees - limited_sweep) > 0.1,
				scenario + ": reversing D-pad responds on next frame")
		else:
			_expect(scene.left_dancer.get_arm_flexion(-1) < limited_flexion - 0.001,
				scenario + ": releasing trigger responds on next frame")
		print("POSE LIMIT %s distance=%.4f gap=%.5f correction=%.4f body_step=%.4f flex_step=%.5f limited_flexion=%.4f sweep=%.3f" % [
			scenario, minimum_distance, peak_gap, peak_correction, peak_body_step, peak_flexion_step, limited_flexion, limited_sweep])
		# Releasing one hand restores the ordinary stance range without a pose jump.
		var velocity := scene.left_dancer.linear_velocity
		scene.hand_connection.release_secondary_hands()
		_expect(scene.left_dancer.linear_velocity == velocity, "release retains momentum")
		for frame in 180:
			scene._apply_arm_pose_inputs(Vector2.UP, Vector2.UP, 1.0 / 120.0)
			await observer.frame_completed
		_expect(is_equal_approx(scene.left_dancer.extended_forward_sweep_degrees, -25.0),
			"single hold restores full D-pad sweep")
		scene.queue_free()
		await process_frame
	print("DOUBLE HOLD POSE LIMITS: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _setup(rear: bool) -> void:
	scene = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	scene.get_node("TelemetryRecorder").set_physics_process(false)
	scene.figure_demonstration.set_process(false)
	scene.figure_demonstration.visible = false
	for dancer in [scene.left_dancer, scene.right_dancer]:
		dancer.extended_elbow_flexion_degrees = 5.0 if rear else 8.333333333
		dancer.extended_forward_sweep_degrees = -25.0 if rear else 28.0
	scene.left_dancer.reset_to_pose(Vector2(640, 330), 0.0)
	scene.right_dancer.reset_to_pose(Vector2.ZERO, PI)
	scene.right_dancer.position = scene.left_dancer.get_hand_world_position(-1) \
		- scene.right_dancer.get_hand_local_position(1).rotated(PI)
	for side in [-1, 1]:
		scene.hand_connection.set_grip_button_state(scene.left_dancer, side, true)
		scene.hand_connection.set_grip_button_state(scene.right_dancer, -side, true)
	observer = FrameObserver.new()
	observer.process_physics_priority = 2000
	scene.add_child(observer)
	for frame in 30:
		await observer.frame_completed
	minimum_distance = INF
	peak_gap = 0.0
	peak_correction = 0.0
	peak_flexion_step = 0.0
	peak_body_step = 0.0
	previous_a = scene.left_dancer.position
	previous_b = scene.right_dancer.position
	previous_flexions = Vector4.ZERO
	initial_facing = -1.0 if rear else 1.0
	flipped = false
	limited_frames = 0

func _frame() -> void:
	await observer.frame_completed
	var hold := scene.hand_connection
	var a := scene.left_dancer
	var b := scene.right_dancer
	peak_body_step = maxf(peak_body_step, maxf(a.position.distance_to(previous_a), b.position.distance_to(previous_b)))
	previous_a = a.position
	previous_b = b.position
	minimum_distance = minf(minimum_distance, a.position.distance_to(b.position))
	peak_gap = maxf(peak_gap, maxf(hold.primary_hand_separation, hold.secondary_hand_separation))
	peak_correction = maxf(peak_correction, maxf(hold.primary_position_correction, hold.secondary_position_correction))
	var flexions := Vector4(a.get_arm_flexion(-1), a.get_arm_flexion(1), b.get_arm_flexion(-1), b.get_arm_flexion(1))
	for index in 4:
		peak_flexion_step = maxf(peak_flexion_step, absf(flexions[index] - previous_flexions[index]))
	previous_flexions = flexions
	flipped = flipped or (b.position - a.position).dot(Dancer.LOCAL_FORWARD_DIRECTION.rotated(a.rotation)) * initial_facing <= 0.0
	if hold.double_hold_pose_limited:
		limited_frames += 1

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

extends SceneTree

const DancerScript = preload("res://dancer.gd")
const DT := 1.0 / 120.0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dancer: Node = DancerScript.new()
	get_root().add_child(dancer)
	dancer.freeze = true
	dancer.set_physics_process(false)
	dancer.set_control_input(Vector2.ZERO, Vector2.RIGHT * 0.1, 0.0, 0.0)
	_check(not dancer.facing_dial_active, "inner travel does not engage")
	dancer.set_control_input(Vector2.ZERO, Vector2.RIGHT * 0.25, 0.0, 0.0)
	for tick in 12:
		dancer._apply_facing_torque(DT)
	var light_rotation: float = absf(dancer.global_rotation)
	_check(dancer.facing_dial_active and light_rotation > 0.0, "light travel begins correcting toward its heading")
	var light_response: float = dancer.facing_dial_response_scale
	dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	dancer.global_rotation = 0.0
	dancer._unwrapped_rotation = 0.0
	dancer._previous_wrapped_rotation = 0.0
	dancer.set_control_input(Vector2.ZERO, Vector2.RIGHT, 0.0, 0.0)
	for tick in 12:
		dancer._apply_facing_torque(DT)
	_check(light_response < dancer.facing_dial_response_scale
		and is_equal_approx(dancer.facing_dial_response_scale, 1.0),
		"stick radius scales turn response up to full authority")
	_check(absf(dancer.global_rotation) > light_rotation * 4.0,
		"full travel corrects much faster than light travel")
	dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	dancer.global_rotation = 0.0
	dancer._unwrapped_rotation = 0.0
	dancer._previous_wrapped_rotation = 0.0
	dancer.set_control_input(Vector2.ZERO, Vector2.DOWN, 0.0, 0.0)
	# Full turns stay on the outer ring, where the response can keep up.
	var peak_lag := 0.0
	for tick in 240:
		dancer.set_control_input(Vector2.ZERO, Vector2.from_angle(PI * 0.5 + TAU * float(tick + 1) / 240.0), 0.0, 0.0)
		dancer._apply_facing_torque(DT)
		peak_lag = maxf(peak_lag, absf(dancer.heading_error))
	for tick in 120:
		dancer._apply_facing_torque(DT)
	_check(absf(dancer.facing_dial_total_rotation - TAU) < 0.01, "outer-ring circle preserves a full turn")
	_check(peak_lag < deg_to_rad(45.0), "outer-ring heading response remains close")
	# Deliberate overload: three circles in 1.5 seconds, then reverse.
	for tick in 180:
		dancer.set_control_input(Vector2.ZERO, Vector2.from_angle(TAU * 3.0 * float(tick + 1) / 180.0), 0.0, 0.0)
		dancer._apply_facing_torque(DT)
	_check(absf(dancer.heading_error) <= PI,
		"overload remains a shortest-path heading correction instead of queued revolutions")
	for tick in 8:
		dancer.set_control_input(Vector2.ZERO, Vector2.from_angle(-0.05 * float(tick + 1)), 0.0, 0.0)
		dancer._apply_facing_torque(DT)
	_check(dancer.target_angular_velocity < 0.0, "reversal responds within 67 ms")
	dancer.angular_velocity = 1.25
	dancer._apply_facing_torque(DT)
	_check(is_equal_approx(dancer.angular_velocity, 1.25), "active dial preserves physical spin")
	dancer.set_control_input(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	var released_rotation: float = dancer.global_rotation
	for tick in 120:
		dancer._apply_facing_torque(DT)
	_check(is_equal_approx(dancer.global_rotation, released_rotation)
		and is_zero_approx(dancer.heading_error)
		and is_equal_approx(dancer.angular_velocity, 1.25), "release cancels input while preserving physical spin")
	dancer.free()
	print("RS heading response: 10 checks, %d failures" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

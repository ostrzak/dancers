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
	dancer.set_control_input(Vector2.ZERO, Vector2.RIGHT * 0.4, 0.0, 0.0)
	_check(not dancer.facing_dial_active, "inner travel does not engage")
	dancer.set_control_input(Vector2.ZERO, Vector2.RIGHT * 0.8, 0.0, 0.0)
	dancer._apply_facing_torque(DT)
	_check(dancer.facing_dial_active and is_zero_approx(dancer.global_rotation), "entry has no snap")
	# One ordinary full circle, with radius inside the hysteresis band.
	var peak_lag := 0.0
	for tick in 240:
		dancer.set_control_input(Vector2.ZERO, Vector2.from_angle(TAU * float(tick + 1) / 240.0) * 0.4, 0.0, 0.0)
		dancer._apply_facing_torque(DT)
		peak_lag = maxf(peak_lag, absf(dancer.heading_error))
	for tick in 120:
		dancer._apply_facing_torque(DT)
	_check(absf(dancer.facing_dial_total_rotation - TAU) < 0.001, "ordinary circle preserves turn travel")
	_check(peak_lag <= deg_to_rad(20.0), "ordinary gesture remains close")
	# Deliberate overload: three circles in 1.5 seconds, then reverse.
	for tick in 180:
		dancer.set_control_input(Vector2.ZERO, Vector2.from_angle(TAU * 3.0 * float(tick + 1) / 180.0), 0.0, 0.0)
		dancer._apply_facing_torque(DT)
	_check(absf(dancer.heading_error) <= deg_to_rad(20.0), "overload cannot queue a revolution")
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
	print("RS dial: 8 checks, %d failures" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

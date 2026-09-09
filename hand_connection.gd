class_name HandConnection
extends Node2D

signal connection_changed(is_connected: bool)
signal grip_state_changed

@export_category("Catch Assist")
@export var catch_radius := 54.0
@export var maximum_relative_catch_velocity := 280.0
@export var release_cooldown := 0.35
@export var snap_duration := 0.22

@export_category("Rigid Joint")
@export_range(1, 32, 1) var rigid_position_iterations := 32
@export_range(1, 8, 1) var rigid_velocity_iterations := 6

@export_category("Rigid Double Hold")
@export var rigid_span_tolerance := 0.02
@export_range(1, 12, 1) var rigid_span_projection_iterations := 6

@export var dancer_a: Dancer
@export var dancer_b: Dancer

var is_connected := false
var is_secondary_connected := false
var distance_error := 0.0
var relative_hand_velocity := 0.0
var separation_limit_active := false
var primary_hand_separation := 0.0
var secondary_hand_separation := 0.0
var primary_allowed_separation := 0.0
var secondary_allowed_separation := 0.0
var primary_position_correction := 0.0
var secondary_position_correction := 0.0
var primary_velocity_correction := 0.0
var secondary_velocity_correction := 0.0
var primary_snap_remaining := 0.0
var secondary_snap_remaining := 0.0
var primary_acquisition_progress := 0.0
var secondary_acquisition_progress := 0.0
var double_hold_orbital_angular_velocity := 0.0
var double_hold_alignment_error := 0.0
var double_hold_primary_permission := 0.0
var double_hold_secondary_permission := 0.0
var double_hold_maximum_effort := 0.0

var _connected_hand_a := 1
var _connected_hand_b := 1
var _secondary_hand_a := -1
var _secondary_hand_b := -1
var _grip_a := {-1: false, 1: false}
var _grip_b := {-1: false, 1: false}
var _button_down_a := {-1: false, 1: false}
var _button_down_b := {-1: false, 1: false}
var _release_tap_armed_a := {-1: false, 1: false}
var _release_tap_armed_b := {-1: false, 1: false}
var _button_consumed_a := {-1: false, 1: false}
var _button_consumed_b := {-1: false, 1: false}
var _cooldown_a := {-1: 0.0, 1: 0.0}
var _cooldown_b := {-1: 0.0, 1: 0.0}
var _primary_catch_separation := 0.0
var _secondary_catch_separation := 0.0
var _double_hold_was_active := false
var _double_hold_primary_flexion := 0.0
var _double_hold_secondary_flexion := 0.0

const HAND_SIDES := [-1, 1]


func _ready() -> void:
	_update_dancer_collision_exception()


func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_reset_diagnostics()
	if not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return

	_try_connect_waiting_hands()
	var double_hold_active := is_connected and is_secondary_connected
	_update_double_hold_arm_frame(double_hold_active, delta)
	if is_connected:
		primary_snap_remaining = maxf(0.0, primary_snap_remaining - delta)
		primary_acquisition_progress = _get_acquisition_progress(1)
	if is_secondary_connected:
		secondary_snap_remaining = maxf(0.0, secondary_snap_remaining - delta)
		secondary_acquisition_progress = _get_acquisition_progress(2)
	_solve_active_hold_constraints(delta)
	_update_active_hold_metrics()
	if double_hold_active:
		_update_double_hold_metrics()
	if not has_any_connection():
		_update_free_hand_metrics()
	queue_redraw()


func set_grip_button_state(
	dancer: Dancer,
	hand_side: int,
	is_pressed: bool
) -> void:
	var side := signi(hand_side)
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return
	if _get_button_down(endpoint, side) == is_pressed:
		return

	_set_button_down(endpoint, side, is_pressed)
	var slot := _connection_slot_for_endpoint(endpoint, side)
	if slot != 0:
		_set_grip(endpoint, side, false)
		if is_pressed and _get_release_tap_armed(endpoint, side):
			_set_button_consumed(endpoint, side, true)
			_set_release_tap_armed(endpoint, side, false)
			if slot == 1:
				_release_pair(1, _connected_hand_a, _connected_hand_b)
			else:
				_release_pair(2, _secondary_hand_a, _secondary_hand_b)
		else:
			# The button-up following a successful catch arms a future tap; it does
			# not release the latched physical connection.
			_set_release_tap_armed(endpoint, side, not is_pressed)
			if not is_pressed:
				_set_button_consumed(endpoint, side, false)
			grip_state_changed.emit()
			queue_redraw()
		return

	if is_pressed:
		if _get_button_consumed(endpoint, side):
			return
		_set_grip(endpoint, side, true)
		if not _try_connect_for_endpoint(endpoint, side):
			grip_state_changed.emit()
			queue_redraw()
	else:
		_set_grip(endpoint, side, false)
		_set_button_consumed(endpoint, side, false)
		_set_release_tap_armed(endpoint, side, false)
		grip_state_changed.emit()
		queue_redraw()


func is_hand_primed(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	return _get_grip(endpoint, signi(hand_side))


func is_grip_button_down(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	return _get_button_down(endpoint, signi(hand_side))


func is_release_tap_armed(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	return _get_release_tap_armed(endpoint, signi(hand_side))


func release_hands() -> void:
	if not is_connected:
		return
	_release_pair(1, _connected_hand_a, _connected_hand_b)


func release_secondary_hands() -> void:
	if not is_secondary_connected:
		return
	_release_pair(2, _secondary_hand_a, _secondary_hand_b)


func has_any_connection() -> bool:
	return is_connected or is_secondary_connected


func get_active_connection_count() -> int:
	return int(is_connected) + int(is_secondary_connected)


func get_hold_mode() -> String:
	match get_active_connection_count():
		1:
			return "single"
		2:
			return "double"
	return "free"


func get_solver_mode() -> String:
	return "joint"


func is_mutual_body_collision_disabled() -> bool:
	return (
		is_instance_valid(dancer_a)
		and is_instance_valid(dancer_b)
		and dancer_a.get_collision_exceptions().has(dancer_b)
	)


func get_connected_hand_sides() -> Array[int]:
	return [_connected_hand_a, _connected_hand_b]


func get_secondary_connected_hand_sides() -> Array[int]:
	return [_secondary_hand_a, _secondary_hand_b]


func get_cooldown_remaining() -> float:
	var remaining := 0.0
	for side in HAND_SIDES:
		remaining = maxf(remaining, float(_cooldown_a[side]))
		remaining = maxf(remaining, float(_cooldown_b[side]))
	return remaining


func _try_connect_waiting_hands() -> void:
	for side in HAND_SIDES:
		if _get_grip(1, side) and _connection_slot_for_endpoint(1, side) == 0:
			_try_connect_for_endpoint(1, side)
	for side in HAND_SIDES:
		if _get_grip(2, side) and _connection_slot_for_endpoint(2, side) == 0:
			_try_connect_for_endpoint(2, side)


func _try_connect_for_endpoint(endpoint: int, side: int) -> bool:
	if not _endpoint_can_catch(endpoint, side):
		return false

	var best_distance := INF
	var best_other_side := 0
	for other_side in HAND_SIDES:
		var other_endpoint := 2 if endpoint == 1 else 1
		if not _endpoint_can_be_caught(other_endpoint, other_side):
			continue
		var hand_a_side: int = side if endpoint == 1 else int(other_side)
		var hand_b_side: int = int(other_side) if endpoint == 1 else side
		var hand_a := dancer_a.get_hand_world_position(hand_a_side)
		var hand_b := dancer_b.get_hand_world_position(hand_b_side)
		var separation_length := hand_a.distance_to(hand_b)
		var relative_velocity := (
			dancer_b.get_hand_velocity(hand_b_side)
			- dancer_a.get_hand_velocity(hand_a_side)
		).length()
		if (
			separation_length <= catch_radius
			and relative_velocity <= maximum_relative_catch_velocity
			and separation_length < best_distance
		):
			best_distance = separation_length
			best_other_side = other_side

	if best_other_side == 0:
		return false
	var catch_hand_a := side if endpoint == 1 else best_other_side
	var catch_hand_b := best_other_side if endpoint == 1 else side
	return _connect_pair(catch_hand_a, catch_hand_b)


func _connect_pair(hand_a_side: int, hand_b_side: int) -> bool:
	if (
		_connection_slot_for_endpoint(1, hand_a_side) != 0
		or _connection_slot_for_endpoint(2, hand_b_side) != 0
		or not _get_grip(1, hand_a_side)
		or not _get_grip(2, hand_b_side)
	):
		return false

	if not is_connected:
		_connected_hand_a = signi(hand_a_side)
		_connected_hand_b = signi(hand_b_side)
		is_connected = true
		primary_snap_remaining = snap_duration
		_primary_catch_separation = dancer_a.get_hand_world_position(
			_connected_hand_a
		).distance_to(dancer_b.get_hand_world_position(_connected_hand_b))
		primary_acquisition_progress = 0.0
	elif not is_secondary_connected:
		_secondary_hand_a = signi(hand_a_side)
		_secondary_hand_b = signi(hand_b_side)
		is_secondary_connected = true
		secondary_snap_remaining = snap_duration
		_secondary_catch_separation = dancer_a.get_hand_world_position(
			_secondary_hand_a
		).distance_to(dancer_b.get_hand_world_position(_secondary_hand_b))
		secondary_acquisition_progress = 0.0
	else:
		return false

	_consume_catch_input(hand_a_side, hand_b_side)
	_update_dancer_collision_exception()
	connection_changed.emit(true)
	grip_state_changed.emit()
	queue_redraw()
	return true


func _release_pair(slot: int, hand_a_side: int, hand_b_side: int) -> void:
	_consume_release_input(hand_a_side, hand_b_side)
	if slot == 1:
		is_connected = false
		primary_snap_remaining = 0.0
		primary_acquisition_progress = 0.0
		_primary_catch_separation = 0.0
	else:
		is_secondary_connected = false
		secondary_snap_remaining = 0.0
		secondary_acquisition_progress = 0.0
		_secondary_catch_separation = 0.0
	_set_cooldown(1, hand_a_side, release_cooldown)
	_set_cooldown(2, hand_b_side, release_cooldown)
	_update_dancer_collision_exception()
	_reset_diagnostics()
	connection_changed.emit(has_any_connection())
	grip_state_changed.emit()
	queue_redraw()


func _consume_catch_input(hand_a_side: int, hand_b_side: int) -> void:
	for endpoint in [1, 2]:
		var side := hand_a_side if endpoint == 1 else hand_b_side
		_set_grip(endpoint, side, false)
		_set_button_consumed(endpoint, side, true)
		_set_release_tap_armed(endpoint, side, false)


func _consume_release_input(hand_a_side: int, hand_b_side: int) -> void:
	for endpoint in [1, 2]:
		var side := hand_a_side if endpoint == 1 else hand_b_side
		_set_grip(endpoint, side, false)
		_set_button_consumed(endpoint, side, _get_button_down(endpoint, side))
		_set_release_tap_armed(endpoint, side, false)


func _solve_active_hold_constraints(delta: float) -> void:
	primary_allowed_separation = (
		_get_acquisition_separation(1)
		if is_connected
		else 0.0
	)
	secondary_allowed_separation = (
		_get_acquisition_separation(2)
		if is_secondary_connected
		else 0.0
	)
	for _iteration in rigid_position_iterations:
		var corrected_any := false
		if is_connected:
			corrected_any = (
				_solve_pair_position(
					_connected_hand_a,
					_connected_hand_b,
					primary_allowed_separation,
					1
				)
				or corrected_any
			)
		if is_secondary_connected:
			corrected_any = (
				_solve_pair_position(
					_secondary_hand_a,
					_secondary_hand_b,
					secondary_allowed_separation,
					2
				)
				or corrected_any
			)
		if not corrected_any:
			break
	for _iteration in rigid_velocity_iterations:
		if is_connected:
			if primary_snap_remaining <= 0.0:
				_solve_rigid_pair_velocity(
					_connected_hand_a,
					_connected_hand_b,
					delta,
					1
				)
			else:
				_solve_pair_velocity(
					_connected_hand_a,
					_connected_hand_b,
					primary_allowed_separation,
					delta,
					1
				)
		if is_secondary_connected:
			if secondary_snap_remaining <= 0.0:
				_solve_rigid_pair_velocity(
					_secondary_hand_a,
					_secondary_hand_b,
					delta,
					2
				)
			else:
				_solve_pair_velocity(
					_secondary_hand_a,
					_secondary_hand_b,
					secondary_allowed_separation,
					delta,
					2
				)


func _get_acquisition_progress(slot: int) -> float:
	if snap_duration <= 0.000001:
		return 1.0
	var remaining := primary_snap_remaining if slot == 1 else secondary_snap_remaining
	var linear_progress := clampf(1.0 - remaining / snap_duration, 0.0, 1.0)
	# Smoothstep has zero velocity at both ends, so the catch starts and finishes
	# without a positional kick. This is an acquisition path, not a spring.
	return linear_progress * linear_progress * (3.0 - 2.0 * linear_progress)


func _get_acquisition_separation(slot: int) -> float:
	var catch_separation := (
		_primary_catch_separation if slot == 1 else _secondary_catch_separation
	)
	return catch_separation * (1.0 - _get_acquisition_progress(slot))


func _update_double_hold_arm_frame(active: bool, delta: float) -> void:
	if not active:
		if _double_hold_was_active:
			dancer_a.clear_double_hold_arm_states()
			dancer_b.clear_double_hold_arm_states()
		_double_hold_was_active = false
		double_hold_primary_permission = 0.0
		double_hold_secondary_permission = 0.0
		double_hold_maximum_effort = 0.0
		return

	double_hold_primary_permission = minf(
		dancer_a.get_trigger_value(_connected_hand_a),
		dancer_b.get_trigger_value(_connected_hand_b)
	)
	double_hold_secondary_permission = minf(
		dancer_a.get_trigger_value(_secondary_hand_a),
		dancer_b.get_trigger_value(_secondary_hand_b)
	)
	if not _double_hold_was_active:
		_double_hold_primary_flexion = minf(
			dancer_a.get_arm_flexion(_connected_hand_a),
			dancer_b.get_arm_flexion(_connected_hand_b)
		)
		_double_hold_secondary_flexion = minf(
			dancer_a.get_arm_flexion(_secondary_hand_a),
			dancer_b.get_arm_flexion(_secondary_hand_b)
		)
	_double_hold_was_active = true

	var normalized_rate := minf(
		dancer_a.arm_interpolation_speed
		/ maxf(dancer_a.maximum_arm_length - dancer_a.minimum_arm_length, 0.001),
		dancer_b.arm_interpolation_speed
		/ maxf(dancer_b.maximum_arm_length - dancer_b.minimum_arm_length, 0.001)
	)
	_double_hold_primary_flexion = move_toward(
		_double_hold_primary_flexion,
		double_hold_primary_permission,
		normalized_rate * maxf(delta, 0.0)
	)
	_double_hold_secondary_flexion = move_toward(
		_double_hold_secondary_flexion,
		double_hold_secondary_permission,
		normalized_rate * maxf(delta, 0.0)
	)

	# Begin with the mutually permitted flexion for each contact. Then make only
	# the tiny anatomical adjustment required for both dancers' two hand spans to
	# match. Equal spans are what make two exact point contacts geometrically
	# possible without welding either dancer's body orientation.
	var flexions := [
		_double_hold_primary_flexion,
		_double_hold_primary_flexion,
		_double_hold_secondary_flexion,
		_double_hold_secondary_flexion,
	]
	_project_double_hold_spans(flexions)
	_apply_double_hold_flexions(flexions, true)
	double_hold_maximum_effort = maxf(
		maxf(
			dancer_a.get_double_hold_arm_effort(_connected_hand_a),
			dancer_b.get_double_hold_arm_effort(_connected_hand_b)
		),
		maxf(
			dancer_a.get_double_hold_arm_effort(_secondary_hand_a),
			dancer_b.get_double_hold_arm_effort(_secondary_hand_b)
		)
	)


func _project_double_hold_spans(flexions: Array) -> void:
	const SAMPLE_STEP := 0.01
	var minimum_body_distance := _get_body_contact_distance()
	for _iteration in rigid_span_projection_iterations:
		_apply_double_hold_flexions(flexions, false)
		var error := _get_double_hold_span_error()
		var body_offset := _get_double_hold_body_offset()
		var clearance_error := minf(0.0, body_offset.length() - minimum_body_distance)
		var clearance_axis := body_offset.normalized()
		if clearance_axis.is_zero_approx():
			# Same-side double grips can start with identical local hand spans.
			# Use their real separation to resolve that zero-distance derivative.
			clearance_axis = (dancer_b.global_position - dancer_a.global_position).rotated(
				-dancer_a.global_rotation).normalized()
			if clearance_axis.is_zero_approx():
				clearance_axis = Vector2.DOWN
		if absf(error) <= rigid_span_tolerance and clearance_error >= -0.001:
			return
		var gradient := [0.0, 0.0, 0.0, 0.0]
		var clearance_gradient := [0.0, 0.0, 0.0, 0.0]
		var denominator := 0.0
		var clearance_denominator := 0.0
		var cross_denominator := 0.0
		for index in 4:
			var original: float = flexions[index]
			var sample := clampf(original + SAMPLE_STEP, 0.0, 1.0)
			if is_equal_approx(sample, original):
				sample = clampf(original - SAMPLE_STEP, 0.0, 1.0)
			if is_equal_approx(sample, original):
				continue
			flexions[index] = sample
			_apply_double_hold_flexions(flexions, false)
			gradient[index] = (_get_double_hold_span_error() - error) / (sample - original)
			denominator += gradient[index] * gradient[index]
			if clearance_error < 0.0:
				clearance_gradient[index] = (
					(_get_double_hold_body_offset() - body_offset).dot(clearance_axis)
				) / (sample - original)
				clearance_denominator += clearance_gradient[index] * clearance_gradient[index]
				cross_denominator += gradient[index] * clearance_gradient[index]
			flexions[index] = original
		if denominator <= 0.000001 and clearance_denominator <= 0.000001:
			break
		# Project only incompatible arm geometry. Match both hand spans while
		# respecting the actual torso circles, so a fully tucked request cannot
		# close the joints by pulling the two bodies through each other. The
		# requested trigger values stay intact; unmet flexion is normal red effort.
		var span_scale := -error / maxf(denominator, 0.000001)
		var clearance_scale := 0.0
		if clearance_error < 0.0:
			var determinant := denominator * clearance_denominator - cross_denominator * cross_denominator
			if determinant > 0.000001:
				span_scale = (-error * clearance_denominator + clearance_error * cross_denominator) / determinant
				clearance_scale = (-clearance_error * denominator + error * cross_denominator) / determinant
			else:
				clearance_scale = -clearance_error / maxf(clearance_denominator, 0.000001)
		for index in 4:
			flexions[index] = clampf(
				float(flexions[index]) + clampf(
					span_scale * float(gradient[index]) + clearance_scale * float(clearance_gradient[index]),
					-0.25, 0.25),
				0.0,
				1.0
			)
	_apply_double_hold_flexions(flexions, false)


func _get_body_contact_distance() -> float:
	var distance := 0.0
	for dancer in [dancer_a, dancer_b]:
		var collision := dancer.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null and not collision.disabled and collision.shape is CircleShape2D:
			distance += (collision.shape as CircleShape2D).radius
	return distance


func _get_double_hold_body_offset() -> Vector2:
	# The two hand vectors determine the relative body rotation of a closed
	# frame. Its required translation gives the centre distance independently
	# of the current world pose; no body transforms are changed by this query.
	var a_primary := dancer_a.get_hand_local_position(_connected_hand_a)
	var b_primary := dancer_b.get_hand_local_position(_connected_hand_b)
	var a_span := dancer_a.get_hand_local_position(_secondary_hand_a) - a_primary
	var b_span := dancer_b.get_hand_local_position(_secondary_hand_b) - b_primary
	var relative_rotation := a_span.angle() - b_span.angle()
	return a_primary - b_primary.rotated(relative_rotation)


func _apply_double_hold_flexions(flexions: Array, record_effort: bool) -> void:
	var request_a_primary := (
		dancer_a.get_trigger_value(_connected_hand_a)
		if record_effort else float(flexions[0])
	)
	var request_b_primary := (
		dancer_b.get_trigger_value(_connected_hand_b)
		if record_effort else float(flexions[1])
	)
	var request_a_secondary := (
		dancer_a.get_trigger_value(_secondary_hand_a)
		if record_effort else float(flexions[2])
	)
	var request_b_secondary := (
		dancer_b.get_trigger_value(_secondary_hand_b)
		if record_effort else float(flexions[3])
	)
	dancer_a.set_double_hold_arm_state(
		_connected_hand_a,
		float(flexions[0]),
		request_a_primary
	)
	dancer_b.set_double_hold_arm_state(
		_connected_hand_b,
		float(flexions[1]),
		request_b_primary
	)
	dancer_a.set_double_hold_arm_state(
		_secondary_hand_a,
		float(flexions[2]),
		request_a_secondary
	)
	dancer_b.set_double_hold_arm_state(
		_secondary_hand_b,
		float(flexions[3]),
		request_b_secondary
	)


func _get_double_hold_span_error() -> float:
	var span_a := dancer_a.get_hand_local_position(_connected_hand_a).distance_to(
		dancer_a.get_hand_local_position(_secondary_hand_a)
	)
	var span_b := dancer_b.get_hand_local_position(_connected_hand_b).distance_to(
		dancer_b.get_hand_local_position(_secondary_hand_b)
	)
	return span_a - span_b


func _solve_rigid_pair_velocity(
	hand_a_side: int,
	hand_b_side: int,
	delta: float,
	slot: int
) -> void:
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		var relative_speed := (
			_get_predicted_hand_velocity(dancer_b, hand_b_side, delta)
			- _get_predicted_hand_velocity(dancer_a, hand_a_side, delta)
		).dot(axis)
		_apply_pair_velocity_axis(
			hand_a_side,
			hand_b_side,
			axis,
			relative_speed,
			slot
		)


func _solve_pair_position(
	hand_a_side: int,
	hand_b_side: int,
	allowed_separation: float,
	slot: int
) -> bool:
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var gap := hand_b - hand_a
	var gap_length := gap.length()
	if gap_length <= allowed_separation + 0.001:
		return false
	var correction := gap_length - allowed_separation
	if not _apply_pair_position_axis(
		hand_a_side,
		hand_b_side,
		gap / gap_length,
		correction
	):
		return false
	_record_position_correction(slot, correction)
	separation_limit_active = true
	return true


func _apply_pair_position_axis(
	hand_a_side: int,
	hand_b_side: int,
	axis: Vector2,
	correction: float
) -> bool:
	if correction <= 0.0 or axis.is_zero_approx():
		return false
	axis = axis.normalized()
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var offset_a := hand_a - dancer_a.global_position
	var offset_b := hand_b - dancer_b.global_position
	var inverse_mass_a := (
		0.0 if dancer_a.position_lock_active else 1.0 / maxf(dancer_a.mass, 0.001)
	)
	var inverse_mass_b := (
		0.0 if dancer_b.position_lock_active else 1.0 / maxf(dancer_b.mass, 0.001)
	)
	var inverse_inertia_a := (
		0.0 if dancer_a.rotation_lock_active else 1.0 / maxf(dancer_a.inertia, 0.001)
	)
	var inverse_inertia_b := (
		0.0 if dancer_b.rotation_lock_active else 1.0 / maxf(dancer_b.inertia, 0.001)
	)
	var angular_axis_a := offset_a.cross(axis)
	var angular_axis_b := offset_b.cross(axis)
	var effective_inverse_mass := (
		inverse_mass_a
		+ inverse_mass_b
		+ angular_axis_a * angular_axis_a * inverse_inertia_a
		+ angular_axis_b * angular_axis_b * inverse_inertia_b
	)
	if effective_inverse_mass <= 0.000001:
		# Two fully locked dancers still cannot violate a handhold. In that singular
		# conflict the fingertip tether takes priority over both position anchors.
		inverse_mass_a = 1.0 / maxf(dancer_a.mass, 0.001)
		inverse_mass_b = 1.0 / maxf(dancer_b.mass, 0.001)
		effective_inverse_mass = inverse_mass_a + inverse_mass_b
	var impulse := correction / effective_inverse_mass
	dancer_a.global_position += axis * impulse * inverse_mass_a
	dancer_b.global_position -= axis * impulse * inverse_mass_b
	if inverse_inertia_a > 0.0:
		dancer_a.global_rotation += angular_axis_a * impulse * inverse_inertia_a
	if inverse_inertia_b > 0.0:
		dancer_b.global_rotation -= angular_axis_b * impulse * inverse_inertia_b
	dancer_a.sleeping = false
	dancer_b.sleeping = false
	return true


func _solve_pair_velocity(
	hand_a_side: int,
	hand_b_side: int,
	allowed_separation: float,
	delta: float,
	slot: int
) -> void:
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var gap := hand_b - hand_a
	var gap_length := gap.length()
	if gap_length <= 0.001:
		return
	var allowed_speed := maxf(
		0.0,
		(allowed_separation - gap_length) / maxf(delta, 0.000001)
	)
	_limit_pair_velocity_axis(
		hand_a_side,
		hand_b_side,
		gap / gap_length,
		allowed_speed,
		slot,
		delta
	)


func _limit_pair_velocity_axis(
	hand_a_side: int,
	hand_b_side: int,
	axis: Vector2,
	maximum_speed: float,
	slot: int,
	delta: float
) -> bool:
	var relative_speed := (
		_get_predicted_hand_velocity(dancer_b, hand_b_side, delta)
		- _get_predicted_hand_velocity(dancer_a, hand_a_side, delta)
	).dot(axis)
	var excess_speed := relative_speed - maximum_speed
	if excess_speed <= 0.0001:
		return false
	_apply_pair_velocity_axis(
		hand_a_side,
		hand_b_side,
		axis,
		excess_speed,
		slot
	)
	return true


func _get_predicted_hand_velocity(
	dancer: Dancer,
	hand_side: int,
	delta: float
) -> Vector2:
	var offset := dancer.get_hand_offset(hand_side)
	var applied_force := (
		dancer.diagnostic_movement_force
		+ dancer.diagnostic_position_lock_force
	)
	var predicted_linear_velocity := (
		dancer.linear_velocity
		+ applied_force / maxf(dancer.mass, 0.001) * delta
	)
	var applied_torque := (
		dancer.diagnostic_spin_torque
		+ dancer.diagnostic_rotation_lock_torque
	)
	var predicted_angular_velocity := (
		dancer.angular_velocity
		+ applied_torque / maxf(dancer.inertia, 0.001) * delta
	)
	return (
		predicted_linear_velocity
		+ Vector2(-offset.y, offset.x) * predicted_angular_velocity
	)


func _apply_pair_velocity_axis(
	hand_a_side: int,
	hand_b_side: int,
	axis: Vector2,
	speed_correction: float,
	slot: int,
	record_correction: bool = true,
	maximum_impulse: float = INF
) -> float:
	if is_zero_approx(speed_correction) or maximum_impulse <= 0.0:
		return 0.0
	axis = axis.normalized()
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var offset_a := hand_a - dancer_a.global_position
	var offset_b := hand_b - dancer_b.global_position
	var inverse_mass_a := (
		0.0 if dancer_a.position_lock_active else 1.0 / maxf(dancer_a.mass, 0.001)
	)
	var inverse_mass_b := (
		0.0 if dancer_b.position_lock_active else 1.0 / maxf(dancer_b.mass, 0.001)
	)
	var inverse_inertia_a := (
		0.0 if dancer_a.rotation_lock_active else 1.0 / maxf(dancer_a.inertia, 0.001)
	)
	var inverse_inertia_b := (
		0.0 if dancer_b.rotation_lock_active else 1.0 / maxf(dancer_b.inertia, 0.001)
	)
	var angular_axis_a := offset_a.cross(axis)
	var angular_axis_b := offset_b.cross(axis)
	var effective_inverse_mass := (
		inverse_mass_a
		+ inverse_mass_b
		+ angular_axis_a * angular_axis_a * inverse_inertia_a
		+ angular_axis_b * angular_axis_b * inverse_inertia_b
	)
	if effective_inverse_mass <= 0.000001:
		inverse_mass_a = 1.0 / maxf(dancer_a.mass, 0.001)
		inverse_mass_b = 1.0 / maxf(dancer_b.mass, 0.001)
		effective_inverse_mass = inverse_mass_a + inverse_mass_b
	var impulse := clampf(
		speed_correction / effective_inverse_mass,
		-maximum_impulse,
		maximum_impulse
	)
	dancer_a.linear_velocity += axis * impulse * inverse_mass_a
	dancer_b.linear_velocity -= axis * impulse * inverse_mass_b
	if inverse_inertia_a > 0.0:
		dancer_a.angular_velocity += angular_axis_a * impulse * inverse_inertia_a
	if inverse_inertia_b > 0.0:
		dancer_b.angular_velocity -= angular_axis_b * impulse * inverse_inertia_b
	if record_correction:
		_record_velocity_correction(slot, absf(speed_correction))
	return impulse


func _record_position_correction(slot: int, correction: float) -> void:
	if slot == 1:
		primary_position_correction = maxf(primary_position_correction, correction)
	else:
		secondary_position_correction = maxf(secondary_position_correction, correction)


func _record_velocity_correction(slot: int, correction: float) -> void:
	if slot == 1:
		primary_velocity_correction = maxf(primary_velocity_correction, correction)
	else:
		secondary_velocity_correction = maxf(secondary_velocity_correction, correction)


func _update_active_hold_metrics() -> void:
	if is_connected:
		primary_hand_separation = dancer_a.get_hand_world_position(
			_connected_hand_a
		).distance_to(dancer_b.get_hand_world_position(_connected_hand_b))
		distance_error = maxf(distance_error, primary_hand_separation)
		relative_hand_velocity = maxf(
			relative_hand_velocity,
			(
				dancer_b.get_hand_velocity(_connected_hand_b)
				- dancer_a.get_hand_velocity(_connected_hand_a)
			).length()
		)
	if is_secondary_connected:
		secondary_hand_separation = dancer_a.get_hand_world_position(
			_secondary_hand_a
		).distance_to(dancer_b.get_hand_world_position(_secondary_hand_b))
		distance_error = maxf(distance_error, secondary_hand_separation)
		relative_hand_velocity = maxf(
			relative_hand_velocity,
			(
				dancer_b.get_hand_velocity(_secondary_hand_b)
				- dancer_a.get_hand_velocity(_secondary_hand_a)
			).length()
		)


func _update_double_hold_metrics() -> void:
	var separation := dancer_b.global_position - dancer_a.global_position
	var distance_squared := separation.length_squared()
	if distance_squared <= 0.001:
		return
	var relative_body_velocity := dancer_b.linear_velocity - dancer_a.linear_velocity
	double_hold_orbital_angular_velocity = (
		separation.cross(relative_body_velocity) / distance_squared
	)
	var axis_angle := separation.angle()
	var error_a := wrapf(
		axis_angle - PI * 0.5 - dancer_a.global_rotation,
		-PI,
		PI
	)
	var error_b := wrapf(
		axis_angle + PI * 0.5 - dancer_b.global_rotation,
		-PI,
		PI
	)
	double_hold_alignment_error = maxf(absf(error_a), absf(error_b))


func _update_free_hand_metrics() -> void:
	var closest_distance := INF
	var closest_relative_velocity := 0.0
	for side_a in HAND_SIDES:
		for side_b in HAND_SIDES:
			var hand_a := dancer_a.get_hand_world_position(side_a)
			var hand_b := dancer_b.get_hand_world_position(side_b)
			var separation_length := hand_a.distance_to(hand_b)
			var relative_velocity := (
				dancer_b.get_hand_velocity(side_b)
				- dancer_a.get_hand_velocity(side_a)
			).length()
			if separation_length < closest_distance:
				closest_distance = separation_length
				closest_relative_velocity = relative_velocity
	distance_error = closest_distance
	relative_hand_velocity = closest_relative_velocity


func _endpoint_for_dancer(dancer: Dancer) -> int:
	if dancer == dancer_a:
		return 1
	if dancer == dancer_b:
		return 2
	return 0


func _connection_slot_for_endpoint(endpoint: int, side: int) -> int:
	if is_connected and (
		(endpoint == 1 and side == _connected_hand_a)
		or (endpoint == 2 and side == _connected_hand_b)
	):
		return 1
	if is_secondary_connected and (
		(endpoint == 1 and side == _secondary_hand_a)
		or (endpoint == 2 and side == _secondary_hand_b)
	):
		return 2
	return 0


func _endpoint_can_catch(endpoint: int, side: int) -> bool:
	return (
		_connection_slot_for_endpoint(endpoint, side) == 0
		and _get_grip(endpoint, side)
		and _get_cooldown(endpoint, side) <= 0.0
	)


func _endpoint_can_be_caught(endpoint: int, side: int) -> bool:
	return _endpoint_can_catch(endpoint, side)


func _update_dancer_collision_exception() -> void:
	if not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return
	# The 12 px circles are intentionally small enough for a proper two-hand
	# frame. Keeping them active prevents a double hold from collapsing both body
	# centres into the same space when the two constraints briefly disagree.
	dancer_a.remove_collision_exception_with(dancer_b)
	dancer_b.remove_collision_exception_with(dancer_a)


func _get_grip(endpoint: int, side: int) -> bool:
	return bool(_grip_a[side]) if endpoint == 1 else bool(_grip_b[side])


func _set_grip(endpoint: int, side: int, active: bool) -> void:
	if endpoint == 1:
		_grip_a[signi(side)] = active
	else:
		_grip_b[signi(side)] = active


func _get_button_down(endpoint: int, side: int) -> bool:
	return (
		bool(_button_down_a[side])
		if endpoint == 1
		else bool(_button_down_b[side])
	)


func _set_button_down(endpoint: int, side: int, is_down: bool) -> void:
	if endpoint == 1:
		_button_down_a[signi(side)] = is_down
	else:
		_button_down_b[signi(side)] = is_down


func _get_release_tap_armed(endpoint: int, side: int) -> bool:
	return (
		bool(_release_tap_armed_a[side])
		if endpoint == 1
		else bool(_release_tap_armed_b[side])
	)


func _set_release_tap_armed(endpoint: int, side: int, armed: bool) -> void:
	if endpoint == 1:
		_release_tap_armed_a[signi(side)] = armed
	else:
		_release_tap_armed_b[signi(side)] = armed


func _get_button_consumed(endpoint: int, side: int) -> bool:
	return (
		bool(_button_consumed_a[side])
		if endpoint == 1
		else bool(_button_consumed_b[side])
	)


func _set_button_consumed(endpoint: int, side: int, consumed: bool) -> void:
	if endpoint == 1:
		_button_consumed_a[signi(side)] = consumed
	else:
		_button_consumed_b[signi(side)] = consumed


func _get_cooldown(endpoint: int, side: int) -> float:
	return (
		float(_cooldown_a[side])
		if endpoint == 1
		else float(_cooldown_b[side])
	)


func _set_cooldown(endpoint: int, side: int, value: float) -> void:
	if endpoint == 1:
		_cooldown_a[signi(side)] = value
	else:
		_cooldown_b[signi(side)] = value


func _update_cooldowns(delta: float) -> void:
	for side in HAND_SIDES:
		_cooldown_a[side] = maxf(0.0, float(_cooldown_a[side]) - delta)
		_cooldown_b[side] = maxf(0.0, float(_cooldown_b[side]) - delta)


func _reset_diagnostics() -> void:
	distance_error = 0.0
	relative_hand_velocity = 0.0
	separation_limit_active = false
	primary_hand_separation = 0.0
	secondary_hand_separation = 0.0
	primary_allowed_separation = 0.0
	secondary_allowed_separation = 0.0
	primary_position_correction = 0.0
	secondary_position_correction = 0.0
	primary_velocity_correction = 0.0
	secondary_velocity_correction = 0.0
	double_hold_orbital_angular_velocity = 0.0
	double_hold_alignment_error = 0.0


func _draw() -> void:
	if not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return
	if is_connected:
		_draw_connected_pair(_connected_hand_a, _connected_hand_b)
	if is_secondary_connected:
		_draw_connected_pair(_secondary_hand_a, _secondary_hand_b)
	_draw_waiting_grips(dancer_a, 1)
	_draw_waiting_grips(dancer_b, 2)


func _draw_connected_pair(hand_a_side: int, hand_b_side: int) -> void:
	var hand_a := to_local(dancer_a.get_hand_world_position(hand_a_side))
	var hand_b := to_local(dancer_b.get_hand_world_position(hand_b_side))
	var midpoint := (hand_a + hand_b) * 0.5
	draw_line(hand_a, hand_b, Color("f0f0f0"), 4.0, true)
	draw_circle(midpoint, 13.0, Color(0.15, 0.15, 0.15, 0.22))
	draw_arc(midpoint, 12.0, 0.0, TAU, 24, Color("202020"), 3.0, true)


func _draw_waiting_grips(dancer: Dancer, endpoint: int) -> void:
	for side in HAND_SIDES:
		if not _get_grip(endpoint, side):
			continue
		if _connection_slot_for_endpoint(endpoint, side) != 0:
			continue
		var hand := to_local(dancer.get_hand_world_position(side))
		draw_arc(hand, 13.0, 0.0, TAU, 24, dancer.detail_color, 2.0, true)

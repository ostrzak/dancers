class_name HandConnection
extends Node2D

signal connection_changed(is_connected: bool)
signal grip_state_changed

@export_category("Catch Assist")
@export var catch_radius := 54.0
@export var maximum_relative_catch_velocity := 280.0
@export var release_cooldown := 0.35
@export var snap_duration := 0.22
@export var snap_response_rate := 18.0
@export var snap_velocity_correction := 0.7

@export_category("Physical Hold")
@export var weld_speed_threshold := 80.0
@export var elastic_speed_threshold := 400.0
@export var weld_response_rate := 12.0
@export var weld_velocity_correction := 0.55
@export var weld_tangential_correction := 0.35
@export var elastic_response_rate := 4.0
@export var elastic_velocity_correction := 0.18
@export var elastic_tangential_correction := 0.02
@export var maximum_spring_closing_speed := 240.0
@export var maximum_hand_separation := 27.0
@export var welded_hand_separation := 2.0
@export var dorsal_safety_margin := 2.0
@export var compliance_open_rate := 10.0
@export var compliance_close_rate := 3.5
@export var separation_projection_margin := 2.0
@export_range(1, 16, 1) var separation_projection_iterations := 8
@export_range(1, 4, 1) var velocity_projection_iterations := 1
@export var maximum_constraint_force := 4200.0

@export var dancer_a: Dancer
@export var dancer_b: Dancer

var is_connected := false
var is_secondary_connected := false
var distance_error := 0.0
var relative_hand_velocity := 0.0
var connection_force := 0.0
var primary_connection_force := 0.0
var secondary_connection_force := 0.0
var primary_elastic_blend := 0.0
var secondary_elastic_blend := 0.0
var separation_limit_active := false
var dorsal_limit_active := false
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
var double_hold_orbital_angular_velocity := 0.0
var double_hold_alignment_error := 0.0

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
var _primary_compliance := 0.0
var _secondary_compliance := 0.0
var _dancer_grip := {1: false, 2: false}
var _dancer_button_down := {1: false, 2: false}
var _dancer_release_tap_armed := {1: false, 2: false}
var _dancer_button_consumed := {1: false, 2: false}

const HAND_SIDES := [-1, 1]


func _ready() -> void:
	_update_dancer_collision_exception()


func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_reset_diagnostics()
	if not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return

	_try_connect_waiting_dancers()
	var double_hold_active := is_connected and is_secondary_connected
	_update_hold_compliance(delta, double_hold_active)
	if is_connected:
		primary_snap_remaining = maxf(0.0, primary_snap_remaining - delta)
		primary_connection_force = _process_hold_pair(
			_connected_hand_a,
			_connected_hand_b,
			1,
			double_hold_active,
			delta
		)
	if is_secondary_connected:
		secondary_snap_remaining = maxf(0.0, secondary_snap_remaining - delta)
		secondary_connection_force = _process_hold_pair(
			_secondary_hand_a,
			_secondary_hand_b,
			2,
			double_hold_active,
			delta
		)
	_solve_active_hold_constraints(delta)
	_update_active_hold_metrics()
	if double_hold_active:
		_update_double_hold_metrics()
	if not has_any_connection():
		_update_free_hand_metrics()
	connection_force = primary_connection_force + secondary_connection_force
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


func set_dancer_grip_state(dancer: Dancer, is_pressed: bool) -> void:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0 or bool(_dancer_button_down[endpoint]) == is_pressed:
		return

	_dancer_button_down[endpoint] = is_pressed
	if is_connected:
		_dancer_grip[endpoint] = false
		if is_pressed and bool(_dancer_release_tap_armed[endpoint]):
			_dancer_button_consumed[endpoint] = true
			_dancer_release_tap_armed[endpoint] = false
			release_hands()
		else:
			# Releasing the bumper used for the catch only arms the next tap.
			_dancer_release_tap_armed[endpoint] = not is_pressed
			if not is_pressed:
				_dancer_button_consumed[endpoint] = false
			grip_state_changed.emit()
			queue_redraw()
		return

	if is_pressed:
		if bool(_dancer_button_consumed[endpoint]):
			return
		_dancer_grip[endpoint] = true
		_try_connect_waiting_dancers()
	else:
		_dancer_grip[endpoint] = false
		_dancer_button_consumed[endpoint] = false
		_dancer_release_tap_armed[endpoint] = false
		grip_state_changed.emit()
		queue_redraw()


func is_hand_primed(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	if bool(_dancer_grip[endpoint]) and not is_connected:
		var closest_pair := _get_closest_hand_pair()
		return signi(hand_side) == int(closest_pair[endpoint - 1])
	return _get_grip(endpoint, signi(hand_side))


func is_grip_button_down(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	var relevant_side := (
		_connected_hand_a
		if endpoint == 1 and is_connected
		else _connected_hand_b
		if endpoint == 2 and is_connected
		else int(_get_closest_hand_pair()[endpoint - 1])
	)
	return (
		bool(_dancer_button_down[endpoint])
		and signi(hand_side) == relevant_side
	)


func is_release_tap_armed(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0 or not is_connected:
		return false
	var connected_side := _connected_hand_a if endpoint == 1 else _connected_hand_b
	return (
		bool(_dancer_release_tap_armed[endpoint])
		and signi(hand_side) == connected_side
	)


func is_dancer_primed(dancer: Dancer) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	return endpoint != 0 and bool(_dancer_grip[endpoint])


func release_hands() -> void:
	if not is_connected:
		return
	_release_pair(1, _connected_hand_a, _connected_hand_b)


func release_secondary_hands() -> void:
	return


func has_any_connection() -> bool:
	return is_connected


func get_active_connection_count() -> int:
	return int(is_connected)


func get_hold_mode() -> String:
	return "single" if is_connected else "free"


func get_solver_mode() -> String:
	return "spring"


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


func get_elastic_blend_for_speed(speed: float) -> float:
	var blend := inverse_lerp(
		weld_speed_threshold,
		maxf(weld_speed_threshold + 0.001, elastic_speed_threshold),
		maxf(0.0, speed)
	)
	blend = clampf(blend, 0.0, 1.0)
	return blend * blend * (3.0 - 2.0 * blend)


func _try_connect_waiting_hands() -> void:
	for side in HAND_SIDES:
		if _get_grip(1, side) and _connection_slot_for_endpoint(1, side) == 0:
			_try_connect_for_endpoint(1, side)
	for side in HAND_SIDES:
		if _get_grip(2, side) and _connection_slot_for_endpoint(2, side) == 0:
			_try_connect_for_endpoint(2, side)


func _try_connect_waiting_dancers() -> bool:
	if (
		is_connected
		or not bool(_dancer_grip[1])
		or not bool(_dancer_grip[2])
	):
		return false

	var best_distance := INF
	var best_hand_a := 0
	var best_hand_b := 0
	for hand_a_side in HAND_SIDES:
		if _get_cooldown(1, hand_a_side) > 0.0:
			continue
		for hand_b_side in HAND_SIDES:
			if _get_cooldown(2, hand_b_side) > 0.0:
				continue
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
				best_hand_a = hand_a_side
				best_hand_b = hand_b_side

	if best_hand_a == 0 or best_hand_b == 0:
		return false
	return _connect_pair(best_hand_a, best_hand_b)


func _get_closest_hand_pair() -> Array[int]:
	var best_distance := INF
	var best_pair: Array[int] = [1, 1]
	for hand_a_side in HAND_SIDES:
		for hand_b_side in HAND_SIDES:
			var separation_length := dancer_a.get_hand_world_position(
				hand_a_side
			).distance_to(dancer_b.get_hand_world_position(hand_b_side))
			if separation_length < best_distance:
				best_distance = separation_length
				best_pair = [hand_a_side, hand_b_side]
	return best_pair


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
	var dancer_level_ready := (
		bool(_dancer_grip[1])
		and bool(_dancer_grip[2])
	)
	var hand_level_ready := (
		_get_grip(1, hand_a_side)
		and _get_grip(2, hand_b_side)
	)
	if (
		is_connected
		or
		_connection_slot_for_endpoint(1, hand_a_side) != 0
		or _connection_slot_for_endpoint(2, hand_b_side) != 0
		or not (dancer_level_ready or hand_level_ready)
	):
		return false

	_connected_hand_a = signi(hand_a_side)
	_connected_hand_b = signi(hand_b_side)
	is_connected = true
	primary_snap_remaining = snap_duration
	_primary_compliance = 0.0
	if dancer_level_ready:
		_consume_dancer_catch_input()
	else:
		_consume_catch_input(hand_a_side, hand_b_side)
	_update_dancer_collision_exception()
	connection_changed.emit(true)
	grip_state_changed.emit()
	queue_redraw()
	return true


func _release_pair(slot: int, hand_a_side: int, hand_b_side: int) -> void:
	_consume_dancer_release_input()
	if slot == 1:
		is_connected = false
		primary_snap_remaining = 0.0
		_primary_compliance = 0.0
	else:
		is_secondary_connected = false
		secondary_snap_remaining = 0.0
		_secondary_compliance = 0.0
	for side in HAND_SIDES:
		_set_cooldown(1, side, release_cooldown)
		_set_cooldown(2, side, release_cooldown)
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


func _consume_dancer_catch_input() -> void:
	for endpoint in [1, 2]:
		_dancer_grip[endpoint] = false
		_dancer_button_consumed[endpoint] = true
		_dancer_release_tap_armed[endpoint] = false


func _consume_dancer_release_input() -> void:
	for endpoint in [1, 2]:
		_dancer_grip[endpoint] = false
		_dancer_button_consumed[endpoint] = bool(
			_dancer_button_down[endpoint]
		)
		_dancer_release_tap_armed[endpoint] = false


func _process_hold_pair(
	hand_a_side: int,
	hand_b_side: int,
	slot: int,
	double_hold_active: bool,
	delta: float
) -> float:
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var delta_position := hand_b - hand_a
	var separation_length := delta_position.length()
	var elastic_blend := (
		_primary_compliance if slot == 1 else _secondary_compliance
	)
	if double_hold_active:
		elastic_blend = 0.0
	var response_rate := lerpf(
		weld_response_rate,
		elastic_response_rate,
		elastic_blend
	)
	var velocity_correction := lerpf(
		weld_velocity_correction,
		elastic_velocity_correction,
		elastic_blend
	)
	var tangential_correction := lerpf(
		weld_tangential_correction,
		elastic_tangential_correction,
		elastic_blend
	)
	var snap_remaining := (
		primary_snap_remaining if slot == 1 else secondary_snap_remaining
	)
	if snap_remaining > 0.0:
		response_rate = maxf(response_rate, snap_response_rate)
		velocity_correction = maxf(
			velocity_correction,
			snap_velocity_correction
		)
	var maximum_impulse := maximum_constraint_force * maxf(delta, 0.0)
	var applied_impulse := 0.0
	if separation_length > 0.001:
		var direction := delta_position / separation_length
		var tangent := direction.orthogonal()
		var delta_velocity := (
			dancer_b.get_hand_velocity(hand_b_side)
			- dancer_a.get_hand_velocity(hand_a_side)
		)
		var extension := maxf(0.0, separation_length - welded_hand_separation)
		var desired_normal_speed := -minf(
			extension * response_rate,
			maximum_spring_closing_speed
		)
		var normal_correction := (
			(delta_velocity.dot(direction) - desired_normal_speed)
			* velocity_correction
		)
		applied_impulse += absf(_apply_pair_velocity_axis(
			hand_a_side,
			hand_b_side,
			direction,
			normal_correction,
			slot,
			false,
			maximum_impulse
		))
		delta_velocity = (
			dancer_b.get_hand_velocity(hand_b_side)
			- dancer_a.get_hand_velocity(hand_a_side)
		)
		applied_impulse += absf(_apply_pair_velocity_axis(
			hand_a_side,
			hand_b_side,
			tangent,
			delta_velocity.dot(tangent) * tangential_correction,
			slot,
			false,
			maxf(0.0, maximum_impulse - applied_impulse)
		))
	else:
		for axis in [Vector2.RIGHT, Vector2.DOWN]:
			var relative_speed := (
				dancer_b.get_hand_velocity(hand_b_side)
				- dancer_a.get_hand_velocity(hand_a_side)
			).dot(axis)
			applied_impulse += absf(_apply_pair_velocity_axis(
				hand_a_side,
				hand_b_side,
				axis,
				relative_speed * tangential_correction,
				slot,
				false,
				maxf(0.0, maximum_impulse - applied_impulse)
			))
	return applied_impulse / maxf(delta, 0.000001)


func _update_hold_compliance(delta: float, double_hold_active: bool) -> void:
	if is_connected:
		_primary_compliance = _next_pair_compliance(
			_primary_compliance,
			_connected_hand_a,
			_connected_hand_b,
			primary_snap_remaining > 0.0,
			double_hold_active,
			delta
		)
	else:
		_primary_compliance = 0.0
	if is_secondary_connected:
		_secondary_compliance = _next_pair_compliance(
			_secondary_compliance,
			_secondary_hand_a,
			_secondary_hand_b,
			secondary_snap_remaining > 0.0,
			double_hold_active,
			delta
		)
	else:
		_secondary_compliance = 0.0
	primary_elastic_blend = _primary_compliance
	secondary_elastic_blend = _secondary_compliance


func _next_pair_compliance(
	current: float,
	hand_a_side: int,
	hand_b_side: int,
	is_snapping: bool,
	double_hold_active: bool,
	delta: float
) -> float:
	# A new catch begins conservatively. After that, the hold responds to its own
	# physical travel rather than inventing a shared arm pose or body alignment.
	if is_snapping:
		return 0.0
	var relative_speed := (
		dancer_b.get_hand_velocity(hand_b_side)
		- dancer_a.get_hand_velocity(hand_a_side)
	).length()
	var offset_a := (
		dancer_a.get_hand_world_position(hand_a_side) - dancer_a.global_position
	)
	var offset_b := (
		dancer_b.get_hand_world_position(hand_b_side) - dancer_b.global_position
	)
	# Include body/arm travel so a firm low-speed spring can still graduate into
	# the faster fingertip-tether response.
	var maneuver_speed := (
		(dancer_b.linear_velocity - dancer_a.linear_velocity).length()
		+ absf(dancer_a.angular_velocity) * offset_a.length()
		+ absf(dancer_b.angular_velocity) * offset_b.length()
	)
	var speed := maxf(relative_speed, maneuver_speed)
	if double_hold_active:
		return 0.0
	var target := get_elastic_blend_for_speed(speed)
	var rate := compliance_open_rate if target > current else compliance_close_rate
	return move_toward(current, target, maxf(0.0, rate * delta))


func _solve_active_hold_constraints(delta: float) -> void:
	primary_allowed_separation = (
		_get_pair_allowed_separation(_connected_hand_a, _connected_hand_b)
		if is_connected
		else 0.0
	)
	secondary_allowed_separation = (
		_get_pair_allowed_separation(_secondary_hand_a, _secondary_hand_b)
		if is_secondary_connected
		else 0.0
	)
	for _iteration in separation_projection_iterations:
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
	for _iteration in velocity_projection_iterations:
		if is_connected:
			_solve_pair_velocity(
				_connected_hand_a,
				_connected_hand_b,
				primary_allowed_separation,
				delta,
				1
			)
		if is_secondary_connected:
			_solve_pair_velocity(
				_secondary_hand_a,
				_secondary_hand_b,
				secondary_allowed_separation,
				delta,
				2
			)


func _get_pair_allowed_separation(hand_a_side: int, hand_b_side: int) -> float:
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var gap := hand_b - hand_a
	if gap.length() <= dorsal_safety_margin:
		return maximum_hand_separation
	var dorsal_a := dancer_a.get_dorsal_local_direction().rotated(
		dancer_a.global_rotation
	)
	var dorsal_b := dancer_b.get_dorsal_local_direction().rotated(
		dancer_b.global_rotation
	)
	var dorsal_to_dorsal := (
		gap.dot(dorsal_a) > dorsal_safety_margin
		and (-gap).dot(dorsal_b) > dorsal_safety_margin
	)
	if dorsal_to_dorsal:
		dorsal_limit_active = true
		return welded_hand_separation
	return maxf(
		welded_hand_separation,
		maximum_hand_separation - separation_projection_margin
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
	# The minimal torso circles remain active during the one-hand spring.
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
	connection_force = 0.0
	primary_connection_force = 0.0
	secondary_connection_force = 0.0
	primary_elastic_blend = _primary_compliance if is_connected else 0.0
	secondary_elastic_blend = (
		_secondary_compliance if is_secondary_connected else 0.0
	)
	separation_limit_active = false
	dorsal_limit_active = false
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
		if not is_hand_primed(dancer, side):
			continue
		if _connection_slot_for_endpoint(endpoint, side) != 0:
			continue
		var hand := to_local(dancer.get_hand_world_position(side))
		draw_arc(hand, 13.0, 0.0, TAU, 24, dancer.detail_color, 2.0, true)

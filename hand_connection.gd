class_name HandConnection
extends Node2D

signal connection_changed(is_connected: bool)
signal grip_state_changed

@export_category("Catch Assist")
@export var catch_radius := 54.0
@export var maximum_relative_catch_velocity := 280.0
@export var release_cooldown := 0.35
@export var snap_duration := 0.22
@export var snap_stiffness := 120.0
@export var snap_damping := 20.0

@export_category("Physical Hold")
@export var weld_speed_threshold := 80.0
@export var elastic_speed_threshold := 500.0
@export var weld_stiffness := 96.0
@export var weld_normal_damping := 16.0
@export var weld_tangential_damping := 12.0
@export var elastic_stiffness := 42.0
@export var elastic_normal_damping := 2.0
@export var elastic_tangential_damping := 0.5
@export var maximum_hand_separation := 36.0
@export var separation_projection_margin := 0.75
@export_range(1, 16, 1) var separation_projection_iterations := 8
@export var separation_stiffness := 120.0
@export var separation_damping := 12.0
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
var primary_snap_remaining := 0.0
var secondary_snap_remaining := 0.0

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

const HAND_SIDES := [-1, 1]


func _ready() -> void:
	_update_dancer_collision_exception()


func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_reset_diagnostics()
	if not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return

	_try_connect_waiting_hands()
	_enforce_active_maximum_separations(delta)
	if is_connected:
		primary_snap_remaining = maxf(0.0, primary_snap_remaining - delta)
		primary_connection_force = _process_hold_pair(
			_connected_hand_a,
			_connected_hand_b,
			primary_snap_remaining > 0.0,
			1,
			delta
		)
	if is_secondary_connected:
		secondary_snap_remaining = maxf(0.0, secondary_snap_remaining - delta)
		secondary_connection_force = _process_hold_pair(
			_secondary_hand_a,
			_secondary_hand_b,
			secondary_snap_remaining > 0.0,
			2,
			delta
		)
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
	elif not is_secondary_connected:
		_secondary_hand_a = signi(hand_a_side)
		_secondary_hand_b = signi(hand_b_side)
		is_secondary_connected = true
		secondary_snap_remaining = snap_duration
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
	else:
		is_secondary_connected = false
		secondary_snap_remaining = 0.0
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


func _process_hold_pair(
	hand_a_side: int,
	hand_b_side: int,
	is_snapping: bool,
	slot: int,
	delta: float = 1.0 / 120.0
) -> float:
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var hand_velocity_a := dancer_a.get_hand_velocity(hand_a_side)
	var hand_velocity_b := dancer_b.get_hand_velocity(hand_b_side)
	var delta_position := hand_b - hand_a
	var delta_velocity := hand_velocity_b - hand_velocity_a
	var separation_length := delta_position.length()
	distance_error = maxf(distance_error, separation_length)
	relative_hand_velocity = maxf(relative_hand_velocity, delta_velocity.length())

	var elastic_blend := get_elastic_blend_for_speed(delta_velocity.length())
	if slot == 1:
		primary_elastic_blend = elastic_blend
	else:
		secondary_elastic_blend = elastic_blend
	var stiffness := lerpf(weld_stiffness, elastic_stiffness, elastic_blend)
	var normal_damping := lerpf(
		weld_normal_damping,
		elastic_normal_damping,
		elastic_blend
	)
	var tangential_damping := lerpf(
		weld_tangential_damping,
		elastic_tangential_damping,
		elastic_blend
	)
	if is_snapping:
		stiffness = maxf(stiffness, lerpf(snap_stiffness, elastic_stiffness, elastic_blend))
		normal_damping = maxf(
			normal_damping,
			lerpf(snap_damping, elastic_normal_damping, elastic_blend)
		)

	var force := Vector2.ZERO
	var direction := delta_position / separation_length if separation_length > 0.001 else Vector2.RIGHT
	var normal_stiffness := stiffness
	if separation_length > 0.001:
		var normal_speed := delta_velocity.dot(direction)
		var tangential_velocity := delta_velocity - direction * normal_speed
		force = direction * (
			separation_length * stiffness
			+ normal_speed * normal_damping
		)
		force += tangential_velocity * tangential_damping
		if separation_length > maximum_hand_separation:
			normal_stiffness += separation_stiffness
			separation_limit_active = true
			var separating_speed := maxf(0.0, normal_speed)
			force += direction * (
				(separation_length - maximum_hand_separation) * separation_stiffness
				+ separating_speed * separation_damping
			)
			if normal_speed > 0.0:
				normal_damping += separation_damping
	else:
		force = delta_velocity * tangential_damping
	var offset_a := hand_a - dancer_a.global_position
	var offset_b := hand_b - dancer_b.global_position
	force = _implicit_spring_force(force, delta_velocity, direction,
		Vector2(normal_stiffness, stiffness), Vector2(normal_damping, tangential_damping),
		offset_a, offset_b, delta).limit_length(maximum_constraint_force)
	dancer_a.apply_force(force, offset_a)
	dancer_b.apply_force(-force, offset_b)
	return force.length()


func _implicit_spring_force(requested: Vector2, velocity: Vector2, normal: Vector2,
		stiffness: Vector2, damping: Vector2, offset_a: Vector2, offset_b: Vector2,
		delta: float) -> Vector2:
	if delta <= 0.0:
		return Vector2.ZERO
	# Endpoint inverse mass includes rotation about each body's centre. Ignoring
	# those lever arms makes even modest explicit damping reverse hand velocity
	# every tick. Backward Euler evaluates spring/damping at the resulting velocity.
	var inverse_mass := 1.0 / dancer_a.mass + 1.0 / dancer_b.mass
	var lever_a := Vector2(-offset_a.y, offset_a.x)
	var lever_b := Vector2(-offset_b.y, offset_b.x)
	var inverse_inertia_a := 1.0 / maxf(dancer_a.inertia, 0.001)
	var inverse_inertia_b := 1.0 / maxf(dancer_b.inertia, 0.001)
	# Two simultaneous pairs share the same bodies. This conservative block
	# bound budgets the response across both, avoiding competing independent solves.
	var pairs := float(maxi(get_active_connection_count(), 1))
	var kxx := pairs * (inverse_mass + lever_a.x * lever_a.x * inverse_inertia_a
		+ lever_b.x * lever_b.x * inverse_inertia_b)
	var kxy := pairs * (lever_a.x * lever_a.y * inverse_inertia_a
		+ lever_b.x * lever_b.y * inverse_inertia_b)
	var kyy := pairs * (inverse_mass + lever_a.y * lever_a.y * inverse_inertia_a
		+ lever_b.y * lever_b.y * inverse_inertia_b)
	var normal_coefficient := delta * damping.x + delta * delta * stiffness.x
	var tangent_coefficient := delta * damping.y + delta * delta * stiffness.y
	var difference := normal_coefficient - tangent_coefficient
	var bxx := tangent_coefficient + difference * normal.x * normal.x
	var bxy := difference * normal.x * normal.y
	var byy := tangent_coefficient + difference * normal.y * normal.y
	var a11 := 1.0 + bxx * kxx + bxy * kxy
	var a12 := bxx * kxy + bxy * kyy
	var a21 := bxy * kxx + byy * kxy
	var a22 := 1.0 + bxy * kxy + byy * kyy
	var rhs := requested + delta * (stiffness.y * velocity
		+ (stiffness.x - stiffness.y) * normal * velocity.dot(normal))
	var determinant := a11 * a22 - a12 * a21
	return Vector2(a22 * rhs.x - a12 * rhs.y, a11 * rhs.y - a21 * rhs.x) / determinant


func _enforce_active_maximum_separations(delta: float) -> void:
	for _iteration in separation_projection_iterations:
		var corrected_any_pair := false
		if is_connected:
			corrected_any_pair = (
				_enforce_maximum_separation(_connected_hand_a, _connected_hand_b, delta)
				or corrected_any_pair
			)
		if is_secondary_connected:
			corrected_any_pair = (
				_enforce_maximum_separation(_secondary_hand_a, _secondary_hand_b, delta)
				or corrected_any_pair
			)
		if not corrected_any_pair:
			break


func _enforce_maximum_separation(
	hand_a_side: int,
	hand_b_side: int,
	delta: float
) -> bool:
	var hand_a := dancer_a.get_hand_world_position(hand_a_side)
	var hand_b := dancer_b.get_hand_world_position(hand_b_side)
	var delta_position := hand_b - hand_a
	var separation_length := delta_position.length()
	if separation_length <= 0.001:
		return false

	var direction := delta_position / separation_length
	var inverse_mass_a := (
		0.0 if dancer_a.position_lock_active else 1.0 / maxf(dancer_a.mass, 0.001)
	)
	var inverse_mass_b := (
		0.0 if dancer_b.position_lock_active else 1.0 / maxf(dancer_b.mass, 0.001)
	)
	var inverse_mass_sum := inverse_mass_a + inverse_mass_b
	if inverse_mass_sum <= 0.001:
		return false

	var corrected := false
	var projection_limit := maxf(
		0.0,
		maximum_hand_separation - separation_projection_margin
	)
	var excess := maxf(0.0, separation_length - projection_limit)
	if excess > 0.0:
		separation_limit_active = true
		corrected = true
		# Correct translation only. Off-centre spring forces remain the sole source
		# of body rotation, so the safety solve cannot inject a turn.
		dancer_a.global_position += direction * excess * inverse_mass_a / inverse_mass_sum
		dancer_b.global_position -= direction * excess * inverse_mass_b / inverse_mass_sum

	hand_a = dancer_a.get_hand_world_position(hand_a_side)
	hand_b = dancer_b.get_hand_world_position(hand_b_side)
	delta_position = hand_b - hand_a
	if delta_position.length_squared() > 0.001:
		direction = delta_position.normalized()
	var corrected_velocity_a := dancer_a.get_hand_velocity(hand_a_side)
	var corrected_velocity_b := dancer_b.get_hand_velocity(hand_b_side)
	var separating_speed := (corrected_velocity_b - corrected_velocity_a).dot(direction)
	var allowed_separating_speed := 0.0
	var corrected_distance := delta_position.length()
	if delta > 0.0 and corrected_distance < projection_limit:
		allowed_separating_speed = (
			(projection_limit - corrected_distance) / delta
		)
	if separating_speed > allowed_separating_speed:
		separation_limit_active = true
		corrected = true
		var velocity_impulse := (
			(separating_speed - allowed_separating_speed) / inverse_mass_sum
		)
		dancer_a.linear_velocity += direction * velocity_impulse * inverse_mass_a
		dancer_b.linear_velocity -= direction * velocity_impulse * inverse_mass_b
	return corrected


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
	# Keep the torso circles active in both holds so the bodies retain their
	# space even when the two constraints briefly disagree.
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
	primary_elastic_blend = 0.0
	secondary_elastic_blend = 0.0
	separation_limit_active = false


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

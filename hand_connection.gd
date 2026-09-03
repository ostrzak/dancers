class_name HandConnection
extends Node2D

signal connection_changed(is_connected: bool)
signal grip_state_changed

@export_category("Catch Assist")
@export var catch_radius := 54.0
@export var maximum_relative_catch_velocity := 280.0
@export var release_cooldown := 0.35
@export var snap_duration := 0.22
@export var snap_stiffness := 64.0
@export var snap_damping := 10.0

@export_category("Physical Hold")
@export var spring_stiffness := 42.0
@export var spring_damping := 8.0
@export var maximum_hand_separation := 36.0
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
var separation_limit_active := false
var primary_snap_remaining := 0.0
var secondary_snap_remaining := 0.0

var _connected_hand_a := 1
var _connected_hand_b := 1
var _secondary_hand_a := -1
var _secondary_hand_b := -1
var _grip_a := {-1: false, 1: false}
var _grip_b := {-1: false, 1: false}
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
	if is_connected:
		primary_snap_remaining = maxf(0.0, primary_snap_remaining - delta)
		primary_connection_force = _process_hold_pair(
			_connected_hand_a,
			_connected_hand_b,
			primary_snap_remaining > 0.0
		)
	if is_secondary_connected:
		secondary_snap_remaining = maxf(0.0, secondary_snap_remaining - delta)
		secondary_connection_force = _process_hold_pair(
			_secondary_hand_a,
			_secondary_hand_b,
			secondary_snap_remaining > 0.0
		)
	if not has_any_connection():
		_update_free_hand_metrics()
	connection_force = primary_connection_force + secondary_connection_force
	queue_redraw()


func set_grip_active(dancer: Dancer, hand_side: int, active: bool) -> bool:
	var side := signi(hand_side)
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	if _get_grip(endpoint, side) == active:
		return active

	var slot := _connection_slot_for_endpoint(endpoint, side)
	_set_grip(endpoint, side, active)
	if not active and slot == 1:
		_release_pair(1, _connected_hand_a, _connected_hand_b)
	elif not active and slot == 2:
		_release_pair(2, _secondary_hand_a, _secondary_hand_b)
	elif active:
		if not _try_connect_for_endpoint(endpoint, side):
			grip_state_changed.emit()
			queue_redraw()
	else:
		grip_state_changed.emit()
		queue_redraw()
	return active


func is_grip_active(dancer: Dancer, hand_side: int) -> bool:
	var endpoint := _endpoint_for_dancer(dancer)
	if endpoint == 0:
		return false
	return _get_grip(endpoint, signi(hand_side))


func release_hands() -> void:
	if not is_connected:
		return
	_set_grip(1, _connected_hand_a, false)
	_set_grip(2, _connected_hand_b, false)
	_release_pair(1, _connected_hand_a, _connected_hand_b)


func release_secondary_hands() -> void:
	if not is_secondary_connected:
		return
	_set_grip(1, _secondary_hand_a, false)
	_set_grip(2, _secondary_hand_b, false)
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
	elif not is_secondary_connected:
		_secondary_hand_a = signi(hand_a_side)
		_secondary_hand_b = signi(hand_b_side)
		is_secondary_connected = true
		secondary_snap_remaining = snap_duration
	else:
		return false

	_update_dancer_collision_exception()
	connection_changed.emit(true)
	grip_state_changed.emit()
	queue_redraw()
	return true


func _release_pair(slot: int, hand_a_side: int, hand_b_side: int) -> void:
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


func _process_hold_pair(
	hand_a_side: int,
	hand_b_side: int,
	is_snapping: bool
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

	var stiffness := snap_stiffness if is_snapping else spring_stiffness
	var damping := snap_damping if is_snapping else spring_damping
	var force := delta_position * stiffness + delta_velocity * damping
	if separation_length > maximum_hand_separation and separation_length > 0.001:
		var direction := delta_position / separation_length
		var separating_speed := maxf(0.0, delta_velocity.dot(direction))
		force += direction * (
			(separation_length - maximum_hand_separation) * separation_stiffness
			+ separating_speed * separation_damping
		)
		separation_limit_active = true
	force = force.limit_length(maximum_constraint_force)

	var offset_a := hand_a - dancer_a.global_position
	var offset_b := hand_b - dancer_b.global_position
	dancer_a.apply_force(force, offset_a)
	dancer_b.apply_force(-force, offset_b)
	return force.length()


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
	if get_active_connection_count() >= 2:
		dancer_a.add_collision_exception_with(dancer_b)
		dancer_b.add_collision_exception_with(dancer_a)
	else:
		dancer_a.remove_collision_exception_with(dancer_b)
		dancer_b.remove_collision_exception_with(dancer_a)


func _get_grip(endpoint: int, side: int) -> bool:
	return bool(_grip_a[side]) if endpoint == 1 else bool(_grip_b[side])


func _set_grip(endpoint: int, side: int, active: bool) -> void:
	if endpoint == 1:
		_grip_a[signi(side)] = active
	else:
		_grip_b[signi(side)] = active


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

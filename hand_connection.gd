class_name HandConnection
extends Node2D

signal connection_changed(is_connected: bool)

@export_category("Catch")
@export var catch_radius := 26.0
@export var maximum_relative_catch_velocity := 210.0
@export var release_cooldown := 0.35

@export_category("Connection")
@export var spring_stiffness := 18.0
@export var spring_damping := 2.2
@export var maximum_numerical_safety_force := 4200.0

@export var dancer_a: Dancer
@export var dancer_b: Dancer

var is_connected := false
var distance_error := 0.0
var relative_hand_velocity := 0.0
var connection_force := 0.0
var _cooldown_remaining := 0.0
var _connected_hand_a := 1
var _connected_hand_b := 1

const HAND_SIDES := [-1, 1]


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return

	connection_force = 0.0

	if is_connected:
		var hand_a := dancer_a.get_hand_world_position(_connected_hand_a)
		var hand_b := dancer_b.get_hand_world_position(_connected_hand_b)
		var hand_velocity_a := dancer_a.get_hand_velocity(_connected_hand_a)
		var hand_velocity_b := dancer_b.get_hand_velocity(_connected_hand_b)
		var delta_position := hand_b - hand_a
		var delta_velocity := hand_velocity_b - hand_velocity_a
		distance_error = delta_position.length()
		relative_hand_velocity = delta_velocity.length()
		_apply_constraint_force(delta_position, delta_velocity)
	else:
		_update_open_hand_metrics_and_try_catch()

	queue_redraw()


func connect_hands(hand_a_side: int = 1, hand_b_side: int = 1) -> void:
	if is_connected:
		return
	_connected_hand_a = signi(hand_a_side)
	_connected_hand_b = signi(hand_b_side)
	is_connected = true
	connection_changed.emit(true)
	queue_redraw()


func release_hands() -> void:
	if not is_connected:
		return
	# Removing the force relationship is the whole release operation. No body
	# velocity or transform is touched, so the existing throw carries through.
	is_connected = false
	connection_force = 0.0
	_cooldown_remaining = release_cooldown
	connection_changed.emit(false)
	queue_redraw()


func _apply_constraint_force(delta_position: Vector2, delta_velocity: Vector2) -> void:
	var force := delta_position * spring_stiffness + delta_velocity * spring_damping
	force = force.limit_length(maximum_numerical_safety_force)
	connection_force = force.length()

	var offset_a := dancer_a.get_hand_world_position(_connected_hand_a) - dancer_a.global_position
	var offset_b := dancer_b.get_hand_world_position(_connected_hand_b) - dancer_b.global_position
	dancer_a.apply_force(force, offset_a)
	dancer_b.apply_force(-force, offset_b)


func _update_open_hand_metrics_and_try_catch() -> void:
	var closest_distance := INF
	var closest_relative_velocity := 0.0
	var catch_distance := INF
	var catch_hand_a := 1
	var catch_hand_b := 1

	for side_a in HAND_SIDES:
		for side_b in HAND_SIDES:
			var hand_a := dancer_a.get_hand_world_position(side_a)
			var hand_b := dancer_b.get_hand_world_position(side_b)
			var separation := hand_b - hand_a
			var relative_velocity := (
				dancer_b.get_hand_velocity(side_b) - dancer_a.get_hand_velocity(side_a)
			).length()
			var separation_length := separation.length()
			if separation_length < closest_distance:
				closest_distance = separation_length
				closest_relative_velocity = relative_velocity
			if _cooldown_remaining <= 0.0 \
					and separation_length <= catch_radius \
					and relative_velocity <= maximum_relative_catch_velocity \
					and separation_length < catch_distance:
				catch_distance = separation_length
				catch_hand_a = side_a
				catch_hand_b = side_b

	distance_error = closest_distance
	relative_hand_velocity = closest_relative_velocity
	if catch_distance < INF:
		connect_hands(catch_hand_a, catch_hand_b)


func _draw() -> void:
	if not is_connected or not is_instance_valid(dancer_a) or not is_instance_valid(dancer_b):
		return
	var hand_a := to_local(dancer_a.get_hand_world_position(_connected_hand_a))
	var hand_b := to_local(dancer_b.get_hand_world_position(_connected_hand_b))
	var midpoint := (hand_a + hand_b) * 0.5
	draw_line(hand_a, hand_b, Color("f0f0f0"), 4.0, true)
	draw_circle(midpoint, 13.0, Color(0.15, 0.15, 0.15, 0.22))
	draw_arc(midpoint, 12.0, 0.0, TAU, 24, Color("202020"), 3.0, true)

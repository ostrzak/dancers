class_name Dancer
extends RigidBody2D

@export_category("Identity")
@export var dancer_name := "Dancer"
@export var body_color := Color("111111")
@export var detail_color := Color("f2f2f2")
@export_enum("Man", "Woman") var body_style := 0

@export_category("Movement")
@export var movement_force := 900.0
@export var movement_linear_damping := 2.2
@export var maximum_input_speed := 360.0

@export_category("Facing")
@export var spin_torque := 15000.0
@export var spin_response_gain := 9000.0
@export var facing_response_rate := 10.0
@export var minimum_target_angular_velocity := 8.0
@export var maximum_target_angular_velocity := 12.0
@export var spin_angular_damping := 0.7

@export_category("Physical Locks")
@export var position_lock_stiffness := 1400.0
@export var position_lock_damping := 82.0
@export var maximum_position_lock_force := 16000.0
@export var rotation_lock_stiffness := 240000.0
@export var rotation_lock_damping := 22000.0
@export var maximum_rotation_lock_torque := 900000.0

@export_category("Arm")
@export var minimum_arm_length := 33.6
@export var maximum_arm_length := 82.6
@export var arm_interpolation_speed := 126.0
@export var hand_line_offset := 0.0
@export var shoulder_half_width := 17.0
@export var upper_arm_length := 36.4
@export var forearm_length := 36.4
@export_range(0.0, 90.0, 1.0) var minimum_abduction_degrees := 0.0
@export_range(0.0, 90.0, 1.0) var maximum_abduction_degrees := 84.0
@export_range(0.0, 180.0, 1.0) var minimum_elbow_flexion_degrees := 12.0
@export_range(0.0, 180.0, 1.0) var maximum_elbow_flexion_degrees := 145.0
@export_range(0.0, 90.0, 1.0) var minimum_forearm_out_of_plane_degrees := 0.0
@export_range(0.0, 90.0, 1.0) var maximum_forearm_out_of_plane_degrees := 80.0
@export var base_effective_inertia := 320.0
@export var arm_inertia_scale := 0.015
@export var effective_inertia_influence := 1.0

var movement_input := Vector2.ZERO
var facing_input := Vector2.ZERO
var desired_facing_direction := Vector2.UP
var left_trigger_value := 0.0
var right_trigger_value := 0.0
var target_angular_velocity := 0.0
var heading_error := 0.0
var diagnostic_movement_force := Vector2.ZERO
var diagnostic_spin_torque := 0.0
var diagnostic_position_lock_force := Vector2.ZERO
var diagnostic_rotation_lock_torque := 0.0
var spin_speed_scale := 1.0
var move_speed_scale := 1.0
var spin_move_ratio := 1.0
var position_lock_active := false
var rotation_lock_active := false
var position_lock_anchor := Vector2.ZERO
var rotation_lock_anchor := 0.0

var _current_arm_lengths := {
	-1: 82.6,
	1: 82.6,
}
var _unwrapped_rotation := 0.0
var _previous_wrapped_rotation := 0.0
var _desired_facing_rotation := 0.0
var _previous_facing_input_angle := 0.0
var _facing_gesture_active := false

const HAND_RADIUS := 9.0
const ELBOW_RADIUS := 5.0
const HAND_SIDES := [-1, 1]


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = movement_linear_damping
	angular_damp = spin_angular_damping
	_current_arm_lengths[-1] = maximum_arm_length
	_current_arm_lengths[1] = maximum_arm_length
	desired_facing_direction = Vector2.UP.rotated(global_rotation)
	_previous_wrapped_rotation = global_rotation
	_unwrapped_rotation = global_rotation
	_desired_facing_rotation = global_rotation
	_update_effective_inertia()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_unwrapped_rotation()
	for side in HAND_SIDES:
		var current_length := get_current_arm_length(side)
		var desired_length := lerpf(
			maximum_arm_length,
			minimum_arm_length,
			get_trigger_value(side)
		)
		_current_arm_lengths[side] = move_toward(
			current_length,
			desired_length,
			arm_interpolation_speed * delta
		)
	_update_effective_inertia()
	_apply_movement_force()
	_apply_position_lock_force()
	_apply_facing_torque()
	_apply_rotation_lock_torque()
	queue_redraw()


func set_control_input(
	new_movement_input: Vector2,
	new_facing_input: Vector2,
	new_left_trigger_value: float,
	new_right_trigger_value: float,
	new_position_lock_active: bool = false,
	new_rotation_lock_active: bool = false
) -> void:
	if new_position_lock_active and not position_lock_active:
		position_lock_anchor = global_position
	if new_rotation_lock_active and not rotation_lock_active:
		rotation_lock_anchor = global_rotation
	position_lock_active = new_position_lock_active
	rotation_lock_active = new_rotation_lock_active
	movement_input = new_movement_input.limit_length(1.0)
	facing_input = new_facing_input.limit_length(1.0)
	if not facing_input.is_zero_approx():
		desired_facing_direction = facing_input.normalized()
		var facing_angle := desired_facing_direction.angle()
		if rotation_lock_active:
			# R3 is a physical orientation lock, not a stored-turn windup. Keep the
			# latest screen direction but discard rotation backlog while it is held.
			var locked_wrapped_target := facing_angle + PI * 0.5
			_desired_facing_rotation = _unwrapped_rotation + wrapf(
				locked_wrapped_target - global_rotation,
				-PI,
				PI
			)
			_facing_gesture_active = false
		elif _facing_gesture_active:
			_desired_facing_rotation += wrapf(
				facing_angle - _previous_facing_input_angle,
				-PI,
				PI
			)
		else:
			var wrapped_target := facing_angle + PI * 0.5
			_desired_facing_rotation = _unwrapped_rotation + wrapf(
				wrapped_target - global_rotation,
				-PI,
				PI
			)
		_facing_gesture_active = true
		_previous_facing_input_angle = facing_angle
	elif _facing_gesture_active:
		# Releasing RS keeps the final screen direction but discards any backlog
		# of full rotations the physical body could not complete during the gesture.
		var final_wrapped_target := desired_facing_direction.angle() + PI * 0.5
		_desired_facing_rotation = _unwrapped_rotation + wrapf(
			final_wrapped_target - global_rotation,
			-PI,
			PI
		)
		_facing_gesture_active = false
	left_trigger_value = clampf(new_left_trigger_value, 0.0, 1.0)
	right_trigger_value = clampf(new_right_trigger_value, 0.0, 1.0)


func set_runtime_tuning(
	new_spin_speed_scale: float,
	new_move_speed_scale: float,
	new_spin_move_ratio: float
) -> void:
	spin_speed_scale = maxf(new_spin_speed_scale, 0.0)
	move_speed_scale = maxf(new_move_speed_scale, 0.0)
	spin_move_ratio = maxf(new_spin_move_ratio, 0.0)


func get_trigger_value(side: int) -> float:
	return left_trigger_value if signi(side) < 0 else right_trigger_value


func get_current_arm_length(side: int) -> float:
	return float(_current_arm_lengths[signi(side)])


func set_current_arm_length(side: int, value: float) -> void:
	_current_arm_lengths[signi(side)] = clampf(
		value,
		minimum_arm_length,
		maximum_arm_length
	)


func get_average_arm_flexion() -> float:
	return (get_arm_flexion(-1) + get_arm_flexion(1)) * 0.5


func get_turn_speed_limit() -> float:
	return (
		lerpf(
			minimum_target_angular_velocity,
			maximum_target_angular_velocity,
			get_average_arm_flexion()
		)
		* spin_speed_scale
	)


func get_desired_facing_rotation() -> float:
	return _desired_facing_rotation


func get_hand_world_position(side: int = 1) -> Vector2:
	return global_position + get_hand_offset(side)


func get_hand_offset(side: int = 1) -> Vector2:
	return get_hand_local_position(side).rotated(global_rotation)


func get_hand_velocity(side: int = 1) -> Vector2:
	var offset := get_hand_offset(side)
	return linear_velocity + Vector2(-offset.y, offset.x) * angular_velocity


func get_hand_local_position(side: int = 1) -> Vector2:
	return (
		get_elbow_local_position(side)
		+ get_forearm_local_direction(side) * get_projected_forearm_length(side)
	)


func get_shoulder_local_position(side: int = 1) -> Vector2:
	return Vector2(shoulder_half_width * signi(side), hand_line_offset)


func get_shoulder_world_position(side: int = 1) -> Vector2:
	return global_position + get_shoulder_local_position(side).rotated(global_rotation)


func get_maximum_hand_reach() -> float:
	return upper_arm_length + forearm_length


func get_arm_flexion(side: int = 1) -> float:
	return clampf(
		inverse_lerp(
			maximum_arm_length,
			minimum_arm_length,
			get_current_arm_length(side)
		),
		0.0,
		1.0
	)


func get_abduction_degrees(side: int = 1) -> float:
	return lerpf(
		maximum_abduction_degrees,
		minimum_abduction_degrees,
		get_arm_flexion(side)
	)


func get_projected_upper_arm_length(side: int = 1) -> float:
	return upper_arm_length * sin(deg_to_rad(get_abduction_degrees(side)))


func get_elbow_flexion_degrees(side: int = 1) -> float:
	return lerpf(
		minimum_elbow_flexion_degrees,
		maximum_elbow_flexion_degrees,
		get_arm_flexion(side)
	)


func get_forearm_out_of_plane_degrees(side: int = 1) -> float:
	return lerpf(
		minimum_forearm_out_of_plane_degrees,
		maximum_forearm_out_of_plane_degrees,
		get_arm_flexion(side)
	)


func get_projected_forearm_length(side: int = 1) -> float:
	# As the humerus reorients the elbow hinge, more of the forearm's flexion arc
	# leaves the screen plane. Cosine projection makes shortening continuous but
	# naturally more visible toward the fully adducted endpoint.
	return (
		forearm_length
		* cos(deg_to_rad(get_forearm_out_of_plane_degrees(side)))
	)


func get_elbow_joint_radius(side: int = 1) -> float:
	# At full adduction the elbow overlaps the shoulder in projection. Enlarge
	# that single visible joint into a compact, hand-sized shoulder cap.
	return lerpf(ELBOW_RADIUS, HAND_RADIUS, get_arm_flexion(side))


func get_dorsal_local_direction() -> Vector2:
	# Both pictograms face toward their heads at the top of the body, so their
	# anatomical back is down in body-local space.
	return Vector2.DOWN


func get_elbow_local_position(side: int = 1) -> Vector2:
	# Abduction happens outside the top-down viewing plane. Keep the humerus
	# radial on screen and communicate that motion through its projected length.
	var outward := Vector2.RIGHT * float(signi(side))
	return (
		get_shoulder_local_position(side)
		+ outward * get_projected_upper_arm_length(side)
	)


func get_forearm_local_direction(side: int = 1) -> Vector2:
	# Mirror the elbow rotation so both forearms fold through the dancer's dorsal
	# side and eventually point back inward toward the torso.
	var side_sign := float(signi(side))
	var outward := Vector2.RIGHT * side_sign
	return outward.rotated(deg_to_rad(get_elbow_flexion_degrees(side)) * side_sign)


func get_spin_move_scale() -> float:
	var minimum_spin := maxf(minimum_target_angular_velocity, 0.001)
	var pose_spin_ratio := lerpf(
		minimum_target_angular_velocity,
		maximum_target_angular_velocity,
		get_average_arm_flexion()
	) / minimum_spin
	return 1.0 + (pose_spin_ratio - 1.0) * spin_move_ratio


func get_effective_move_scale() -> float:
	return move_speed_scale * get_spin_move_scale()


func _apply_movement_force() -> void:
	diagnostic_movement_force = Vector2.ZERO
	if position_lock_active or movement_input.is_zero_approx():
		return
	var effective_move_scale := get_effective_move_scale()
	var force_scale := 1.0
	if maximum_input_speed > 0.0:
		var along_input := linear_velocity.dot(movement_input.normalized())
		if along_input > maximum_input_speed * effective_move_scale:
			force_scale = 0.0
	diagnostic_movement_force = (
		movement_input * movement_force * effective_move_scale * force_scale
	)
	apply_central_force(diagnostic_movement_force)


func _apply_position_lock_force() -> void:
	diagnostic_position_lock_force = Vector2.ZERO
	if not position_lock_active:
		return
	diagnostic_position_lock_force = (
		(position_lock_anchor - global_position) * position_lock_stiffness
		- linear_velocity * position_lock_damping
	).limit_length(maximum_position_lock_force)
	apply_central_force(diagnostic_position_lock_force)


func _apply_facing_torque() -> void:
	diagnostic_spin_torque = 0.0
	heading_error = get_desired_facing_rotation() - _unwrapped_rotation
	if rotation_lock_active or facing_input.is_zero_approx():
		target_angular_velocity = 0.0
		return
	var turn_speed_limit := get_turn_speed_limit()
	target_angular_velocity = clampf(
		heading_error * facing_response_rate,
		-turn_speed_limit,
		turn_speed_limit
	)
	var velocity_error := target_angular_velocity - angular_velocity
	var requested_torque := velocity_error * spin_response_gain
	diagnostic_spin_torque = clampf(requested_torque, -spin_torque, spin_torque)
	apply_torque(diagnostic_spin_torque)


func _apply_rotation_lock_torque() -> void:
	diagnostic_rotation_lock_torque = 0.0
	if not rotation_lock_active:
		return
	var lock_error := wrapf(rotation_lock_anchor - global_rotation, -PI, PI)
	var requested_torque := (
		lock_error * rotation_lock_stiffness
		- angular_velocity * rotation_lock_damping
	)
	diagnostic_rotation_lock_torque = clampf(
		requested_torque,
		-maximum_rotation_lock_torque,
		maximum_rotation_lock_torque
	)
	apply_torque(diagnostic_rotation_lock_torque)


func _update_unwrapped_rotation() -> void:
	var wrapped_rotation := global_rotation
	_unwrapped_rotation += wrapf(
		wrapped_rotation - _previous_wrapped_rotation,
		-PI,
		PI
	)
	_previous_wrapped_rotation = wrapped_rotation


func _update_effective_inertia() -> void:
	var average_radius_squared := (
		get_hand_local_position(-1).length_squared()
		+ get_hand_local_position(1).length_squared()
	) * 0.5
	var arm_inertia := arm_inertia_scale * average_radius_squared
	inertia = maxf(1.0, base_effective_inertia + arm_inertia * effective_inertia_influence)


func _draw() -> void:
	for side in HAND_SIDES:
		var shoulder := get_shoulder_local_position(side)
		var elbow := get_elbow_local_position(side)
		var hand := get_hand_local_position(side)
		draw_line(shoulder, elbow, body_color, 8.0, true)
		draw_line(elbow, hand, body_color, 8.0, true)
		draw_circle(elbow, get_elbow_joint_radius(side), body_color)
		draw_circle(hand, HAND_RADIUS, body_color)
	_draw_simple_body()


func _draw_simple_body() -> void:
	if body_style == 1:
		_draw_woman_body()
	else:
		_draw_man_body()


func _draw_man_body() -> void:
	var torso := PackedVector2Array([
		Vector2(-21.0, -3.0),
		Vector2(21.0, -3.0),
		Vector2(16.0, 31.0),
		Vector2(-16.0, 31.0),
	])
	draw_colored_polygon(torso, body_color)
	draw_polyline(
		PackedVector2Array([
			Vector2(-21.0, -3.0),
			Vector2(21.0, -3.0),
			Vector2(16.0, 31.0),
			Vector2(-16.0, 31.0),
			Vector2(-21.0, -3.0),
		]),
		detail_color,
		2.0,
		true
	)

	# A pale shirt opening and narrow tie read as formalwear from directly above.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -3.0),
		Vector2(8.0, -3.0),
		Vector2(0.0, 11.0),
	]), detail_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.4, 1.0),
		Vector2(2.4, 1.0),
		Vector2(1.5, 13.0),
		Vector2(-1.5, 13.0),
	]), body_color)
	draw_line(Vector2(-20.0, -1.0), Vector2(-4.0, 14.0), detail_color, 2.0, true)
	draw_line(Vector2(20.0, -1.0), Vector2(4.0, 14.0), detail_color, 2.0, true)

	var head_center := Vector2(0.0, -22.0)
	draw_circle(head_center, 11.0, body_color)
	draw_arc(head_center, 11.0, 0.0, TAU, 32, detail_color, 2.0, true)
	# Rear hairline and side part establish which end of the silhouette is ahead.
	draw_arc(head_center, 8.0, 0.15, PI - 0.15, 18, detail_color, 3.0, true)
	draw_line(Vector2(-1.0, -29.0), Vector2(4.0, -24.0), detail_color, 1.5, true)


func _draw_woman_body() -> void:
	# Bun and side hair sit behind the head, toward the shoulders.
	draw_circle(Vector2(0.0, -9.0), 7.0, body_color)
	draw_arc(Vector2(0.0, -9.0), 7.0, 0.0, TAU, 24, detail_color, 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17.0, -3.0),
		Vector2(17.0, -3.0),
		Vector2(10.0, 12.0),
		Vector2(27.0, 35.0),
		Vector2(-27.0, 35.0),
		Vector2(-10.0, 12.0),
	]), body_color)
	draw_polyline(
		PackedVector2Array([
			Vector2(-17.0, -3.0),
			Vector2(17.0, -3.0),
			Vector2(10.0, 12.0),
			Vector2(27.0, 35.0),
			Vector2(-27.0, 35.0),
			Vector2(-10.0, 12.0),
			Vector2(-17.0, -3.0),
		]),
		detail_color,
		2.0,
		true
	)
	draw_arc(Vector2.ZERO, 9.0, 0.15, PI - 0.15, 18, detail_color, 2.0, true)
	draw_line(Vector2(-10.0, 12.0), Vector2(10.0, 12.0), detail_color, 2.0, true)
	draw_line(Vector2(0.0, 13.0), Vector2(0.0, 32.0), detail_color, 1.5, true)

	var head_center := Vector2(0.0, -22.0)
	draw_circle(head_center, 11.0, body_color)
	draw_arc(head_center, 11.0, 0.0, TAU, 32, detail_color, 2.0, true)
	# The dark rear crescent makes the hair readable without turning the view frontal.
	draw_arc(head_center, 8.5, 0.1, PI - 0.1, 18, detail_color, 4.0, true)

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
@export var facing_response_rate := 40.0
@export var minimum_target_angular_velocity := 8.0
@export var maximum_target_angular_velocity := 12.0
@export var spin_angular_damping := 0.7
@export_range(0.0, 1.0, 0.05) var facing_dial_engage_threshold := 0.55
@export_range(0.0, 1.0, 0.05) var facing_dial_release_threshold := 0.25
@export_range(1.0, 45.0, 1.0) var facing_dial_max_lag_degrees := 20.0
@export var facing_dial_acceleration := 80.0
@export var facing_dial_braking := 240.0

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
@export_range(0.0, 180.0, 1.0) var maximum_elbow_flexion_degrees := 145.0
@export_range(0.0, 90.0, 1.0) var minimum_forearm_out_of_plane_degrees := 0.0
@export_range(0.0, 90.0, 1.0) var maximum_forearm_out_of_plane_degrees := 80.0
@export var base_effective_inertia := 320.0
@export var arm_inertia_scale := 0.015
@export var effective_inertia_influence := 1.0

@export_category("Extended Arm Stance")
@export_range(5.0, 55.0, 1.0) var extended_elbow_flexion_degrees := 12.0
@export var minimum_extended_elbow_flexion_degrees := 5.0
@export var maximum_extended_elbow_flexion_degrees := 55.0
@export_range(-25.0, 45.0, 1.0) var extended_forward_sweep_degrees := 25.0
@export var minimum_extended_forward_sweep_degrees := -25.0
@export var maximum_extended_forward_sweep_degrees := 45.0
@export var arm_stance_adjustment_rate_degrees := 40.0

var movement_input := Vector2.ZERO
var facing_input := Vector2.ZERO
var desired_facing_direction := Vector2.DOWN
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
var facing_dial_active := false
var facing_dial_total_rotation := 0.0
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
var _pending_facing_rotation_delta := 0.0
var _facing_dial_velocity := 0.0

const HAND_RADIUS := 9.0
const ELBOW_RADIUS := 5.0
const HAND_SIDES := [-1, 1]
const LOCAL_FORWARD_DIRECTION := Vector2.DOWN
const HEAD_CENTER := Vector2.ZERO
const HEAD_RADIUS := 12.0
const BODY_REAR_Y := -10.0
const BODY_FORWARD_Y := 9.0
const NECK_REAR_Y := -14.0
const NOSE_TIP_Y := 19.0


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = movement_linear_damping
	angular_damp = spin_angular_damping
	_current_arm_lengths[-1] = maximum_arm_length
	_current_arm_lengths[1] = maximum_arm_length
	extended_elbow_flexion_degrees = clampf(
		extended_elbow_flexion_degrees,
		minimum_extended_elbow_flexion_degrees,
		maximum_extended_elbow_flexion_degrees
	)
	extended_forward_sweep_degrees = clampf(
		extended_forward_sweep_degrees,
		minimum_extended_forward_sweep_degrees,
		maximum_extended_forward_sweep_degrees
	)
	desired_facing_direction = LOCAL_FORWARD_DIRECTION.rotated(global_rotation)
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
	_apply_facing_torque(delta)
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
	_update_facing_dial_input(new_facing_input.limit_length(1.0))
	left_trigger_value = clampf(new_left_trigger_value, 0.0, 1.0)
	right_trigger_value = clampf(new_right_trigger_value, 0.0, 1.0)


func _update_facing_dial_input(new_input: Vector2) -> void:
	var magnitude := new_input.length()
	var release_threshold := minf(facing_dial_release_threshold, facing_dial_engage_threshold)
	if rotation_lock_active or magnitude <= release_threshold:
		_release_facing_dial()
		return
	if not facing_dial_active:
		if magnitude < facing_dial_engage_threshold:
			return
		facing_dial_active = true
		_previous_facing_input_angle = new_input.angle()
		facing_dial_total_rotation = 0.0
		_pending_facing_rotation_delta = 0.0
		_facing_dial_velocity = 0.0
	facing_input = new_input
	desired_facing_direction = new_input.normalized()
	var sweep := wrapf(new_input.angle() - _previous_facing_input_angle, -PI, PI)
	_previous_facing_input_angle = new_input.angle()
	# A reversal starts a new request instead of paying off the old direction.
	if sweep * _pending_facing_rotation_delta < 0.0 and absf(sweep) > 0.0001:
		_pending_facing_rotation_delta = 0.0
	var lag_limit := deg_to_rad(maxf(facing_dial_max_lag_degrees, 0.0))
	_pending_facing_rotation_delta = clampf(
		_pending_facing_rotation_delta + sweep, -lag_limit, lag_limit
	)
	heading_error = _pending_facing_rotation_delta
	_desired_facing_rotation = _unwrapped_rotation + heading_error


func _release_facing_dial() -> void:
	facing_dial_active = false
	facing_input = Vector2.ZERO
	_pending_facing_rotation_delta = 0.0
	_facing_dial_velocity = 0.0
	target_angular_velocity = 0.0
	heading_error = 0.0
	_desired_facing_rotation = _unwrapped_rotation


func set_runtime_tuning(
	new_spin_speed_scale: float,
	new_move_speed_scale: float,
	new_spin_move_ratio: float
) -> void:
	spin_speed_scale = maxf(new_spin_speed_scale, 0.0)
	move_speed_scale = maxf(new_move_speed_scale, 0.0)
	spin_move_ratio = maxf(new_spin_move_ratio, 0.0)


func adjust_extended_arm_pose(
	spread_input: float,
	forward_input: float,
	delta: float
) -> void:
	var step := arm_stance_adjustment_rate_degrees * maxf(delta, 0.0)
	extended_elbow_flexion_degrees = clampf(
		extended_elbow_flexion_degrees - clampf(spread_input, -1.0, 1.0) * step,
		minimum_extended_elbow_flexion_degrees,
		maximum_extended_elbow_flexion_degrees
	)
	extended_forward_sweep_degrees = clampf(
		extended_forward_sweep_degrees + clampf(forward_input, -1.0, 1.0) * step,
		minimum_extended_forward_sweep_degrees,
		maximum_extended_forward_sweep_degrees
	)
	queue_redraw()


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
		extended_elbow_flexion_degrees,
		maximum_elbow_flexion_degrees,
		get_arm_flexion(side)
	)


func get_arm_forward_sweep_degrees(side: int = 1) -> float:
	return extended_forward_sweep_degrees * (1.0 - get_arm_flexion(side))


func get_upper_arm_local_direction(side: int = 1) -> Vector2:
	var side_sign := float(signi(side))
	var outward := Vector2.RIGHT * side_sign
	return outward.rotated(
		deg_to_rad(get_arm_forward_sweep_degrees(side)) * side_sign
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
	# Both overhead silhouettes face from the torso through the nose, so their
	# anatomical back is up in body-local space.
	return Vector2.UP


func get_elbow_local_position(side: int = 1) -> Vector2:
	# Abduction happens outside the top-down viewing plane. Keep the humerus
	# within a bounded player-selected stance and communicate its out-of-plane
	# motion through projected length.
	return (
		get_shoulder_local_position(side)
		+ get_upper_arm_local_direction(side) * get_projected_upper_arm_length(side)
	)


func get_forearm_local_direction(side: int = 1) -> Vector2:
	# Preserve the approved mirrored elbow bend while the corrected face and RS
	# axis move to the opposite side of the unchanged arm frame.
	var side_sign := float(signi(side))
	return get_upper_arm_local_direction(side).rotated(
		deg_to_rad(get_elbow_flexion_degrees(side)) * side_sign
	)


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


func _apply_facing_torque(delta: float = 1.0 / 120.0) -> void:
	diagnostic_spin_torque = 0.0
	if rotation_lock_active or not facing_dial_active:
		_release_facing_dial()
		return
	if delta <= 0.0:
		return
	var turn_speed_limit := maxf(get_turn_speed_limit(), 0.0)
	var braking := maxf(facing_dial_braking, 0.001)
	var remaining := absf(_pending_facing_rotation_delta)
	var desired_speed := signf(_pending_facing_rotation_delta) * minf(
		turn_speed_limit,
		minf(remaining * maxf(facing_response_rate, 0.0), sqrt(2.0 * braking * remaining))
	)
	var slowing := _facing_dial_velocity * desired_speed < 0.0 \
		or absf(desired_speed) < absf(_facing_dial_velocity)
	_facing_dial_velocity = move_toward(
		_facing_dial_velocity, desired_speed,
		(braking if slowing else maxf(facing_dial_acceleration, 0.0)) * delta
	)
	var applied_step := _facing_dial_velocity * delta
	# Land exactly on small adjustments; never coast past a finished request.
	if remaining <= 0.000001 or (
		applied_step * _pending_facing_rotation_delta > 0.0
		and absf(applied_step) >= remaining
	):
		applied_step = _pending_facing_rotation_delta
		_facing_dial_velocity = 0.0
	var lag_limit := deg_to_rad(maxf(facing_dial_max_lag_degrees, 0.0))
	_pending_facing_rotation_delta = clampf(
		_pending_facing_rotation_delta - applied_step, -lag_limit, lag_limit
	)
	# Controlled RS motion is additive. Handhold/collision angular velocity is
	# left intact, including when the clutch releases; no orientation hold.
	global_rotation += applied_step
	_unwrapped_rotation += applied_step
	_previous_wrapped_rotation = global_rotation
	facing_dial_total_rotation += applied_step
	target_angular_velocity = applied_step / delta
	heading_error = _pending_facing_rotation_delta
	_desired_facing_rotation = _unwrapped_rotation + heading_error


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
	# An upright torso projects almost entirely beneath the head. Only the neck,
	# angular shoulders, and jacket edges escape the head's footprint.
	var torso := PackedVector2Array([
		Vector2(-6.0, NECK_REAR_Y),
		Vector2(6.0, NECK_REAR_Y),
		Vector2(9.0, BODY_REAR_Y),
		Vector2(20.0, -8.0),
		Vector2(25.0, -3.0),
		Vector2(22.0, 6.0),
		Vector2(12.0, BODY_FORWARD_Y),
		Vector2(-12.0, BODY_FORWARD_Y),
		Vector2(-22.0, 6.0),
		Vector2(-25.0, -3.0),
		Vector2(-20.0, -8.0),
		Vector2(-9.0, BODY_REAR_Y),
	])
	draw_colored_polygon(torso, body_color)
	var torso_outline := torso.duplicate()
	torso_outline.append(torso[0])
	draw_polyline(
		torso_outline,
		detail_color,
		2.0,
		true
	)

	# Small lapel points remain visible beside the head without turning the body
	# into a frontal chest drawing.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19.0, -6.0),
		Vector2(-9.0, -8.0),
		Vector2(-12.0, 5.0),
	]), detail_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(19.0, -6.0),
		Vector2(9.0, -8.0),
		Vector2(12.0, 5.0),
	]), detail_color)
	_draw_overhead_head(false)


func _draw_woman_body() -> void:
	# Three shallow rear ruffles add a small dress flourish without turning the
	# upright dancer back into a floor-length silhouette.
	for ruffle_center in [
		Vector2(-15.0, -10.0),
		Vector2(0.0, -11.0),
		Vector2(15.0, -10.0),
	]:
		draw_circle(ruffle_center, 5.5, body_color)
		draw_arc(ruffle_center, 5.5, PI, TAU, 12, detail_color, 1.5, true)

	# Long hair drapes over the shoulders instead of extending like a body lying
	# on the floor. The head will occlude its central portion.
	var hair := PackedVector2Array([
		Vector2(-7.0, NECK_REAR_Y),
		Vector2(7.0, NECK_REAR_Y),
		Vector2(18.0, -9.0),
		Vector2(21.0, 3.0),
		Vector2(16.0, BODY_FORWARD_Y),
		Vector2(9.0, 5.0),
		Vector2(-9.0, 5.0),
		Vector2(-16.0, BODY_FORWARD_Y),
		Vector2(-21.0, 3.0),
		Vector2(-18.0, -9.0),
	])
	draw_colored_polygon(hair, detail_color)

	# The dress is a rounded shoulder-and-bodice footprint no longer than the
	# head. Two small front lobes suggest the bosom from above.
	var dress := PackedVector2Array([
		Vector2(-8.0, BODY_REAR_Y),
		Vector2(8.0, BODY_REAR_Y),
		Vector2(19.0, -7.0),
		Vector2(24.0, -2.0),
		Vector2(23.0, 5.0),
		Vector2(16.0, BODY_FORWARD_Y),
		Vector2(-16.0, BODY_FORWARD_Y),
		Vector2(-23.0, 5.0),
		Vector2(-24.0, -2.0),
		Vector2(-19.0, -7.0),
	])
	draw_colored_polygon(dress, body_color)
	var dress_outline := dress.duplicate()
	dress_outline.append(dress[0])
	draw_polyline(
		dress_outline,
		detail_color,
		2.0,
		true
	)
	draw_circle(Vector2(-8.0, 6.0), 6.0, body_color)
	draw_circle(Vector2(8.0, 6.0), 6.0, body_color)
	draw_arc(Vector2(-8.0, 6.0), 6.0, 0.1, PI - 0.1, 12, detail_color, 1.5, true)
	draw_arc(Vector2(8.0, 6.0), 6.0, 0.1, PI - 0.1, 12, detail_color, 1.5, true)
	_draw_overhead_head(true)


func _draw_overhead_head(has_long_hair: bool) -> void:
	var nose := PackedVector2Array([
		Vector2(-3.2, 10.0),
		Vector2(3.2, 10.0),
		Vector2(0.0, NOSE_TIP_Y),
	])
	draw_colored_polygon(nose, body_color)
	draw_circle(HEAD_CENTER, HEAD_RADIUS, body_color)
	draw_arc(HEAD_CENTER, HEAD_RADIUS, 0.0, TAU, 32, detail_color, 2.0, true)
	draw_line(nose[0], nose[2], detail_color, 1.5, true)
	draw_line(nose[2], nose[1], detail_color, 1.5, true)
	if has_long_hair:
		# A filled rear cap and side locks read as actual hair rather than a thin
		# outline around a bald crown.
		var hair_cap := PackedVector2Array()
		for point_index in 21:
			var angle := lerpf(
				PI + 0.08,
				TAU - 0.08,
				float(point_index) / 20.0
			)
			hair_cap.append(HEAD_CENTER + Vector2.from_angle(angle) * 9.5)
		draw_colored_polygon(hair_cap, detail_color)
		draw_circle(Vector2(-9.5, -2.0), 3.0, detail_color)
		draw_circle(Vector2(9.5, -2.0), 3.0, detail_color)

class_name Dancer
extends RigidBody2D

@export_category("Identity")
@export var dancer_name := "Dancer"
@export var body_color := Color("111111")
@export var detail_color := Color("f2f2f2")
@export var flip_body_symbol := false

@export_category("Movement")
@export var movement_force := 900.0
@export var movement_linear_damping := 2.2
@export var maximum_input_speed := 360.0

@export_category("Rotation")
@export var spin_torque := 15000.0
@export var spin_response_gain := 9000.0
@export var minimum_target_angular_velocity := 2.2
@export var maximum_target_angular_velocity := 5.0
@export var spin_angular_damping := 0.7
@export_enum("Clockwise:1", "Counterclockwise:-1") var intended_spin_direction := 1

@export_category("Arm")
@export var minimum_arm_length := 48.0
@export var maximum_arm_length := 118.0
@export var arm_interpolation_speed := 180.0
@export var hand_line_offset := 0.0
@export var shoulder_half_width := 17.0
@export var upper_arm_length := 52.0
@export var forearm_length := 52.0
@export_range(0.0, 90.0, 1.0) var minimum_abduction_degrees := 30.0
@export_range(0.0, 90.0, 1.0) var maximum_abduction_degrees := 84.0
@export var base_effective_inertia := 320.0
@export var arm_inertia_scale := 0.015
@export var effective_inertia_influence := 1.0

var movement_input := Vector2.ZERO
var trigger_value := 0.0
var current_arm_length := 118.0
var target_angular_velocity := 2.2

const HAND_RADIUS := 9.0


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = movement_linear_damping
	angular_damp = spin_angular_damping
	current_arm_length = maximum_arm_length
	_update_effective_inertia()
	queue_redraw()


func _physics_process(delta: float) -> void:
	current_arm_length = move_toward(
		current_arm_length,
		lerp(maximum_arm_length, minimum_arm_length, trigger_value),
		arm_interpolation_speed * delta
	)
	_update_effective_inertia()
	_apply_movement_force()
	_apply_spin_torque()
	queue_redraw()


func set_control_input(new_movement_input: Vector2, new_trigger_value: float) -> void:
	movement_input = new_movement_input.limit_length(1.0)
	trigger_value = clampf(new_trigger_value, 0.0, 1.0)


func reverse_spin() -> void:
	intended_spin_direction *= -1


func get_hand_world_position(side: int = 1) -> Vector2:
	return global_position + get_hand_offset(side)


func get_hand_offset(side: int = 1) -> Vector2:
	return get_hand_local_position(side).rotated(global_rotation)


func get_hand_velocity(side: int = 1) -> Vector2:
	var offset := get_hand_offset(side)
	return linear_velocity + Vector2(-offset.y, offset.x) * angular_velocity


func get_hand_local_position(side: int = 1) -> Vector2:
	return Vector2(current_arm_length * signi(side), hand_line_offset)


func get_shoulder_local_position(side: int = 1) -> Vector2:
	return Vector2(shoulder_half_width * signi(side), hand_line_offset)


func get_abduction_degrees() -> float:
	var flexion := inverse_lerp(maximum_arm_length, minimum_arm_length, current_arm_length)
	return lerpf(maximum_abduction_degrees, minimum_abduction_degrees, flexion)


func get_projected_upper_arm_length() -> float:
	return upper_arm_length * sin(deg_to_rad(get_abduction_degrees()))


func get_dorsal_local_direction() -> Vector2:
	# Both pictograms face toward their heads at the top of the body, so their
	# anatomical back is down in body-local space.
	return Vector2.DOWN


func get_elbow_local_position(side: int = 1) -> Vector2:
	var shoulder := get_shoulder_local_position(side)
	var hand := get_hand_local_position(side)
	var projected_upper_arm_length := get_projected_upper_arm_length()
	var shoulder_to_hand := hand - shoulder
	var distance := shoulder_to_hand.length()
	if distance <= 0.001:
		return shoulder + Vector2.UP * projected_upper_arm_length

	var direction := shoulder_to_hand / distance
	var reachable_distance := clampf(
		distance,
		absf(projected_upper_arm_length - forearm_length) + 0.001,
		projected_upper_arm_length + forearm_length - 0.001
	)
	var along_distance := (
		projected_upper_arm_length * projected_upper_arm_length
		- forearm_length * forearm_length
		+ reachable_distance * reachable_distance
	) / (2.0 * reachable_distance)
	var perpendicular_distance := sqrt(maxf(
		projected_upper_arm_length * projected_upper_arm_length - along_distance * along_distance,
		0.0
	))
	# Of the two valid IK solutions, choose the one toward the dancer's back.
	# This keeps both elbows anatomically dorsal instead of choosing by screen
	# chirality and accidentally creating a pinwheel-like pose.
	var tangent := Vector2(-direction.y, direction.x)
	if tangent.dot(get_dorsal_local_direction()) < 0.0:
		tangent = -tangent
	return shoulder + direction * along_distance + tangent * perpendicular_distance


func _apply_movement_force() -> void:
	if movement_input.is_zero_approx():
		return
	var force_scale := 1.0
	if maximum_input_speed > 0.0:
		var along_input := linear_velocity.dot(movement_input.normalized())
		if along_input > maximum_input_speed:
			force_scale = 0.0
	apply_central_force(movement_input * movement_force * force_scale)


func _apply_spin_torque() -> void:
	var tuck := inverse_lerp(maximum_arm_length, minimum_arm_length, current_arm_length)
	var target_speed := lerpf(minimum_target_angular_velocity, maximum_target_angular_velocity, tuck)
	target_angular_velocity = target_speed * float(intended_spin_direction)
	var velocity_error := target_angular_velocity - angular_velocity
	var requested_torque := velocity_error * spin_response_gain
	apply_torque(clampf(requested_torque, -spin_torque, spin_torque))


func _update_effective_inertia() -> void:
	var effective_radius_squared := (
		current_arm_length * current_arm_length
		+ hand_line_offset * hand_line_offset
	)
	var arm_inertia := arm_inertia_scale * effective_radius_squared
	inertia = maxf(1.0, base_effective_inertia + arm_inertia * effective_inertia_influence)


func _draw() -> void:
	for side in [-1, 1]:
		var shoulder := get_shoulder_local_position(side)
		var elbow := get_elbow_local_position(side)
		var hand := get_hand_local_position(side)
		draw_line(shoulder, elbow, body_color, 8.0, true)
		draw_line(elbow, hand, body_color, 8.0, true)
		draw_circle(elbow, 5.0, body_color)
		draw_circle(hand, HAND_RADIUS, body_color)
	_draw_simple_body()


func _draw_simple_body() -> void:
	var vertical_direction := -1.0 if flip_body_symbol else 1.0
	var base_y := -7.0 * vertical_direction
	var point_y := 27.0 * vertical_direction
	var torso := PackedVector2Array([
		Vector2(-23.0, base_y),
		Vector2(23.0, base_y),
		Vector2(0.0, point_y)
	])
	draw_colored_polygon(torso, body_color)

	var head_center := Vector2(0.0, base_y - 10.0)
	if flip_body_symbol:
		# The white dancer follows the restroom-pictogram arrangement: the head
		# touches the pointed corner rather than the flat edge.
		head_center = Vector2(0.0, point_y - 10.0)
	draw_circle(head_center, 10.0, body_color)
	_draw_yin_yang_half(Vector2(0.0, 3.0 * vertical_direction), 9.5)


func _draw_yin_yang_half(center: Vector2, radius: float) -> void:
	# Only the opposite-color half is drawn. The triangle itself supplies the
	# invisible complementary half, while this lobe keeps the classic S curl.
	var visible_half := PackedVector2Array([center])
	var start_angle := -PI * 0.5 if intended_spin_direction > 0 else PI * 0.5
	var end_angle := PI * 0.5 if intended_spin_direction > 0 else PI * 1.5
	for point_index in 25:
		var angle := lerpf(start_angle, end_angle, float(point_index) / 24.0)
		visible_half.append(center + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(visible_half, detail_color)

	var lobe_radius := radius * 0.5
	var upper_lobe := center + Vector2.UP * lobe_radius
	var lower_lobe := center + Vector2.DOWN * lobe_radius
	draw_circle(upper_lobe, lobe_radius, detail_color)
	draw_circle(lower_lobe, lobe_radius, body_color)

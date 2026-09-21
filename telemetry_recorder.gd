class_name TelemetryRecorder
extends Node

signal capture_saved(path: String, reason: String)
signal capture_failed(message: String)

@export_category("Capture")
@export var capture_duration_seconds := 12.0
@export var sample_rate_hz := 60.0
@export_dir var capture_directory := "res://diagnostics"

@export_category("Sources")
@export var left_dancer: Dancer
@export var right_dancer: Dancer
@export var hand_connection: HandConnection
@export var controller: PrototypeController

var last_capture_path := ""
var last_capture_reason := ""

var _samples: Array[Dictionary] = []
var _sample_accumulator := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000


func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree != null and tree.paused:
		return
	var interval := 1.0 / maxf(sample_rate_hz, 1.0)
	_sample_accumulator += maxf(delta, 0.0)
	var samples_this_frame := 0
	while _sample_accumulator >= interval and samples_this_frame < 4:
		_sample_accumulator -= interval
		record_current_sample()
		samples_this_frame += 1


func record_current_sample() -> void:
	if (
		not is_instance_valid(left_dancer)
		or not is_instance_valid(right_dancer)
		or not is_instance_valid(hand_connection)
	):
		return
	append_sample(_build_current_sample())


func append_sample(sample: Dictionary) -> void:
	_samples.append(sample)
	var maximum_samples := get_max_samples()
	while _samples.size() > maximum_samples:
		_samples.pop_front()


func clear() -> void:
	_samples.clear()
	_sample_accumulator = 0.0


func get_sample_count() -> int:
	return _samples.size()


func get_max_samples() -> int:
	return maxi(1, ceili(maxf(capture_duration_seconds, 0.1) * maxf(sample_rate_hz, 1.0)))


func get_samples() -> Array[Dictionary]:
	return _samples.duplicate(true)


func save_capture(reason: String = "manual") -> String:
	record_current_sample()
	if capture_directory.is_empty():
		capture_failed.emit("Telemetry capture directory is empty.")
		return ""

	var absolute_directory := ProjectSettings.globalize_path(capture_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		var directory_message := "Could not create telemetry directory (%d): %s" % [
			directory_error,
			absolute_directory,
		]
		capture_failed.emit(directory_message)
		return ""

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var frame := Engine.get_physics_frames()
	var filename := "dancers-telemetry-%s-f%d.json" % [timestamp, frame]
	var absolute_path := absolute_directory.path_join(filename)
	var collision_index := 1
	while FileAccess.file_exists(absolute_path):
		filename = "dancers-telemetry-%s-f%d-%02d.json" % [
			timestamp,
			frame,
			collision_index,
		]
		absolute_path = absolute_directory.path_join(filename)
		collision_index += 1

	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		var file_message := "Could not write telemetry capture: %s" % absolute_path
		capture_failed.emit(file_message)
		return ""
	file.store_string(JSON.stringify(build_capture_payload(reason), "\t"))
	file.close()

	last_capture_path = absolute_path
	last_capture_reason = reason
	capture_saved.emit(last_capture_path, reason)
	return last_capture_path


func build_capture_payload(reason: String = "manual") -> Dictionary:
	return {
		"schema": "dancers-coop-telemetry-v11",
		"reason": reason,
		"captured_at": Time.get_datetime_string_from_system(),
		"captured_at_utc": Time.get_datetime_string_from_system(true),
		"capture_duration_seconds": capture_duration_seconds,
		"sample_rate_hz": sample_rate_hz,
		"sample_count": _samples.size(),
		"recorded_span_seconds": _calculate_recorded_span_seconds(),
		"engine": Engine.get_version_info(),
		"project": {
			"name": ProjectSettings.get_setting("application/config/name", "Dancers"),
			"physics_ticks_per_second": ProjectSettings.get_setting(
				"physics/common/physics_ticks_per_second",
				60
			),
		},
		"configuration": _build_configuration(),
		"samples": get_samples(),
	}


func _build_current_sample() -> Dictionary:
	var separation := right_dancer.global_position - left_dancer.global_position
	var relative_velocity := right_dancer.linear_velocity - left_dancer.linear_velocity
	return {
		"ticks_msec": Time.get_ticks_msec(),
		"physics_frame": Engine.get_physics_frames(),
		"left_dancer": _build_dancer_sample(left_dancer),
		"right_dancer": _build_dancer_sample(right_dancer),
		"pair": {
			"body_separation": _vector2_for_json(separation),
			"body_distance": _float_for_json(separation.length()),
			"relative_body_velocity": _vector2_for_json(relative_velocity),
			"relative_body_speed": _float_for_json(relative_velocity.length()),
			"midpoint": _vector2_for_json(
				(left_dancer.global_position + right_dancer.global_position) * 0.5
			),
		},
		"hand_connection": _build_connection_sample(),
	}


func _build_dancer_sample(dancer: Dancer) -> Dictionary:
	return {
		"position": _vector2_for_json(dancer.global_position),
		"rotation_radians": _float_for_json(dancer.global_rotation),
		"rotation_degrees": _float_for_json(rad_to_deg(dancer.global_rotation)),
		"linear_velocity": _vector2_for_json(dancer.linear_velocity),
		"speed": _float_for_json(dancer.linear_velocity.length()),
		"angular_velocity": _float_for_json(dancer.angular_velocity),
		"target_angular_velocity": _float_for_json(dancer.target_angular_velocity),
		"heading_error": _float_for_json(dancer.heading_error),
		"weight_kg": dancer.weight_kg,
		"fit_weight_kg": dancer.fit_weight_kg,
		"visual_weight_gain_kg": dancer.get_visual_weight_gain_kg(),
		"facing_dial": {
			"active": dancer.facing_dial_active,
			"applied_rotation_radians": _float_for_json(dancer.facing_dial_total_rotation),
			"response_scale": _float_for_json(dancer.facing_dial_response_scale),
		},
		"desired_facing_direction": _vector2_for_json(dancer.desired_facing_direction),
		"input": {
			"movement": _vector2_for_json(dancer.movement_input),
			"facing": _vector2_for_json(dancer.facing_input),
			"left_trigger": _float_for_json(dancer.left_trigger_value),
			"right_trigger": _float_for_json(dancer.right_trigger_value),
			"position_lock": dancer.position_lock_active,
			"rotation_lock": dancer.rotation_lock_active,
		},
		"applied": {
			"movement_force": _vector2_for_json(dancer.diagnostic_movement_force),
			"turn_torque": _float_for_json(dancer.diagnostic_spin_torque),
			"position_lock_force": _vector2_for_json(
				dancer.diagnostic_position_lock_force
			),
			"rotation_lock_torque": _float_for_json(
				dancer.diagnostic_rotation_lock_torque
			),
		},
		"arms": {
			"left": _build_arm_sample(dancer, -1),
			"right": _build_arm_sample(dancer, 1),
			"extended_stance": {
				"elbow_flexion_degrees": _float_for_json(
					dancer.extended_elbow_flexion_degrees
				),
				"forward_sweep_degrees": _float_for_json(
					dancer.extended_forward_sweep_degrees
				),
			},
			"average_flexion_ratio": _float_for_json(
				dancer.get_average_arm_flexion()
			),
			"effective_inertia": _float_for_json(dancer.inertia),
		},
		"hands": {
			"left": _build_hand_sample(dancer, -1),
			"right": _build_hand_sample(dancer, 1),
		},
	}


func _build_arm_sample(dancer: Dancer, side: int) -> Dictionary:
	return {
		"trigger": _float_for_json(dancer.get_trigger_value(side)),
		"request_mismatch": _float_for_json(dancer.get_double_hold_request_mismatch(side)),
		"hand_roll_radians": _float_for_json(dancer.get_hand_roll_radians(side)),
		"double_hold_effort": _float_for_json(
			dancer.get_double_hold_arm_effort(side)
		),
		"current_length": _float_for_json(dancer.get_current_arm_length(side)),
		"flexion_ratio": _float_for_json(dancer.get_arm_flexion(side)),
		"projected_upper_arm_length": _float_for_json(
			dancer.get_projected_upper_arm_length(side)
		),
		"projected_forearm_length": _float_for_json(
			dancer.get_projected_forearm_length(side)
		),
		"abduction_degrees": _float_for_json(dancer.get_abduction_degrees(side)),
		"elbow_flexion_degrees": _float_for_json(
			dancer.get_elbow_flexion_degrees(side)
		),
		"forearm_out_of_plane_degrees": _float_for_json(
			dancer.get_forearm_out_of_plane_degrees(side)
		),
	}


func _build_hand_sample(dancer: Dancer, side: int) -> Dictionary:
	var velocity := dancer.get_hand_velocity(side)
	return {
		"world_position": _vector2_for_json(dancer.get_hand_world_position(side)),
		"velocity": _vector2_for_json(velocity),
		"speed": _float_for_json(velocity.length()),
		"button_down": hand_connection.is_grip_button_down(dancer, side),
		"primed": hand_connection.is_hand_primed(dancer, side),
		"release_tap_armed": hand_connection.is_release_tap_armed(dancer, side),
	}


func _build_connection_sample() -> Dictionary:
	var connected_sides := hand_connection.get_connected_hand_sides()
	var secondary_connected_sides := hand_connection.get_secondary_connected_hand_sides()
	return {
		"connected": hand_connection.is_connected,
		"secondary_connected": hand_connection.is_secondary_connected,
		"connection_count": hand_connection.get_active_connection_count(),
		"hold_mode": hand_connection.get_hold_mode(),
		"solver_mode": hand_connection.get_solver_mode(),
		"left_dancer_hand_side": connected_sides[0],
		"right_dancer_hand_side": connected_sides[1],
		"secondary_left_dancer_hand_side": secondary_connected_sides[0],
		"secondary_right_dancer_hand_side": secondary_connected_sides[1],
		"distance_error": _float_for_json(hand_connection.distance_error),
		"relative_hand_velocity": _float_for_json(
			hand_connection.relative_hand_velocity
		),
		"primary_acquisition_progress": _float_for_json(
			hand_connection.primary_acquisition_progress
		),
		"secondary_acquisition_progress": _float_for_json(
			hand_connection.secondary_acquisition_progress
		),
		"primary_hand_separation": _float_for_json(
			hand_connection.primary_hand_separation
		),
		"secondary_hand_separation": _float_for_json(
			hand_connection.secondary_hand_separation
		),
		"primary_allowed_separation": _float_for_json(
			hand_connection.primary_allowed_separation
		),
		"secondary_allowed_separation": _float_for_json(
			hand_connection.secondary_allowed_separation
		),
		"primary_position_correction": _float_for_json(
			hand_connection.primary_position_correction
		),
		"secondary_position_correction": _float_for_json(
			hand_connection.secondary_position_correction
		),
		"primary_velocity_correction": _float_for_json(
			hand_connection.primary_velocity_correction
		),
		"secondary_velocity_correction": _float_for_json(
			hand_connection.secondary_velocity_correction
		),
		"double_hold_orbital_angular_velocity": _float_for_json(
			hand_connection.double_hold_orbital_angular_velocity
		),
		"double_hold_alignment_error": _float_for_json(
			hand_connection.double_hold_alignment_error
		),
		"double_hold_primary_permission": _float_for_json(
			hand_connection.double_hold_primary_permission
		),
		"double_hold_secondary_permission": _float_for_json(
			hand_connection.double_hold_secondary_permission
		),
		"double_hold_maximum_effort": _float_for_json(
			hand_connection.double_hold_maximum_effort
		),
		"double_hold_pose_limited": hand_connection.double_hold_pose_limited,
		"separation_limit_active": hand_connection.separation_limit_active,
		"primary_snap_remaining": _float_for_json(
			hand_connection.primary_snap_remaining
		),
		"secondary_snap_remaining": _float_for_json(
			hand_connection.secondary_snap_remaining
		),
		"catch_cooldown_remaining": _float_for_json(
			hand_connection.get_cooldown_remaining()
		),
		"mutual_body_collision_disabled": (
			hand_connection.is_mutual_body_collision_disabled()
		),
	}


func _build_configuration() -> Dictionary:
	var configuration := {
		"left_dancer": _build_dancer_configuration(left_dancer),
		"right_dancer": _build_dancer_configuration(right_dancer),
		"hand_connection": {
			"catch_radius": hand_connection.catch_radius,
			"maximum_relative_catch_velocity": (
				hand_connection.maximum_relative_catch_velocity
			),
			"release_cooldown": hand_connection.release_cooldown,
			"snap_duration": hand_connection.snap_duration,
			"rigid_position_iterations": hand_connection.rigid_position_iterations,
			"rigid_velocity_iterations": hand_connection.rigid_velocity_iterations,
			"rigid_span_tolerance": hand_connection.rigid_span_tolerance,
			"rigid_span_projection_iterations": (
				hand_connection.rigid_span_projection_iterations
			),
			"solver_mode": hand_connection.get_solver_mode(),
			"double_hold_body_clearance": true,
			"minimum_double_hold_body_distance": hand_connection._get_body_contact_distance(),
		},
	}
	if is_instance_valid(controller):
		configuration["controller"] = {
			"preferred_player_one_device": controller.preferred_player_one_device,
			"preferred_player_two_device": controller.preferred_player_two_device,
			"assigned_player_one_device": controller.get_player_one_device(),
			"assigned_player_two_device": controller.get_player_two_device(),
			"stick_deadzone": controller.stick_deadzone,
			"trigger_sensitivity": controller.trigger_sensitivity,
			"stick_sensitivity": controller.stick_sensitivity,
			"man_weight_kg": controller.man_weight_kg,
			"woman_weight_kg": controller.woman_weight_kg,
			"man_fit_weight_kg": controller.man_fit_weight_kg,
			"woman_fit_weight_kg": controller.woman_fit_weight_kg,
		}
	return configuration


func _build_dancer_configuration(dancer: Dancer) -> Dictionary:
	return {
		"name": dancer.dancer_name,
		"body_style": dancer.body_style,
		"weight_kg": dancer.weight_kg,
		"fit_weight_kg": dancer.fit_weight_kg,
		"visual_weight_step_kg": 5.0,
		"maximum_visual_weight_gain_kg": dancer.MAXIMUM_VISUAL_WEIGHT_GAIN_KG,
		"reference_weight_kg": dancer.REFERENCE_WEIGHT_KG,
		"mass": dancer.mass,
		"movement_force": dancer.movement_force,
		"movement_linear_damping": dancer.movement_linear_damping,
		"maximum_input_speed": dancer.maximum_input_speed,
		"spin_torque": dancer.spin_torque,
		"spin_response_gain": dancer.spin_response_gain,
		"facing_response_rate": dancer.facing_response_rate,
		"facing_mode": "radial_heading_response",
		"facing_dial_engage_threshold": dancer.facing_dial_engage_threshold,
		"facing_dial_release_threshold": dancer.facing_dial_release_threshold,
		"facing_dial_minimum_response": dancer.facing_dial_minimum_response,
		"facing_dial_acceleration": dancer.facing_dial_acceleration,
		"facing_dial_braking": dancer.facing_dial_braking,
		"minimum_target_angular_velocity": dancer.minimum_target_angular_velocity,
		"maximum_target_angular_velocity": dancer.maximum_target_angular_velocity,
		"spin_angular_damping": dancer.spin_angular_damping,
		"position_lock_stiffness": dancer.position_lock_stiffness,
		"position_lock_damping": dancer.position_lock_damping,
		"maximum_position_lock_force": dancer.maximum_position_lock_force,
		"rotation_lock_stiffness": dancer.rotation_lock_stiffness,
		"rotation_lock_damping": dancer.rotation_lock_damping,
		"maximum_rotation_lock_torque": dancer.maximum_rotation_lock_torque,
		"minimum_arm_length": dancer.minimum_arm_length,
		"maximum_arm_length": dancer.maximum_arm_length,
		"arm_interpolation_speed": dancer.arm_interpolation_speed,
		"shoulder_half_width": dancer.shoulder_half_width,
		"upper_arm_length": dancer.upper_arm_length,
		"forearm_length": dancer.forearm_length,
		"minimum_abduction_degrees": dancer.minimum_abduction_degrees,
		"maximum_abduction_degrees": dancer.maximum_abduction_degrees,
		"maximum_elbow_flexion_degrees": dancer.maximum_elbow_flexion_degrees,
		"extended_elbow_flexion_degrees": dancer.extended_elbow_flexion_degrees,
		"minimum_extended_elbow_flexion_degrees": (
			dancer.minimum_extended_elbow_flexion_degrees
		),
		"maximum_extended_elbow_flexion_degrees": (
			dancer.maximum_extended_elbow_flexion_degrees
		),
		"extended_forward_sweep_degrees": dancer.extended_forward_sweep_degrees,
		"minimum_extended_forward_sweep_degrees": (
			dancer.minimum_extended_forward_sweep_degrees
		),
		"maximum_extended_forward_sweep_degrees": (
			dancer.maximum_extended_forward_sweep_degrees
		),
		"arm_stance_adjustment_rate_degrees": (
			dancer.arm_stance_adjustment_rate_degrees
		),
		"minimum_forearm_out_of_plane_degrees": (
			dancer.minimum_forearm_out_of_plane_degrees
		),
		"maximum_forearm_out_of_plane_degrees": (
			dancer.maximum_forearm_out_of_plane_degrees
		),
		"base_effective_inertia": dancer.base_effective_inertia,
		"arm_inertia_scale": dancer.arm_inertia_scale,
		"effective_inertia_influence": dancer.effective_inertia_influence,
	}


func _calculate_recorded_span_seconds() -> float:
	if _samples.size() < 2:
		return 0.0
	var first_ticks := int(_samples.front().get("ticks_msec", 0))
	var last_ticks := int(_samples.back().get("ticks_msec", first_ticks))
	return maxf(0.0, float(last_ticks - first_ticks) / 1000.0)


static func _float_for_json(value: float) -> Variant:
	if is_nan(value):
		return "nan"
	if is_inf(value):
		return "-inf" if value < 0.0 else "inf"
	return value


static func _vector2_for_json(value: Vector2) -> Array:
	return [_float_for_json(value.x), _float_for_json(value.y)]

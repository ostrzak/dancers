class_name DebugOverlay
extends CanvasLayer

@export var start_visible := true
@export var left_dancer: Dancer
@export var right_dancer: Dancer
@export var hand_connection: HandConnection

@onready var left_readout: Label = $LeftReadout
@onready var right_readout: Label = $RightReadout
@onready var connection_readout: Label = $ConnectionReadout


func _ready() -> void:
	visible = start_visible


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(left_dancer) or not is_instance_valid(right_dancer):
		return
	left_readout.text = "%s\n%s" % [left_dancer.dancer_name, _format_dancer(left_dancer)]
	right_readout.text = "%s\n%s" % [right_dancer.dancer_name, _format_dancer(right_dancer)]
	connection_readout.text = "HANDS %s [%s]   primed B:%s/%s W:%s/%s   gap %6.2f px   relative %6.2f px/s   force %7.1f   elastic %3.0f/%3.0f%%   effort %3.0f%%" % [
		hand_connection.get_hold_mode().to_upper(),
		hand_connection.get_solver_mode().to_upper(),
		"L" if hand_connection.is_hand_primed(left_dancer, -1) else "-",
		"R" if hand_connection.is_hand_primed(left_dancer, 1) else "-",
		"L" if hand_connection.is_hand_primed(right_dancer, -1) else "-",
		"R" if hand_connection.is_hand_primed(right_dancer, 1) else "-",
		hand_connection.distance_error,
		hand_connection.relative_hand_velocity,
		hand_connection.connection_force,
		hand_connection.primary_elastic_blend * 100.0,
		hand_connection.secondary_elastic_blend * 100.0,
		hand_connection.double_hold_maximum_effort * 100.0,
	]


func set_telemetry_visible(is_visible: bool) -> void:
	visible = is_visible


func _format_dancer(dancer: Dancer) -> String:
	return "weight       %7.0f kg\nspeed        %7.2f px/s\nangular      %7.2f rad/s\ntarget       %7.2f rad/s\nheading err  %+7.2f deg\nlocks L3/R3  %6s / %6s\narm flex/fwd %6.1f / %+6.1f deg\nmove scale   %7.2fx\ntrigger L/R  %6.2f / %6.2f\neffort L/R   %6.2f / %6.2f\nreach L/R    %6.2f / %6.2f px\nupper L/R    %6.2f / %6.2f px\nfore L/R     %6.2f / %6.2f px\nhand L/R     %6.2f / %6.2f px/s" % [
		dancer.weight_kg,
		dancer.linear_velocity.length(),
		dancer.angular_velocity,
	dancer.target_angular_velocity,
	rad_to_deg(dancer.heading_error),
	"ON" if dancer.position_lock_active else "-",
	"ON" if dancer.rotation_lock_active else "-",
	dancer.extended_elbow_flexion_degrees,
	dancer.extended_forward_sweep_degrees,
	dancer.get_effective_move_scale(),
		dancer.left_trigger_value,
		dancer.right_trigger_value,
		dancer.get_double_hold_arm_effort(-1),
		dancer.get_double_hold_arm_effort(1),
		dancer.get_hand_local_position(-1).length(),
		dancer.get_hand_local_position(1).length(),
		dancer.get_projected_upper_arm_length(-1),
		dancer.get_projected_upper_arm_length(1),
		dancer.get_projected_forearm_length(-1),
		dancer.get_projected_forearm_length(1),
		dancer.get_hand_velocity(-1).length(),
		dancer.get_hand_velocity(1).length(),
	]

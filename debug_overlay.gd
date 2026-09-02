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
	connection_readout.text = "HANDS %s   error %6.2f px   relative %6.2f px/s   force %7.1f" % [
		"CONNECTED" if hand_connection.is_connected else "OPEN",
		hand_connection.distance_error,
		hand_connection.relative_hand_velocity,
		hand_connection.connection_force
	]


func set_telemetry_visible(is_visible: bool) -> void:
	visible = is_visible


func _format_dancer(dancer: Dancer) -> String:
	var direction := "CW (+1)" if dancer.intended_spin_direction > 0 else "CCW (-1)"
	return "speed        %7.2f px/s\nangular      %7.2f rad/s\ntarget       %7.2f rad/s\nspin         %s\nreach        %7.2f px\nupper proj   %5.1f px @ %4.1f deg\nelbow flex   %5.1f deg\ntrigger      %7.2f\nhand L / R   %6.2f / %6.2f px/s\nconnected    %s" % [
		dancer.linear_velocity.length(),
		dancer.angular_velocity,
		dancer.target_angular_velocity,
		direction,
		dancer.get_hand_local_position(1).length(),
		dancer.get_projected_upper_arm_length(),
		dancer.get_abduction_degrees(),
		dancer.get_elbow_flexion_degrees(),
		dancer.trigger_value,
		dancer.get_hand_velocity(-1).length(),
		dancer.get_hand_velocity(1).length(),
		"yes" if hand_connection.is_connected else "no"
	]

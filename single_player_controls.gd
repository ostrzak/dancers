class_name SinglePlayerControls
extends RefCounted

# Index 0 is LB, index 1 is RB. Slots never change when the other hold releases.
var owned_slots: Array[int] = [0, 0]
var _button_down: Array[bool] = [false, false]
var _consumed: Array[bool] = [false, false]


func reset() -> void:
	owned_slots.assign([0, 0])
	_button_down.assign([false, false])
	_consumed.assign([false, false])


func suspend(hold: HandConnection) -> void:
	# Menu presses, disconnects and rejected catches need a fresh gameplay press.
	_consumed.assign([true, true])
	hold.shared_catch_waiting = false


func apply_steering(
	left: Dancer, right: Dancer, left_move: Vector2, right_move: Vector2,
	left_trigger: float, right_trigger: float
) -> void:
	left.set_control_input(left_move, Vector2.ZERO, left_trigger, left_trigger)
	right.set_control_input(right_move, Vector2.ZERO, right_trigger, right_trigger)


func update_hands(hold: HandConnection, lb: bool, rb: bool) -> void:
	hold.shared_catch_waiting = false
	var pressed := [lb, rb]
	for bumper in 2:
		var slot := owned_slots[bumper]
		if (slot == 1 and not hold.is_connected) or (slot == 2 and not hold.is_secondary_connected):
			owned_slots[bumper] = 0
	for bumper in 2:
		var fresh_press: bool = pressed[bumper] and not _button_down[bumper]
		_button_down[bumper] = pressed[bumper]
		if not pressed[bumper]:
			_consumed[bumper] = false
			continue
		if _consumed[bumper]:
			continue
		if owned_slots[bumper] != 0:
			if fresh_press:
				if owned_slots[bumper] == 1:
					hold.release_hands()
				else:
					hold.release_secondary_hands()
				owned_slots[bumper] = 0
				_consumed[bumper] = true
			continue
		# Hold to prime while approaching; one bumper can acquire only one pair.
		var caught_slot := hold.try_connect_shared_pair()
		if caught_slot != 0:
			owned_slots[bumper] = caught_slot
			_consumed[bumper] = true
		else:
			hold.shared_catch_waiting = true

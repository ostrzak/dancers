class_name DanceFigure
extends Resource

@export var title := ""
@export_multiline var description := ""
@export var duration := 6.0
# Each key describes the pair centre, overall turn, and both connected sides'
# contraction. Both ghosts share the same skeleton and opposite-hand pairing.
@export var keys: Array[Dictionary] = []


func sample(seconds: float) -> Dictionary:
	for index in range(1, keys.size()):
		var next: Dictionary = keys[index]
		if seconds <= float(next.time):
			var previous: Dictionary = keys[index - 1]
			var blend := smoothstep(float(previous.time), float(next.time), seconds)
			var arc: Vector2 = previous.get("arc", Vector2.ZERO)
			return {
				"centre": (previous.centre as Vector2).lerp(next.centre, blend) + arc * sin(PI * blend),
				"turn": lerpf(previous.turn, next.turn, blend),
				"flexion": lerpf(previous.flexion, next.flexion, blend),
				"secondary_flexion": lerpf(previous.get("secondary_flexion", 0.0),
					next.get("secondary_flexion", 0.0), blend),
			}
	return keys[-1]

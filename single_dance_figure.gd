class_name SingleDanceFigure
extends DanceFigure

@export_multiline var narration_text := ""
@export var requirement := ""

func get_keys() -> Array[Dictionary]:
	if mirror_of == null:
		return keys
	if not _mirrored_keys.is_empty():
		return _mirrored_keys
	# Reflect the complete choreography across the floor's vertical centreline.
	# Keep dancer identities, but exchange anatomical hands and joined sides.
	for original in mirror_of.get_keys():
		var key: Dictionary = original.duplicate(true)
		for field in ["centre", "release_position"]:
			if key.has(field):
				key[field] = Vector2(1280.0 - key[field].x, key[field].y)
		for field in ["arc", "arc_a", "arc_b", "position_a", "position_b", "release_offset"]:
			if key.has(field):
				key[field] = Vector2(-key[field].x, key[field].y)
		key.turn = -float(original.turn)
		key.double_turn = -float(original.get("double_turn", 0.0))
		key.partner_turn = -float(original.get("partner_turn", PI))
		key.path_turn = -float(original.get("path_turn", 0.0))
		key.hand_side = -int(original.get("hand_side", -1))
		_mirrored_keys.append(key)
	return _mirrored_keys


func get_caption() -> String:
	return title if variant_label.is_empty() else "%s - %s" % [title, variant_label]


func sample(seconds: float) -> Dictionary:
	var timeline := get_keys()
	for index in range(1, timeline.size()):
		var next: Dictionary = timeline[index]
		if seconds <= float(next.time):
			var previous: Dictionary = timeline[index - 1]
			var blend := smoothstep(float(previous.time), float(next.time), seconds)
			var arc: Vector2 = previous.get("arc", Vector2.ZERO)
			return {
				"centre": (previous.centre as Vector2).lerp(next.centre, blend) + arc * sin(PI * blend),
				"turn": lerpf(previous.turn, next.turn, blend),
				"flexion": lerpf(previous.flexion, next.flexion, blend),
				"secondary_flexion": lerpf(previous.get("secondary_flexion", 0.0),
					next.get("secondary_flexion", 0.0), blend),
				"forward_sweep": lerpf(previous.get("forward_sweep", 25.0), next.get("forward_sweep", 25.0), blend),
				"join_progress": lerpf(previous.get("join_progress", 1.0), next.get("join_progress", 1.0), blend),
				"partner_turn": lerpf(previous.get("partner_turn", PI), next.get("partner_turn", PI), blend),
				"partner_flexion": lerpf(previous.get("partner_flexion", 0.0), next.get("partner_flexion", 0.0), blend),
				"partner_free_flexion": lerpf(previous.get("partner_free_flexion", 0.65), next.get("partner_free_flexion", 0.65), blend),
				"free_flexion": lerpf(previous.get("free_flexion", 0.65), next.get("free_flexion", 0.65), blend),
				"hand_side": previous.get("hand_side", -1),
				"double_weight": lerpf(previous.get("double_weight", 0.0), next.get("double_weight", 0.0), blend),
				"anchor_weight": lerpf(previous.get("anchor_weight", 0.5), next.get("anchor_weight", 0.5), blend),
				"double_turn": lerpf(previous.get("double_turn", 0.0), next.get("double_turn", 0.0), blend),
				"release_weight": lerpf(previous.get("release_weight", 0.0), next.get("release_weight", 0.0), blend),
				"release_position": (previous.get("release_position", Vector2.ZERO) as Vector2).lerp(next.get("release_position", Vector2.ZERO), blend),
				"release_offset": (previous.get("release_offset", Vector2.ZERO) as Vector2).lerp(next.get("release_offset", Vector2.ZERO), blend),
				"position_a": (previous.get("position_a", Vector2.ZERO) as Vector2).lerp(next.get("position_a", Vector2.ZERO), blend)
					+ (previous.get("arc_a", Vector2.ZERO) as Vector2) * sin(PI * blend),
				"position_b": (previous.get("position_b", Vector2.ZERO) as Vector2).lerp(next.get("position_b", Vector2.ZERO), blend)
					+ (previous.get("arc_b", Vector2.ZERO) as Vector2) * sin(PI * blend),
				"path_turn": lerpf(previous.get("path_turn", 0.0), next.get("path_turn", 0.0), blend),
			}
	return timeline[-1]

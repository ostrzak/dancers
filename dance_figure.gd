class_name DanceFigure
extends Resource

@export var title := ""
@export var variant_label := ""
@export var mirror_of: DanceFigure
@export_multiline var description := ""
@export var narration: AudioStream
@export var duration := 6.0
@export var joined_from := 0.0
# Nonzero enables an approach from separate, back-to-back starting positions.
@export var separate_body_distance := 0.0
@export var single_hand := false
@export var no_hands := false
# Single-hand figures can keep A's body at centre instead of the pair midpoint.
@export var anchor_first_body := false
# Each key describes the pair centre, overall turn, and both connected sides'
# contraction. Both ghosts share the same skeleton and opposite-hand pairing.
@export var keys: Array[Dictionary] = []

var _mirrored_keys: Array[Dictionary] = []


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
		key.partner_turn = -float(original.get("partner_turn", PI))
		key.path_turn = -float(original.get("path_turn", 0.0))
		key.hand_side = -int(original.get("hand_side", -1))
		if not single_hand and not no_hands:
			key.flexion = original.get("secondary_flexion", 0.0)
			key.secondary_flexion = original.flexion
		_mirrored_keys.append(key)
	return _mirrored_keys


func get_caption() -> String:
	return title if variant_label.is_empty() else "%s · %s" % [title, variant_label]


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

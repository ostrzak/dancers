class_name TitleDance
extends FigureDemonstration

# Title artwork only: reuse the figure demonstrator's dancers and hand geometry.
const APPROACH_TIME := 3.0
const GATHER_TIME := 1.2
const TRAVEL_START := APPROACH_TIME + GATHER_TIME
const SPEED_RAMP := 1.5
const LAP_TIME := 22.0
const PATH_RADIUS := 125.0
const START_SEPARATION := 105.0
const PLAYBACK_SPEED := 1.5
var hand_glint: HandGlint


func _ready() -> void:
	super._ready()
	hand_glint = HandGlint.new()
	add_child(hand_glint)
	_update_pose()
	visible = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta * PLAYBACK_SPEED
	_update_pose()


func _update_pose() -> void:
	_art.self_modulate.a = 1.0
	var gathering := smoothstep(APPROACH_TIME, TRAVEL_START, elapsed)
	var phase := travel_phase(maxf(elapsed - TRAVEL_START, 0.0))
	var centre := Vector2(cos(phase), sin(phase)) * PATH_RADIUS
	# The travelling turn's half-contracted side, carried around a closed path.
	_apply_pose(centre, phase * 2.0, 0.5 * gathering)
	if elapsed < APPROACH_TIME:
		var separation := START_SEPARATION * (1.0 - smoothstep(0.0, APPROACH_TIME, elapsed))
		var apart := (ghost_b.position - ghost_a.position).normalized() * separation
		ghost_a.position -= apart
		ghost_b.position += apart
	if is_instance_valid(hand_glint):
		hand_glint.age = (elapsed - APPROACH_TIME) / PLAYBACK_SPEED
		hand_glint.points.clear()
		for side in [-1, 1]:
			hand_glint.points.append(hand_glint.to_local(ghost_a.to_global(ghost_a.get_hand_local_position(side))))
		hand_glint.queue_redraw()


func travel_phase(seconds: float) -> float:
	# Integrate a smooth speed ramp, then keep a constant, seamless circular pace.
	var speed := TAU / LAP_TIME
	if seconds < SPEED_RAMP:
		var u := seconds / SPEED_RAMP
		return speed * SPEED_RAMP * (u * u * u - 0.5 * u * u * u * u)
	return speed * (seconds - SPEED_RAMP * 0.5)

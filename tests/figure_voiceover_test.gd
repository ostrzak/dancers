extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene: PrototypeController = load("res://prototype.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var demo := scene.figure_demonstration
	demo.set_process(false)
	_expect(not demo._caption.visible and not demo._narrator.playing, "No caption or narration on startup")
	paused = true
	demo.set_demonstration_visible(true)
	demo.select_figure(1)
	demo.select_figure(0)
	demo._process(0.0)
	_expect(not demo._narrator.playing and demo._narration_pending, "Menu selection waits for resume")
	_expect(not demo._caption.visible, "Menu hides caption")
	paused = false
	demo._process(0.0)
	_expect(demo._narrator.playing and not demo._narration_pending, "Resume starts selected narration once")
	_expect(demo._caption.visible and demo._caption_label.text == "Travelling turn · Clockwise",
		"Caption identifies selected figure (visible=%s, text=%s)" % [demo._caption.visible, demo._caption_label.text])
	_expect(demo._narrator.stream == demo.get_figure().narration, "Player uses selected recording")
	paused = true
	_expect(demo._narrator.stream_paused, "Pause suspends active narration")
	paused = false
	_expect(not demo._narrator.stream_paused, "Resume unpauses active narration")
	demo._narrator.stop()
	demo._process(30.0)
	_expect(not demo._narrator.playing and not demo._narration_pending, "Movement loops never replay completed narration")
	demo.playback_speed = 0.5
	demo.restart()
	demo._process(0.0)
	_expect(demo._narrator.playing and demo._narrator.pitch_scale == 1.0, "Explicit restart replays at natural voice speed")
	demo.select_figure(1)
	_expect(not demo._narrator.playing and demo._narration_pending, "Changing figure stops previous narration")
	demo._process(0.0)
	_expect(demo._narrator.playing and demo._caption_label.text.begins_with("Turn in place"), "New figure updates voice and caption")
	demo.set_demonstration_visible(false)
	_expect(not demo._narrator.playing and not demo._narration_pending and not demo._caption.visible, "Hiding demonstration stops voice and hides caption")
	# Temporarily remove a recording to keep this check valid after all recordings arrive.
	var saved := demo.get_figure().narration
	demo.get_figure().narration = null
	demo.set_demonstration_visible(true)
	demo._process(0.5)
	_expect(not demo._narrator.playing and demo.elapsed > 0.0 and demo._caption.visible, "Missing audio leaves movement and caption working")
	demo.get_figure().narration = saved
	for figure in demo.FIGURES:
		if figure.narration is AudioStreamWAV:
			_expect(figure.narration.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s audio does not loop" % figure.title)
	print("FIGURE VOICEOVER: %d/%d checks passed" % [checks - failures, checks])
	scene.queue_free()
	# Let the audio mixer retire stopped playbacks before shutting down the test.
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)

extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var music := BallroomMusic.new()
	music.preferences_path = "user://music_test_%s.cfg" % Time.get_ticks_usec()
	root.add_child(music)
	paused = true
	await create_timer(1.0).timeout
	_expect(music.player.playing and music.active_index == 0, "title plays while the tree is paused")
	for path in BallroomMusic.PATHS:
		var stream: AudioStream = load(path)
		_expect(stream != null and stream.get_length() > 120, "full recording loads: " + path)
	music.select_track(2)
	_expect(music.active_index == 0, "title track stays Chopin while choosing dance music")
	music.play_context(false)
	await create_timer(1.0).timeout
	_expect(music.player.playing and music.player.stream.resource_path == BallroomMusic.PATHS[2], "dance starts the selected track")
	# Switching during a fade must never restore the stale selection.
	music.select_track(3)
	music.select_track(1)
	await create_timer(1.0).timeout
	_expect(music.player.stream.resource_path == BallroomMusic.PATHS[1], "rapid changes play only the latest selection")
	music.volume = 0
	await process_frame
	await process_frame
	_expect(is_zero_approx(music.player.volume_linear), "zero volume mutes playback")
	music.volume = 0.3
	_expect(music.save_preferences() == OK, "preferences save")
	var reloaded := BallroomMusic.new()
	reloaded.preferences_path = music.preferences_path
	reloaded.load_preferences()
	_expect(reloaded.selected_index == 1 and is_equal_approx(reloaded.volume, 0.3), "track and volume persist")
	reloaded.free()
	music.player.seek(music.player.stream.get_length() - 0.15)
	await create_timer(1.0).timeout
	_expect(music.player.playing and music.player.get_playback_position() < 2, "finished track repeats while paused")
	music.select_track(4)
	await create_timer(0.4).timeout
	_expect(not music.player.playing and music.player.stream == null, "Silence stops the dance track")
	music.play_context(true)
	await create_timer(1.0).timeout
	_expect(music.player.playing and music.active_index == 0, "returning to title restores Chopin")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(music.preferences_path))
	music.free()
	paused = false
	print("BALLROOM MUSIC: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

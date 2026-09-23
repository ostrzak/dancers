class_name BallroomMusic
extends Node

const PATHS := [
	"res://assets/music/chopin_waltz_a_minor_aya_higuchi.ogg",
	"res://assets/music/devonshire_waltz_moderato_kevin_macleod.mp3",
	"res://assets/music/strauss_blue_danube.ogg",
	"res://assets/music/satie_gymnopedie_no_1_kevin_macleod.mp3",
]
const TITLES := ["Waltz in A minor", "Devonshire Waltz Moderato", "The Blue Danube", "Gymnopédie No. 1", "Silence"]
const ARTISTS := ["Frédéric Chopin · Aya Higuchi", "Kevin MacLeod · 93 BPM", "Johann Strauss II · European Archive", "Erik Satie · Kevin MacLeod", "Dance without music"]
const CREDITS := """MUSIC CREDITS

Waltz in A minor, B.150 — Frédéric Chopin
Performance: Aya Higuchi. CC0 1.0.
https://commons.wikimedia.org/wiki/File:Chopin_-_Waltz_in_A_minor,_B_150.ogg

Devonshire Waltz Moderato — Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0
https://creativecommons.org/licenses/by/4.0/
https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN2100016

The Blue Danube — Johann Strauss II
Source credited as European Archive via Musopen. Listed as CC0 1.0.
https://commons.wikimedia.org/wiki/File:Strauss,_An_der_schönen_blauen_Donau.ogg

Gymnopedie No. 1 — Erik Satie
Arrangement and performance: Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 3.0
https://creativecommons.org/licenses/by/3.0/
https://commons.wikimedia.org/wiki/File:Gymnopedie_No._1_(ISRC_USUAN1100787).mp3

CC0 dedication: https://creativecommons.org/publicdomain/zero/1.0/
Original audio files preserved; playback volume, fades and repeats applied in game.
"""

var preferences_path := "user://coop_music.cfg"
var selected_index := 1
var volume := 0.45
var title_mode := true
var player: AudioStreamPlayer
var active_index := -1
var fade: Tween
var gain := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_preferences()
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_repeat)
	play_context(title_mode)


func _process(_delta: float) -> void:
	# Fade the ending, then gently re-enter each complete recording.
	var tail := 1.0
	if player.playing and player.stream:
		tail = clampf((player.stream.get_length() - player.get_playback_position()) / 0.6, 0.0, 1.0)
	player.volume_linear = volume * gain * tail


func play_context(on_title: bool) -> void:
	title_mode = on_title
	var index := 0 if title_mode else selected_index
	if index == active_index:
		return
	active_index = index
	if fade:
		fade.kill()
	fade = create_tween()
	fade.tween_property(self, "gain", 0.0, 0.25)
	fade.tween_callback(_begin_track)
	fade.tween_property(self, "gain", 1.0, 0.6)


func _begin_track() -> void:
	player.stop()
	player.stream = null
	if active_index >= 0 and active_index < PATHS.size():
		player.stream = load(PATHS[active_index])
		player.play()


func _repeat() -> void:
	gain = 0.0
	player.play()
	if fade:
		fade.kill()
	fade = create_tween()
	fade.tween_property(self, "gain", 1.0, 0.6)


func select_track(index: int) -> void:
	selected_index = wrapi(index, 0, TITLES.size())
	play_context(title_mode)


func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) != OK:
		return
	var track: Variant = config.get_value("music", "track", 1)
	var level: Variant = config.get_value("music", "volume", 0.45)
	selected_index = clampi(track, 0, TITLES.size() - 1) if track is int else 1
	volume = clampf(level, 0.0, 1.0) if (level is float or level is int) and is_finite(float(level)) else 0.45


func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("music", "track", selected_index)
	config.set_value("music", "volume", volume)
	return config.save(preferences_path)

extends Node

const PATHS := {
	"explosion": "res://audio/explosion.wav",
	"dash": "res://audio/dash.wav",
	"pickup": "res://audio/pickup.wav",
	"graze": "res://audio/graze.wav",
	"whoosh": "res://audio/whoosh.wav",
	"launch": "res://audio/launch.wav",
	"music": "res://audio/music.mp3",
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	_music.finished.connect(func(): _music.play())
	add_child(_music)

func get_stream(sound_name: String) -> AudioStream:
	if not _cache.has(sound_name):
		var path: String = PATHS[sound_name]
		_cache[sound_name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound_name]

func play(sound_name: String, volume_db := 0.0) -> void:
	var s := get_stream(sound_name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.play()
			return

func play_music() -> void:
	var s := get_stream("music")
	if s == null or _music.playing:
		return
	_music.stream = s
	_music.play()

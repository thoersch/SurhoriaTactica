extends Node

var ambient_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer

var current_ambient: String = ""
var current_music: String = ""
var is_in_battle: bool = false

const AUDIO_PATHS = {
	"ambient_world": "res://audio/ambient/world_ambient.ogg",
	"music_battle": "res://audio/music/battle_theme.ogg",
	"door_open": "res://audio/sfx/door_open.ogg",
	"door_locked": "res://audio/sfx/door_locked.ogg",
	"door_unlock": "res://audio/sfx/door_unlock.ogg",
	"stairs": "res://audio/sfx/stairs.ogg",
	"footstep": "res://audio/sfx/footstep.ogg",
	"item_pickup": "res://audio/sfx/item_pickup.ogg",
	"battle_start": "res://audio/sfx/battle_start.ogg"
}

var ambient_volume: float = 0.5
var music_volume: float = 0.7
var sfx_volume: float = 0.8

func _ready():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Master"
	add_child(ambient_player)
	
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	add_child(music_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "FootstepPlayer"
	footstep_player.bus = "Master"
	add_child(footstep_player)
	
	update_volumes()

func update_volumes():
	ambient_player.volume_db = linear_to_db(ambient_volume)
	music_player.volume_db = linear_to_db(music_volume)
	sfx_player.volume_db = linear_to_db(sfx_volume)
	footstep_player.volume_db = linear_to_db(sfx_volume * 0.8)

func play_ambient(ambient_name: String, fade_duration: float = 2.0):
	if current_ambient == ambient_name and ambient_player.playing:
		return
	
	if ambient_player.playing:
		await fade_out_ambient(fade_duration / 2.0)
	
	var audio_path = AUDIO_PATHS.get(ambient_name, "")
	if audio_path == "":
		push_warning("Ambient sound not found: " + ambient_name)
		return
	
	if not FileAccess.file_exists(audio_path):
		print("Audio file not found (will be added later): " + audio_path)
		return
	
	var stream = load(audio_path)
	if stream:
		ambient_player.stream = stream
		ambient_player.volume_db = linear_to_db(0.0)
		ambient_player.play()
		current_ambient = ambient_name
		await fade_in_ambient(fade_duration / 2.0)

func stop_ambient(fade_duration: float = 2.0):
	if ambient_player.playing:
		await fade_out_ambient(fade_duration)
		current_ambient = ""

func fade_in_ambient(duration: float):
	var tween = create_tween()
	var target_db = linear_to_db(clamp(ambient_volume, 0.0001, 1.0))
	tween.tween_property(ambient_player, "volume_db", target_db, duration)
	await tween.finished

func fade_out_ambient(duration: float):
	var tween = create_tween()
	tween.tween_property(ambient_player, "volume_db", -80.0, duration)
	await tween.finished
	ambient_player.stop()

func play_music(music_name: String, fade_duration: float = 1.5):
	if current_music == music_name and music_player.playing:
		return
	
	if music_player.playing:
		await fade_out_music(fade_duration / 2.0)
	
	var audio_path = AUDIO_PATHS.get(music_name, "")
	if audio_path == "":
		push_warning("Music not found: " + music_name)
		return
	
	if not FileAccess.file_exists(audio_path):
		print("Audio file not found (will be added later): " + audio_path)
		return
	
	var stream = load(audio_path)
	if stream:
		music_player.stream = stream
		music_player.volume_db = linear_to_db(0.0)
		music_player.play()
		current_music = music_name
		await fade_in_music(fade_duration / 2.0)

func stop_music(fade_duration: float = 1.5):
	if music_player.playing:
		await fade_out_music(fade_duration)
		current_music = ""

func fade_in_music(duration: float):
	var tween = create_tween()
	var target_db = linear_to_db(clamp(music_volume, 0.0001, 1.0))
	tween.tween_property(music_player, "volume_db", target_db, duration)
	await tween.finished

func fade_out_music(duration: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()

func play_sfx(sfx_name: String, volume_multiplier: float = 1.0):
	var audio_path = AUDIO_PATHS.get(sfx_name, "")
	if audio_path == "":
		push_warning("SFX not found: " + sfx_name)
		return
	
	if not FileAccess.file_exists(audio_path):
		print("Audio file not found (will be added later): " + audio_path)
		return
	
	var stream = load(audio_path)
	if stream:
		sfx_player.stream = stream
		sfx_player.volume_db = linear_to_db(sfx_volume * volume_multiplier)
		sfx_player.play()

func play_footstep():
	if footstep_player.playing:
		return
	
	var audio_path = AUDIO_PATHS.get("footstep", "")
	if audio_path == "" or not FileAccess.file_exists(audio_path):
		return
	
	var stream = load(audio_path)
	if stream:
		footstep_player.stream = stream
		footstep_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_player.play()

func enter_world():
	is_in_battle = false
	await stop_music(1.0)
	play_ambient("ambient_world")

func enter_battle():
	is_in_battle = true
	await stop_ambient(1.0)
	play_music("music_battle")
	play_sfx("battle_start")

func exit_battle():
	is_in_battle = false
	await stop_music(1.0)
	play_ambient("ambient_world")

func linear_to_db(linear: float) -> float:
	if linear <= 0.0001:  # Use small threshold instead of exact 0
		return -80.0
	return 20.0 * log(linear) / log(10.0)

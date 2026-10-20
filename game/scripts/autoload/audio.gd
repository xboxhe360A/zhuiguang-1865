extends Node
## 声音总线：交互音效池 + 可循环环境声。全部素材为自制 CC0，见 tools/generate_audio.py。

const SFX_DIR := "res://assets/audio/sfx/"
const AMB_DIR := "res://assets/audio/ambience/"
const POOL_SIZE := 10
const AMB_VOLUME := -9.0
const AMB_FADE := -46.0
const MIN_INTERVAL_MS := 35

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _ambience: AudioStreamPlayer
var _ambience_tween: Tween
var _ambience_name := ""
var _last_ms: Dictionary = {}
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	_ambience.volume_db = AMB_FADE
	add_child(_ambience)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_wire_tree")


func play(name: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> AudioStreamPlayer:
	var stream := _stream(SFX_DIR, name + ".wav")
	if stream == null:
		push_warning("missing sfx: " + name)
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(name, -1000)) < MIN_INTERVAL_MS:
		return null
	_last_ms[name] = now
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
	return player


func set_ambience(name: String, fade: float = 1.4) -> void:
	if name == _ambience_name and _ambience.playing:
		return
	_ambience_name = name
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	if _ambience.playing:
		_ambience_tween.tween_property(_ambience, "volume_db", AMB_FADE, maxf(fade * 0.45, 0.01))
	_ambience_tween.tween_callback(_swap_ambience.bind(name))
	if not name.is_empty():
		_ambience_tween.tween_property(_ambience, "volume_db", AMB_VOLUME, maxf(fade * 0.55, 0.01))


func stop_ambience(fade: float = 0.8) -> void:
	set_ambience("", fade)


func _swap_ambience(name: String) -> void:
	_ambience.stop()
	if name.is_empty():
		return
	var stream := _stream(AMB_DIR, name + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_ambience.stream = stream
	_ambience.play()


func _stream(folder: String, file_name: String) -> AudioStream:
	var path := folder + file_name
	if _cache.has(path):
		return _cache[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_cache[path] = stream
	return stream


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)


func _wire_tree() -> void:
	_wire_children(get_tree().root)


func _wire_children(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)
	for child in node.get_children():
		_wire_children(child)


func _wire_button(button: BaseButton) -> void:
	if button == null or button.has_meta("_ui_sfx_wired"):
		return
	button.set_meta("_ui_sfx_wired", true)
	if button.has_meta("ui_sfx") and str(button.get_meta("ui_sfx")) == "none":
		return
	button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play("click", -8.0, 0.08)

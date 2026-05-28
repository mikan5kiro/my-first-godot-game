extends Node
class_name DialogPresenter

## 底部对话框 + 打字机效果 + 打字音效。

@export var typewriter_chars_per_sec: float = 36.0
@export var type_sfx_enabled: bool = true
@export var type_sfx_bus: StringName = &"Master"
@export_range(0.0, 1.0, 0.01) var type_sfx_char_chance: float = 0.75
@export var dialog_scene: PackedScene = preload("res://scenes/interaction_dialog.tscn")

var _dialog: InteractionDialog
var _is_visible: bool = false
var _is_typing: bool = false
var _full_text: String = ""
var _typed_char_count: int = 0
var _type_timer: Timer
var _type_sfx_player: AudioStreamPlayer
var _type_sfx_playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_create_dialog_ui()
	_setup_type_sfx()


func is_visible() -> bool:
	return _is_visible


func is_typing() -> bool:
	return _is_typing


func show_text(text: String) -> void:
	if _dialog == null:
		return

	if _type_timer != null:
		_type_timer.stop()
	_dialog.clear_choices()
	_full_text = text
	_typed_char_count = 0
	_is_typing = not _full_text.is_empty()

	_dialog.set_text("")
	_dialog.show_dialog()
	_is_visible = true

	if not _is_typing:
		return

	var cps: float = maxf(typewriter_chars_per_sec, 1.0)
	_type_timer.wait_time = 1.0 / cps
	_type_timer.start()


func show_text_instant(text: String) -> void:
	if _dialog == null:
		return

	if _type_timer != null:
		_type_timer.stop()
	_is_typing = false
	_full_text = text
	_typed_char_count = _full_text.length()
	_dialog.set_text(text)
	_dialog.show_dialog()
	_is_visible = true


func set_choices(labels: PackedStringArray, selected_index: int) -> void:
	if _dialog != null:
		_dialog.set_choices(labels, selected_index)


func clear_choices() -> void:
	if _dialog != null:
		_dialog.clear_choices()


func skip_typing() -> void:
	if not _is_typing:
		return
	_type_timer.stop()
	_is_typing = false
	if _dialog != null:
		_dialog.set_text(_full_text)


func hide() -> void:
	if _type_timer != null:
		_type_timer.stop()
	if _dialog != null:
		_dialog.hide_dialog()
	_is_typing = false
	_full_text = ""
	_typed_char_count = 0
	_is_visible = false


func _create_dialog_ui() -> void:
	if dialog_scene == null:
		push_error("DialogPresenter: dialog_scene 未设置")
		return
	_dialog = dialog_scene.instantiate() as InteractionDialog
	add_child(_dialog)

	_type_timer = Timer.new()
	_type_timer.one_shot = false
	_type_timer.timeout.connect(_on_typewriter_tick)
	add_child(_type_timer)


func _on_typewriter_tick() -> void:
	if not _is_typing:
		return

	_typed_char_count += 1
	var current_char := _full_text.substr(_typed_char_count - 1, 1)
	_dialog.set_text(_full_text.substr(0, _typed_char_count))
	_play_type_sfx_for_char(current_char)
	if _typed_char_count >= _full_text.length():
		skip_typing()


func _setup_type_sfx() -> void:
	if not type_sfx_enabled:
		return
	_type_sfx_player = AudioStreamPlayer.new()
	_type_sfx_player.bus = type_sfx_bus
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.08
	_type_sfx_player.stream = generator
	add_child(_type_sfx_player)
	_type_sfx_player.play()
	_type_sfx_playback = _type_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _play_type_sfx_for_char(ch: String) -> void:
	if not type_sfx_enabled:
		return
	if _type_sfx_playback == null:
		return
	if ch.is_empty() or ch.strip_edges().is_empty():
		return
	var is_punctuation := "，。！？；：,.!?;:…".contains(ch)
	if not is_punctuation and _rng.randf() > type_sfx_char_chance:
		return

	var mix_rate := 44100.0
	if _type_sfx_player != null and _type_sfx_player.stream is AudioStreamGenerator:
		mix_rate = (_type_sfx_player.stream as AudioStreamGenerator).mix_rate

	var first_duration := _rng.randf_range(0.004, 0.007)
	var first_freq := _rng.randf_range(700.0, 1100.0)
	var first_gain := _rng.randf_range(0.11, 0.18)
	if is_punctuation:
		first_freq = _rng.randf_range(520.0, 820.0)
		first_gain = _rng.randf_range(0.09, 0.14)
	_play_click_pulse(mix_rate, first_duration, first_freq, first_gain, 0.92)

	if is_punctuation:
		return

	var second_duration := _rng.randf_range(0.003, 0.006)
	var second_freq := _rng.randf_range(900.0, 1450.0)
	var second_gain := _rng.randf_range(0.05, 0.1)
	_play_click_pulse(mix_rate, second_duration, second_freq, second_gain, 0.86)


func _play_click_pulse(mix_rate: float, duration: float, freq: float, gain: float, noise_weight: float) -> void:
	var frame_count := int(mix_rate * duration)
	if frame_count <= 0:
		return
	var available_frames := _type_sfx_playback.get_frames_available()
	if available_frames <= 0:
		return
	frame_count = mini(frame_count, available_frames)
	if frame_count <= 0:
		return

	for i in frame_count:
		var t := float(i) / mix_rate
		var progress := float(i) / float(frame_count)
		var env := exp(-7.0 * progress)
		var noise := (_rng.randf() * 2.0 - 1.0) * noise_weight
		var tone := sin(TAU * freq * t) * (1.0 - noise_weight)
		var s := (noise + tone) * gain * env
		_type_sfx_playback.push_frame(Vector2(s, s))

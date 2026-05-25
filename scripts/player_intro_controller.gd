extends Node

@export_file("*.txt") var intro_text_file_path: String = "res://dialogues/intro_awake.txt"
@export var intro_line_1: String = "又是这个梦……"
@export var intro_line_2: String = "今天，得去把那件事做个了断。"
@export var intro_fade_seconds: float = 0.6
@export var intro_black_hold_seconds: float = 0.4
@export var stand_up_sfx: AudioStream = preload("res://audios/衣擦れ.mp3")
@export var on_bed_spawn_marker: String = "Spawn_OnBed"
@export var bedside_spawn_marker: String = "Spawn_BesideBed"
@export_enum("up", "down", "left", "right") var bedside_facing: String = "down"

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _hold_position_marker: String = ""
var _stand_up_sfx_player: AudioStreamPlayer
static var _intro_played_once: bool = false

@onready var _player: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("../AnimatedSprite2D")
@onready var _interact_area: Area2D = get_node_or_null("../Area2D")

func start_intro() -> void:
	if _intro_played_once:
		return
	call_deferred("_run_intro")

func _run_intro() -> void:
	if _animated_sprite == null:
		return
	_intro_played_once = true
	_set_player_locked(true)
	await get_tree().process_frame
	_hold_position_at_marker(on_bed_spawn_marker)
	_ensure_fade_overlay()
	var intro_lines := _get_intro_lines()

	await _play_awake_animation()

	await _play_bed_monologue(intro_lines)

	await _fade_to(1.0, intro_fade_seconds)
	await _play_black_phase_with_sfx()
	_release_position_hold()
	_snap_player_to_marker(bedside_spawn_marker)
	_apply_bedside_facing()
	await _fade_to(0.0, intro_fade_seconds)

	if _player != null and _player.has_method("get_facing"):
		var facing: Facing.Dir = _player.call("get_facing")
		_animated_sprite.play(Facing.to_idle_anim(facing))
	else:
		_animated_sprite.play("down")

	_set_player_locked(false)

func _play_bed_monologue(lines: PackedStringArray) -> void:
	if lines.is_empty() or _interact_area == null:
		return
	if _interact_area.has_method("play_monologue_lines"):
		await _interact_area.call("play_monologue_lines", lines)

func _play_black_phase_with_sfx() -> void:
	# 黑屏开始即播放音频，音频播完后立即继续淡出。
	if not await _play_stand_up_sfx_and_wait():
		# 无音频时回退为固定黑屏时长，避免流程过快。
		var hold_seconds := maxf(intro_black_hold_seconds, 0.0)
		if hold_seconds > 0.0:
			await get_tree().create_timer(hold_seconds).timeout

func _play_stand_up_sfx_and_wait() -> bool:
	if stand_up_sfx == null:
		return false
	if _stand_up_sfx_player == null:
		_stand_up_sfx_player = AudioStreamPlayer.new()
		_stand_up_sfx_player.bus = "Master"
		add_child(_stand_up_sfx_player)
	if _stand_up_sfx_player.playing:
		_stand_up_sfx_player.stop()
	_stand_up_sfx_player.stream = stand_up_sfx
	_stand_up_sfx_player.play()
	await _stand_up_sfx_player.finished
	return true

func _physics_process(_delta: float) -> void:
	if _hold_position_marker.is_empty():
		return
	_snap_player_to_marker(_hold_position_marker)

func _play_awake_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation("awake"):
		return

	_hold_position_at_marker(on_bed_spawn_marker)
	_animated_sprite.sprite_frames.set_animation_loop("awake", false)
	_animated_sprite.stop()
	_animated_sprite.frame = 0
	_animated_sprite.play("awake")

	if _animated_sprite.is_playing():
		await _animated_sprite.animation_finished
	else:
		# 动画只有一帧或已在末帧时，animation_finished 可能不触发。
		var frame_count := _animated_sprite.sprite_frames.get_frame_count("awake")
		var fps := _animated_sprite.sprite_frames.get_animation_speed("awake")
		var duration := float(frame_count) / maxf(fps, 0.01)
		await get_tree().create_timer(duration).timeout

func _hold_position_at_marker(marker_name: String) -> void:
	_hold_position_marker = marker_name
	_snap_player_to_marker(marker_name)

func _release_position_hold() -> void:
	_hold_position_marker = ""

func _snap_player_to_marker(marker_name: String) -> void:
	if _player == null or marker_name.is_empty():
		return
	var marker := _find_marker(marker_name)
	if marker == null:
		push_warning("PlayerIntroController: 找不到 Marker '%s'" % marker_name)
		return
	_player.global_position = marker.global_position
	_player.velocity = Vector2.ZERO

func _find_marker(marker_name: String) -> Marker2D:
	var scene_root := _player.get_parent() if _player != null else null
	if scene_root == null:
		return null
	var marker := scene_root.get_node_or_null(marker_name) as Marker2D
	if marker == null:
		marker = scene_root.find_child(marker_name, true, false) as Marker2D
	return marker

func _apply_bedside_facing() -> void:
	if _player != null and _player.has_method("set_facing_direction"):
		_player.call("set_facing_direction", bedside_facing)

func _set_player_locked(locked: bool) -> void:
	if _player != null and _player.has_method("set_controls_locked"):
		_player.call("set_controls_locked", locked)
	if _player != null:
		_player.velocity = Vector2.ZERO

func _get_intro_lines() -> PackedStringArray:
	var fallback_lines := PackedStringArray([intro_line_1, intro_line_2])
	if intro_text_file_path.is_empty():
		return fallback_lines
	var lines := DialogTextLoader.load_lines(intro_text_file_path, fallback_lines)
	if lines.is_empty():
		return fallback_lines
	return lines

func _ensure_fade_overlay() -> void:
	if _fade_layer != null:
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 200
	_fade_layer.name = "IntroFadeLayer"
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.offset_left = 0.0
	_fade_rect.offset_top = 0.0
	_fade_rect.offset_right = 0.0
	_fade_rect.offset_bottom = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_layer.add_child(_fade_rect)

func _fade_to(target_alpha: float, seconds: float) -> void:
	if _fade_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", clampf(target_alpha, 0.0, 1.0), maxf(seconds, 0.01))
	await tween.finished

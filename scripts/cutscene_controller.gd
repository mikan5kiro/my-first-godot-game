extends Node
class_name CutsceneController

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _hold_position_marker: String = ""
var _sfx_player: AudioStreamPlayer
var _is_playing: bool = false

@onready var _player: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _animated_sprite: AnimatedSprite2D = get_parent().get_node_or_null("AnimatedSprite2D")
@onready var _interact_area: PlayerInteractor = get_parent().get_node_or_null("Area2D") as PlayerInteractor


func is_pending(data: CutsceneData) -> bool:
	if data == null:
		return false
	if data.completion_flag.is_empty():
		return true
	return GameState != null and not GameState.has_flag(data.completion_flag)


func prepare(data: CutsceneData) -> void:
	if data == null or data.prepare_marker.is_empty():
		return
	_hold_at_marker(data.prepare_marker)


func play(data: CutsceneData) -> void:
	if data == null or _is_playing:
		return
	if not is_pending(data):
		_set_player_locked(false)
		return
	_mark_cutscene_completed(data)
	_run_cutscene(data)


func _run_cutscene(data: CutsceneData) -> void:
	_is_playing = true
	if _animated_sprite == null:
		push_warning("CutsceneController: 找不到 AnimatedSprite2D，跳过过场")
		_set_player_locked(false)
		_is_playing = false
		return

	_set_player_locked(true)
	await get_tree().process_frame
	_ensure_fade_overlay()

	for step in data.steps:
		await _run_step(step)

	_mark_cutscene_completed(data)
	_set_player_locked(false)
	_is_playing = false


func _mark_cutscene_completed(data: CutsceneData) -> void:
	if data == null or data.completion_flag.is_empty() or GameState == null:
		return
	GameState.set_flag(data.completion_flag)


func _run_step(step: CutsceneStep) -> void:
	if step == null:
		return

	match step.type:
		CutsceneStep.StepType.HOLD_MARKER:
			_hold_at_marker(step.marker_name)
		CutsceneStep.StepType.RELEASE_HOLD:
			_release_position_hold()
		CutsceneStep.StepType.SNAP_MARKER:
			_snap_player_to_marker(step.marker_name)
		CutsceneStep.StepType.SET_FACING:
			_apply_facing(step.facing)
		CutsceneStep.StepType.PLAY_ANIM:
			await _play_animation(step.anim_name)
		CutsceneStep.StepType.MONOLOGUE:
			await _play_monologue(step)
		CutsceneStep.StepType.FADE:
			await _fade_to(step.fade_alpha, step.duration)
		CutsceneStep.StepType.WAIT:
			if step.duration > 0.0:
				await get_tree().create_timer(step.duration).timeout
		CutsceneStep.StepType.PLAY_SFX:
			await _play_sfx(step.sfx, step.wait_if_no_sfx)
		CutsceneStep.StepType.PLAY_IDLE:
			_play_idle_from_facing()


func _physics_process(_delta: float) -> void:
	if _hold_position_marker.is_empty():
		return
	_snap_player_to_marker(_hold_position_marker)


func _hold_at_marker(marker_name: String) -> void:
	_hold_position_marker = marker_name
	_snap_player_to_marker(marker_name)


func _release_position_hold() -> void:
	_hold_position_marker = ""


func _snap_player_to_marker(marker_name: String) -> void:
	if _player == null or marker_name.is_empty():
		return
	var scene_root := _player.get_parent()
	if scene_root == null:
		return
	if not SpawnUtils.snap_node_to_marker(_player, scene_root, marker_name):
		push_warning("CutsceneController: 找不到 Marker '%s'" % marker_name)


func _apply_facing(direction: String) -> void:
	if _player != null and _player.has_method("set_facing_direction"):
		_player.call("set_facing_direction", direction)


func _play_idle_from_facing() -> void:
	if _animated_sprite == null:
		return
	if _player != null and _player.has_method("get_facing"):
		var facing: Facing.Dir = _player.call("get_facing")
		_animated_sprite.play(Facing.to_idle_anim(facing))
	else:
		_animated_sprite.play("down")


func _play_animation(anim_name: String) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if anim_name.is_empty() or not _animated_sprite.sprite_frames.has_animation(anim_name):
		return

	_animated_sprite.sprite_frames.set_animation_loop(anim_name, false)
	_animated_sprite.stop()
	_animated_sprite.frame = 0
	_animated_sprite.play(anim_name)

	if _animated_sprite.is_playing():
		await _animated_sprite.animation_finished
	else:
		var frame_count := _animated_sprite.sprite_frames.get_frame_count(anim_name)
		var fps := _animated_sprite.sprite_frames.get_animation_speed(anim_name)
		var anim_duration := float(frame_count) / maxf(fps, 0.01)
		await get_tree().create_timer(anim_duration).timeout


func _play_monologue(step: CutsceneStep) -> void:
	var lines: PackedStringArray = step.fallback_lines
	if not step.text_file.is_empty():
		lines = DialogTextLoader.load_lines(step.text_file, step.fallback_lines)
	if lines.is_empty() or _interact_area == null:
		return
	await _interact_area.play_monologue_lines(lines)


func _play_sfx(stream: AudioStream, wait_if_no_sfx: float) -> void:
	if not await _play_sfx_and_wait(stream):
		var hold_seconds := maxf(wait_if_no_sfx, 0.0)
		if hold_seconds > 0.0:
			await get_tree().create_timer(hold_seconds).timeout


func _play_sfx_and_wait(stream: AudioStream) -> bool:
	if stream == null:
		return false
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.bus = &"Master"
		add_child(_sfx_player)
	if _sfx_player.playing:
		_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.play()
	await _sfx_player.finished
	return true


func _set_player_locked(locked: bool) -> void:
	if _player != null and _player.has_method("set_controls_locked"):
		_player.call("set_controls_locked", locked)
	if _player != null:
		_player.velocity = Vector2.ZERO


func _ensure_fade_overlay() -> void:
	if _fade_layer != null:
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 200
	_fade_layer.name = "CutsceneFadeLayer"
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


func _exit_tree() -> void:
	_release_position_hold()
	_is_playing = false

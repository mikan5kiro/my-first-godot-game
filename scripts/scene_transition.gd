extends CanvasLayer

@export var fade_duration: float = 0.35
@export var door_open_sfx_delay_frames: int = 2
@export var door_sfx_scene: PackedScene = preload("res://scenes/开关门声音.tscn")

const DOOR_CLOSE_SFX: AudioStream = preload("res://audios/ドアを閉める2.mp3")
const DOOR_OPEN_SFX_MAX_DURATION: float = 0.7
const CUSTOM_DOOR_OPEN_SFX_MAX_DURATION: float = 1.8
const DOOR_DELAY_AFTER_OPEN_SFX := 0.12
const TITLE_BGM: AudioStream = preload("res://audios/maou_bgm_piano40.mp3")
const TITLE_BGM_VOLUME_DB := -6.0

var _overlay: ColorRect
var _ui_container: Control
var _transitioning := false
var _ending_ui_root: Control
var _ending_bgm_player: AudioStreamPlayer
var _ending_waiting_for_input := false
var _ending_input_received := false
var _pending_spawn_marker := ""
var _pending_facing_direction := ""
var _pending_spawn_position: Variant = null
var _door_sfx_player: Node = null
var _default_door_stream: AudioStream = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	get_tree().scene_changed.connect(_on_scene_changed)

	_ui_container = Control.new()
	_ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_container.set_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_container)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_container.add_child(_overlay)

	_setup_door_sfx_player()


func _input(event: InputEvent) -> void:
	if not _ending_waiting_for_input or event.is_echo():
		return
	if _is_any_input_press(event):
		_ending_input_received = true


func _unhandled_input(event: InputEvent) -> void:
	if not _ending_waiting_for_input or event.is_echo():
		return
	if _is_any_input_press(event):
		_ending_input_received = true
		get_viewport().set_input_as_handled()


func _is_any_input_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _resolve_door_sfx_stream(custom_stream: AudioStream = null) -> AudioStream:
	if custom_stream != null:
		return custom_stream
	return _default_door_stream


func _get_door_sfx_volume_db() -> float:
	if _door_sfx_player is AudioStreamPlayer2D:
		return (_door_sfx_player as AudioStreamPlayer2D).volume_db
	if _door_sfx_player is AudioStreamPlayer:
		return (_door_sfx_player as AudioStreamPlayer).volume_db
	return 0.0


func _door_open_sfx_max_duration(custom_stream: AudioStream) -> float:
	if custom_stream != null:
		return CUSTOM_DOOR_OPEN_SFX_MAX_DURATION
	return DOOR_OPEN_SFX_MAX_DURATION


func _wait_for_stream_player(player: AudioStreamPlayer, max_duration: float) -> void:
	await get_tree().create_timer(max_duration).timeout
	if player.playing:
		player.stop()


func _play_stream_and_wait(stream: AudioStream, max_duration: float) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = stream
	player.volume_db = _get_door_sfx_volume_db()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()
	await _wait_for_stream_player(player, max_duration)
	player.queue_free()


func _play_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = stream
	player.volume_db = _get_door_sfx_volume_db()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _play_stream_until_finished(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = stream
	player.volume_db = _get_door_sfx_volume_db()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()


func play_door_sfx(custom_stream: AudioStream = null) -> void:
	var stream := _resolve_door_sfx_stream(custom_stream)
	if stream == null or _door_sfx_player == null:
		return
	if _door_sfx_player is AudioStreamPlayer2D:
		var player := _door_sfx_player as AudioStreamPlayer2D
		player.stream = stream
		player.play()
	elif _door_sfx_player is AudioStreamPlayer:
		var player := _door_sfx_player as AudioStreamPlayer
		player.stream = stream
		player.play()


func play_door_sfx_and_wait(custom_stream: AudioStream = null) -> void:
	var stream := _resolve_door_sfx_stream(custom_stream)
	await _play_stream_and_wait(stream, _door_open_sfx_max_duration(custom_stream))


func is_transitioning() -> bool:
	return _transitioning


## 等待当前场景切换的黑屏淡入/淡出结束（无切换时立即返回）。
func wait_until_idle() -> void:
	while _transitioning:
		await get_tree().process_frame


func has_pending_spawn() -> bool:
	return not _pending_spawn_marker.is_empty() or _pending_spawn_position is Vector2


func set_pending_spawn_position(position: Vector2, facing_direction: String = "") -> void:
	_pending_spawn_position = position
	_pending_facing_direction = facing_direction
	_pending_spawn_marker = ""


func clear_pending_spawn() -> void:
	_pending_spawn_marker = ""
	_pending_facing_direction = ""
	_pending_spawn_position = null


func transition_to(scene_path: String, spawn_marker_name: String = "", facing_direction: String = "") -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to_black()
	_pending_spawn_marker = spawn_marker_name
	_pending_facing_direction = facing_direction
	if not spawn_marker_name.is_empty():
		_pending_spawn_position = null
	get_tree().change_scene_to_file(scene_path)
	await _fade_from_black()
	_transitioning = false
	clear_pending_spawn()


func transition_to_with_door_sfx(
	scene_path: String,
	spawn_marker_name: String = "",
	facing_direction: String = "",
	custom_stream: AudioStream = null,
	delay_after_sfx: float = 0.0,
	play_close_sfx: bool = true,
) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to_black_with_door_open(custom_stream)
	await _wait_before_door_close_sfx(delay_after_sfx)
	_pending_spawn_marker = spawn_marker_name
	_pending_facing_direction = facing_direction
	if not spawn_marker_name.is_empty():
		_pending_spawn_position = null
	get_tree().change_scene_to_file(scene_path)
	await _fade_from_black()
	_transitioning = false
	clear_pending_spawn()
	if play_close_sfx:
		_play_stream(DOOR_CLOSE_SFX)


func transition_to_with_door_sfx_after_black(
	scene_path: String,
	spawn_marker_name: String = "",
	facing_direction: String = "",
	custom_stream: AudioStream = null,
	delay_before_sfx: float = 0.0,
	delay_after_sfx: float = 0.0,
	play_close_sfx: bool = true,
) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to_black()
	if delay_before_sfx > 0.0:
		await get_tree().create_timer(delay_before_sfx).timeout
	await play_door_sfx_and_wait(custom_stream)
	await _wait_before_door_close_sfx(delay_after_sfx)
	_pending_spawn_marker = spawn_marker_name
	_pending_facing_direction = facing_direction
	if not spawn_marker_name.is_empty():
		_pending_spawn_position = null
	get_tree().change_scene_to_file(scene_path)
	await _fade_from_black()
	_transitioning = false
	clear_pending_spawn()
	if play_close_sfx:
		_play_stream(DOOR_CLOSE_SFX)


func claim_title_bgm(parent: Node, bus: StringName = &"Master", volume_db: float = TITLE_BGM_VOLUME_DB) -> AudioStreamPlayer:
	if _ending_bgm_player == null or not is_instance_valid(_ending_bgm_player) or not _ending_bgm_player.playing:
		return null
	remove_child(_ending_bgm_player)
	_ending_bgm_player.bus = bus
	_ending_bgm_player.volume_db = volume_db
	parent.add_child(_ending_bgm_player)
	var player := _ending_bgm_player
	_ending_bgm_player = null
	return player


func play_ending(
	door_sfx: AudioStream = null,
	end_text: String = "THE END",
	title_scene_path: String = "res://scenes/title_screen.tscn",
	delay_after_sfx: float = DOOR_DELAY_AFTER_OPEN_SFX,
) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to_black_with_door_open(door_sfx)
	await _wait_before_door_close_sfx(delay_after_sfx)
	await get_tree().create_timer(fade_duration).timeout
	await _play_stream_until_finished(DOOR_CLOSE_SFX)
	_show_ending_text(end_text)
	_play_ending_bgm()
	_ending_waiting_for_input = true
	_ending_input_received = false
	while not _ending_input_received:
		await get_tree().process_frame
	_ending_waiting_for_input = false
	_clear_ending_ui()
	if title_scene_path.is_empty():
		await _fade_from_black()
		_transitioning = false
		return
	get_tree().change_scene_to_file(title_scene_path)
	await _fade_from_black()
	_transitioning = false


func play_action_with_fade(
	action: Callable,
	duration: float = -1.0,
	on_fade_out_start: Callable = Callable(),
	play_close_sfx: bool = false,
) -> void:
	if _transitioning:
		return
	_transitioning = true
	var use_duration := fade_duration if duration <= 0.0 else duration
	await _fade_to_alpha(1.0, use_duration)
	if action.is_valid():
		await action.call()
	if on_fade_out_start.is_valid():
		on_fade_out_start.call()
	await _fade_to_alpha(0.0, use_duration)
	_transitioning = false
	if play_close_sfx:
		await _play_stream_until_finished(DOOR_CLOSE_SFX)


func _on_scene_changed() -> void:
	if _pending_spawn_position is Vector2:
		var position: Vector2 = _pending_spawn_position
		var absolute_spawn_facing_direction := _pending_facing_direction
		_pending_spawn_position = null
		_pending_facing_direction = ""
		_apply_absolute_spawn(position, absolute_spawn_facing_direction)
		return
	if _pending_spawn_marker.is_empty():
		return
	var marker_name := _pending_spawn_marker
	var facing_direction := _pending_facing_direction
	_pending_spawn_marker = ""
	_pending_facing_direction = ""
	_apply_spawn(marker_name, facing_direction)


func _apply_spawn(spawn_marker_name: String, facing_direction: String = "") -> void:
	if spawn_marker_name.is_empty():
		return

	var scene_root := _get_scene_root()
	if scene_root == null:
		push_warning("SceneTransition: 当前场景为空")
		return

	var player := _find_player(scene_root)
	if player == null:
		push_warning("SceneTransition: 找不到玩家")
		return

	if not SpawnUtils.snap_node_to_marker(player, scene_root, spawn_marker_name):
		push_warning("SceneTransition: 找不到 Marker '%s'" % spawn_marker_name)
		return
	if not facing_direction.is_empty() and player.has_method("set_facing_direction"):
		player.set_facing_direction(facing_direction)

	if scene_root.has_method("apply_camera_limits"):
		scene_root.apply_camera_limits()


func _apply_absolute_spawn(position: Vector2, facing_direction: String = "") -> void:
	var scene_root := _get_scene_root()
	if scene_root == null:
		push_warning("SceneTransition: 当前场景为空")
		return

	var player := _find_player(scene_root)
	if player == null:
		push_warning("SceneTransition: 找不到玩家")
		return

	player.global_position = position
	if not facing_direction.is_empty() and player.has_method("set_facing_direction"):
		player.set_facing_direction(facing_direction)

	if scene_root.has_method("apply_camera_limits"):
		scene_root.apply_camera_limits()


func _get_scene_root() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene

	for child in get_tree().root.get_children():
		if child == self:
			continue
		return child

	return null


func _find_player(scene_root: Node) -> CharacterBody2D:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null:
		return player

	for node in scene_root.find_children("*", "CharacterBody2D", true, false):
		return node as CharacterBody2D

	return null


func _fade_to_black() -> void:
	await _fade_to_alpha(1.0, fade_duration)


func _wait_before_door_close_sfx(delay_after_sfx: float) -> void:
	if delay_after_sfx > 0.0:
		await get_tree().create_timer(delay_after_sfx).timeout


func _fade_to_black_with_door_open(custom_stream: AudioStream = null) -> void:
	var stream := _resolve_door_sfx_stream(custom_stream)
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, maxf(fade_duration, 0.01))

	for _i in maxi(door_open_sfx_delay_frames, 0):
		await get_tree().process_frame

	if stream == null:
		await tween.finished
		return

	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = stream
	player.volume_db = _get_door_sfx_volume_db()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()
	var max_duration := _door_open_sfx_max_duration(custom_stream)
	var open_limit_ends_at := Time.get_ticks_msec() + int(max_duration * 1000.0)
	await tween.finished
	var remaining_ms := open_limit_ends_at - Time.get_ticks_msec()
	if remaining_ms > 0:
		await get_tree().create_timer(remaining_ms / 1000.0).timeout
	if player.playing:
		player.stop()
	player.queue_free()


func _fade_from_black() -> void:
	await _fade_to_alpha(0.0, fade_duration)


func _fade_to_alpha(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", clampf(target_alpha, 0.0, 1.0), maxf(duration, 0.01))
	await tween.finished


func _show_ending_text(text: String) -> void:
	_clear_ending_ui()
	_ending_ui_root = CenterContainer.new()
	_ending_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending_ui_root.set_offsets_preset(Control.PRESET_FULL_RECT)
	_ending_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)

	_ending_ui_root.add_child(label)
	_ui_container.add_child(_ending_ui_root)


func _play_ending_bgm() -> void:
	if _ending_bgm_player != null and is_instance_valid(_ending_bgm_player) and _ending_bgm_player.playing:
		return
	if TITLE_BGM == null:
		return

	var stream := TITLE_BGM.duplicate(true)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	_ending_bgm_player = AudioStreamPlayer.new()
	_ending_bgm_player.bus = &"Master"
	_ending_bgm_player.volume_db = TITLE_BGM_VOLUME_DB
	_ending_bgm_player.stream = stream
	_ending_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ending_bgm_player)
	_ending_bgm_player.play()


func _clear_ending_ui() -> void:
	if _ending_ui_root != null and is_instance_valid(_ending_ui_root):
		_ending_ui_root.queue_free()
	_ending_ui_root = null


func _setup_door_sfx_player() -> void:
	if door_sfx_scene == null:
		push_warning("SceneTransition: 开关门音效场景未设置")
		return

	_door_sfx_player = door_sfx_scene.instantiate()
	if _door_sfx_player == null:
		push_warning("SceneTransition: 开关门音效场景实例化失败")
		return

	add_child(_door_sfx_player)
	_door_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if _door_sfx_player is AudioStreamPlayer2D:
		_default_door_stream = (_door_sfx_player as AudioStreamPlayer2D).stream
	elif _door_sfx_player is AudioStreamPlayer:
		_default_door_stream = (_door_sfx_player as AudioStreamPlayer).stream

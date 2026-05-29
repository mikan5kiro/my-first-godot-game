extends CanvasLayer

@export var fade_duration: float = 0.35
@export var door_sfx_scene: PackedScene = preload("res://scenes/开关门声音.tscn")

var _overlay: ColorRect
var _transitioning := false
var _pending_spawn_marker := ""
var _pending_facing_direction := ""
var _door_sfx_player: Node = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.set_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_overlay)

	_setup_door_sfx_player()


func play_door_sfx() -> void:
	if _door_sfx_player == null:
		return
	if _door_sfx_player.has_method("play"):
		_door_sfx_player.call("play")


func is_transitioning() -> bool:
	return _transitioning


## 等待当前场景切换的黑屏淡入/淡出结束（无切换时立即返回）。
func wait_until_idle() -> void:
	while _transitioning:
		await get_tree().process_frame


func has_pending_spawn() -> bool:
	return not _pending_spawn_marker.is_empty()


func transition_to(scene_path: String, spawn_marker_name: String = "", facing_direction: String = "") -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to_black()
	_pending_spawn_marker = spawn_marker_name
	_pending_facing_direction = facing_direction
	get_tree().change_scene_to_file(scene_path)
	await _fade_from_black()
	_transitioning = false


func play_action_with_fade(
	action: Callable,
	duration: float = -1.0,
	on_fade_out_start: Callable = Callable(),
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


func _on_scene_changed() -> void:
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


func _fade_from_black() -> void:
	await _fade_to_alpha(0.0, fade_duration)


func _fade_to_alpha(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", clampf(target_alpha, 0.0, 1.0), maxf(duration, 0.01))
	await tween.finished


func _setup_door_sfx_player() -> void:
	if door_sfx_scene == null:
		push_warning("SceneTransition: 开关门音效场景未设置")
		return

	_door_sfx_player = door_sfx_scene.instantiate()
	if _door_sfx_player == null:
		push_warning("SceneTransition: 开关门音效场景实例化失败")
		return

	add_child(_door_sfx_player)

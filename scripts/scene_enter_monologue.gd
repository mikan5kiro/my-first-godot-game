extends Node

## 玩家第一次进入本场景时播放一句独白（经 PlayerInteractor）。

@export var once_flag: String = ""
@export_multiline var lines: String = ""


func _ready() -> void:
	if once_flag.is_empty() or lines.strip_edges().is_empty():
		return
	if GameState != null and GameState.has_flag(once_flag):
		return
	call_deferred("_try_play")


func _try_play() -> void:
	if once_flag.is_empty():
		return
	if GameState != null and GameState.has_flag(once_flag):
		return

	await _wait_until_scene_ready()

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return

	var interactor := player.get_node_or_null("Area2D") as PlayerInteractor
	if interactor == null:
		return

	var dialog_lines := DialogTextLoader.lines_from_strings(_lines_as_array())
	if dialog_lines.is_empty():
		return

	if GameState != null:
		GameState.set_flag(once_flag)

	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	await interactor.play_monologue_lines(dialog_lines)
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


func _wait_until_scene_ready() -> void:
	if SceneTransition != null:
		await SceneTransition.wait_until_idle()
		return
	await get_tree().process_frame


func _lines_as_array() -> PackedStringArray:
	var result := PackedStringArray()
	for raw in lines.split("\n", false):
		var stripped := raw.strip_edges()
		if stripped.is_empty():
			continue
		result.append(stripped)
	return result

extends Node

var _is_playing_event := false


func _ready() -> void:
	call_deferred("_try_play_pending_events")


func _try_play_pending_events() -> void:
	if _is_playing_event or GameState == null or not _is_living_room_scene():
		return
	if not GameState.has_flag(GameState.FLAG_WORKSHOP_HUNGER_PENDING) \
		and not GameState.has_flag(GameState.FLAG_KITCHEN_AFTERNOON_PENDING):
		return

	_is_playing_event = true
	await _wait_until_scene_ready()

	if GameState.has_flag(GameState.FLAG_WORKSHOP_HUNGER_PENDING):
		await _play_workshop_hunger_event()
	elif GameState.has_flag(GameState.FLAG_KITCHEN_AFTERNOON_PENDING):
		await _play_kitchen_afternoon_event()

	_is_playing_event = false


func _play_workshop_hunger_event() -> void:
	if GameState.has_flag(GameState.FLAG_WORKSHOP_HUNGER_PROMPT):
		GameState.clear_flag(GameState.FLAG_WORKSHOP_HUNGER_PENDING)
		return

	GameState.clear_flag(GameState.FLAG_WORKSHOP_HUNGER_PENDING)

	var dialog_lines := DialogTextLoader.lines_from_strings(GameText.WORKSHOP_HUNGER_LINES)
	if dialog_lines.is_empty():
		return

	GameState.set_flag(GameState.FLAG_WORKSHOP_HUNGER_PROMPT)
	await _play_monologue(dialog_lines)


func _play_kitchen_afternoon_event() -> void:
	if GameState.has_flag(GameState.FLAG_KITCHEN_AFTERNOON_PROMPT):
		GameState.clear_flag(GameState.FLAG_KITCHEN_AFTERNOON_PENDING)
		return

	GameState.clear_flag(GameState.FLAG_KITCHEN_AFTERNOON_PENDING)

	var dialog_lines := DialogTextLoader.lines_from_strings(GameText.KITCHEN_AFTERNOON_LINES)
	if dialog_lines.is_empty():
		return

	GameState.set_flag(GameState.FLAG_KITCHEN_AFTERNOON_PROMPT)
	await _play_monologue(dialog_lines)


func _play_monologue(dialog_lines: Array[DialogLine]) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return

	var interactor := player.get_node_or_null("Area2D") as PlayerInteractor
	if interactor == null:
		return

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


func _is_living_room_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.ends_with("客厅.tscn")

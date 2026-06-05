extends Node

## 多槽存档读写（Autoload: SaveManager）。

const SLOT_COUNT := 3

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)

var active_slot: int = -1


func get_save_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


func has_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists(get_save_path(slot))


func has_any_save() -> bool:
	for slot in SLOT_COUNT:
		if has_save(slot):
			return true
	return false


func read_save_data(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}

	var file := FileAccess.open(get_save_path(slot), FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func save_game(slot: int, player_name: String = "ui.common.player_name_default") -> bool:
	if not _is_valid_slot(slot):
		save_completed.emit(slot, false)
		return false
	if not _can_save():
		save_completed.emit(slot, false)
		return false

	var player := _get_player()
	var scene := get_tree().current_scene
	if player == null or scene == null:
		save_completed.emit(slot, false)
		return false

	var data := GameState.to_save_data()
	data["player_name"] = player_name
	data["scene_path"] = scene.scene_file_path
	data["player_position"] = {
		"x": player.global_position.x,
		"y": player.global_position.y,
	}
	data["player_facing"] = player.get_facing_name()
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())

	if not _write_save(slot, data):
		save_completed.emit(slot, false)
		return false

	active_slot = slot
	save_completed.emit(slot, true)
	return true


func load_game(slot: int) -> bool:
	if not has_save(slot):
		load_completed.emit(slot, false)
		return false

	var data := read_save_data(slot)
	if data.is_empty():
		load_completed.emit(slot, false)
		return false

	GameState.apply_save_data(data)
	_restore_pending_arrivals()

	var scene_path: String = str(data.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		load_completed.emit(slot, false)
		return false

	var pos: Dictionary = data.get("player_position", {})
	var spawn_pos := Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
	var facing: String = str(data.get("player_facing", ""))
	SceneTransition.set_pending_spawn_position(spawn_pos, facing)
	await SceneTransition.transition_to(scene_path, "", facing)

	active_slot = slot
	load_completed.emit(slot, true)
	return true


func can_save() -> bool:
	return _can_save()


func _can_save() -> bool:
	if GameState == null:
		return false
	if SceneTransition != null and SceneTransition.is_transitioning():
		return false

	var scene := get_tree().current_scene
	if scene == null:
		return false
	if PlayerPanel != null and scene.scene_file_path == PlayerPanel.title_scene_path:
		return false

	return _get_player() != null


func _restore_pending_arrivals() -> void:
	if GameState.has_flag(GameState.FLAG_DELIVERY_ORDERED):
		PendingArrivalController.schedule_delivery_arrival()
	if GameState.has_flag(GameState.FLAG_FOOD_SUPPLY_ORDERED):
		PendingArrivalController.schedule_food_arrival()


func _write_save(slot: int, data: Dictionary) -> bool:
	var file := FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: 无法写入 '%s'" % get_save_path(slot))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _get_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT

extends InteractableDoor
class_name RoomAreaDoor

const CHOICE_YES := "yes"
const CHOICE_NO := "no"

@export_range(0.0, 2.0, 0.05) var unlock_pre_open_pause: float = 0.45
@export_range(0.0, 2.0, 0.05) var unlock_black_hold_after_open_sfx: float = 0.6


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _is_unlocked():
		return []
	return []


func can_interact(interactor: Node) -> bool:
	if _is_activating:
		return false
	if required_facing != "any":
		if interactor == null or not interactor.has_method("get_facing_name"):
			return false
		if String(interactor.call("get_facing_name")) != required_facing:
			return false
	if _is_unlocked():
		return not target_scene.is_empty()
	return not _blocked_dialog_lines.is_empty()


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	if _is_unlocked():
		return super.interact(interactor)
	_run_locked_door_flow(interactor)
	return ""


func _run_locked_door_flow(interactor: Node) -> void:
	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return

	if not _blocked_dialog_lines.is_empty():
		await player_interactor.play_monologue_lines(_blocked_dialog_lines)

	if not _has_shiny_thing():
		return

	player_interactor.show_choice(
		GameText.ROOM_DOOR_UNLOCK_PROMPT,
		[
			{"id": CHOICE_YES, "label": GameText.CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.CHOICE_NO},
		],
		_on_unlock_choice.bind(player_interactor, interactor),
	)


func _has_shiny_thing() -> bool:
	return GameState != null and GameState.has_shiny_thing()


func _on_unlock_choice(
	choice_id: String,
	player_interactor: PlayerInteractor,
	interactor: Node,
) -> void:
	match choice_id:
		CHOICE_YES:
			_open_with_shiny_thing(player_interactor, interactor)
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _open_with_shiny_thing(player_interactor: PlayerInteractor, interactor: Node) -> void:
	if target_scene.is_empty():
		player_interactor.hide_text_immediately()
		return
	if not _has_shiny_thing():
		player_interactor.hide_text_immediately()
		return
	_permanently_unlock()
	player_interactor.hide_text_immediately()
	_is_activating = true
	var facing_name := ""
	if interactor != null and interactor.has_method("get_facing_name"):
		facing_name = String(interactor.call("get_facing_name"))
	await _play_unlock_transition(interactor, facing_name)


func _play_unlock_transition(interactor: Node, facing_name: String) -> void:
	if interactor != null and interactor.has_method("set_controls_locked"):
		interactor.set_controls_locked(true)
	if unlock_pre_open_pause > 0.0:
		await get_tree().create_timer(unlock_pre_open_pause).timeout
	await SceneTransition.transition_to_with_door_sfx_after_black(
		target_scene,
		spawn_marker_name,
		facing_name,
		door_sfx,
		unlock_black_hold_after_open_sfx,
		play_close_sfx,
	)


func _permanently_unlock() -> void:
	if unlock_flag.is_empty() or GameState == null:
		return
	GameState.set_flag(unlock_flag)


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

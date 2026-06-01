extends InteractableDoor
class_name RoomAreaDoor

const CHOICE_YES := "yes"
const CHOICE_NO := "no"


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _is_unlocked():
		return []
	if _should_offer_unlock_choice():
		return []
	return super.get_interaction_dialog_lines()


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
	if _should_offer_unlock_choice():
		return true
	return not super.get_interaction_dialog_lines().is_empty()


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	if _is_unlocked():
		return super.interact(interactor)
	if _should_offer_unlock_choice():
		_run_unlock_choice_flow(interactor)
		return ""
	_on_blocked_interact()
	return ""


func _should_offer_unlock_choice() -> bool:
	return _has_shiny_thing() and _uses_blocked_repeat_dialog()


func _has_shiny_thing() -> bool:
	return GameState != null and GameState.has_shiny_thing()


func _run_unlock_choice_flow(interactor: Node) -> void:
	_unlock_choice_flow(interactor)


func _unlock_choice_flow(interactor: Node) -> void:
	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return

	var lines := _blocked_repeat_dialog_lines
	if lines.is_empty():
		lines = _blocked_dialog_lines
	if not lines.is_empty():
		await player_interactor.play_monologue_lines(lines)

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
	player_interactor.hide_text_immediately()
	_is_activating = true
	var facing_name := ""
	if interactor != null and interactor.has_method("get_facing_name"):
		facing_name = String(interactor.call("get_facing_name"))
	_start_transition(facing_name)


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

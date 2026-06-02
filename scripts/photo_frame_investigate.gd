extends Interactable
class_name PhotoFrameInvestigateItem

const CHOICE_YES := "yes"
const CHOICE_NO := "no"

@export_multiline var intro_message: String = ""
@export_multiline var detail_message: String = ""
@export var choice_prompt: String = GameText.PHOTO_FRAME_CHOICE_PROMPT
@export var once_flag: String = GameState.FLAG_PHOTO_INVESTIGATED
@export_multiline var repeat_message: String = ""


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _uses_repeat_dialog():
		return _lines_from(repeat_message)
	return []


func can_interact(interactor: Node) -> bool:
	if not super.can_interact(interactor):
		return false
	if _uses_repeat_dialog():
		return not _lines_from(repeat_message).is_empty()
	return not _lines_from(intro_message).is_empty()


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	if _uses_repeat_dialog():
		return ""
	_run_first_investigation(interactor)
	return ""


func _uses_repeat_dialog() -> bool:
	return not once_flag.is_empty() and GameState != null and GameState.has_flag(once_flag)


func _run_first_investigation(interactor: Node) -> void:
	_first_investigation_flow(interactor)


func _first_investigation_flow(interactor: Node) -> void:
	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return

	var intro_lines := _lines_from(intro_message)
	if not intro_lines.is_empty():
		await player_interactor.play_monologue_lines(intro_lines)

	player_interactor.show_choice(
		choice_prompt,
		[
			{"id": CHOICE_YES, "label": GameText.CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.CHOICE_NO},
		],
		_on_choice.bind(player_interactor),
	)


func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	match choice_id:
		CHOICE_YES:
			_play_detail(player_interactor)
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _play_detail(player_interactor: PlayerInteractor) -> void:
	var detail_lines := _lines_from(detail_message)
	if detail_lines.is_empty():
		player_interactor.hide_text_immediately()
		_mark_investigated()
		return
	await player_interactor.play_monologue_lines(detail_lines)
	_mark_investigated()


func _mark_investigated() -> void:
	if once_flag.is_empty() or GameState == null:
		return
	GameState.set_flag(once_flag)


func _lines_from(source_message: String) -> Array[DialogLine]:
	var lines := PackedStringArray()
	for line in source_message.split("\n", false):
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue
		lines.append(stripped)
	return DialogTextLoader.lines_from_strings(lines)


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

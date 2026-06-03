extends Interactable
class_name PhotoFrameInvestigateItem

const CHOICE_YES := "yes"
const CHOICE_NO := "no"
const MEMORY_RELIEF_SFX: AudioStream = preload("res://audios/鍵を開ける1.mp3")

@export_multiline var intro_message: String = ""
@export_file("*.txt") var intro_message_file_path: String = ""
@export_multiline var detail_message: String = ""
@export_file("*.txt") var detail_message_file_path: String = ""
@export var choice_prompt: String = GameText.PHOTO_FRAME_CHOICE_PROMPT
@export var once_flag: String = GameState.FLAG_PHOTO_INVESTIGATED
@export_multiline var repeat_message: String = ""
@export_file("*.txt") var repeat_message_file_path: String = ""
@export var memory_relief_sfx: AudioStream = MEMORY_RELIEF_SFX
@export_range(-40.0, 12.0, 0.5) var memory_relief_sfx_volume_db: float = 0.0


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _uses_repeat_dialog():
		return _load_dialog_lines(repeat_message, repeat_message_file_path)
	return []


func can_interact(interactor: Node) -> bool:
	if not super.can_interact(interactor):
		return false
	if _uses_repeat_dialog():
		return not _load_dialog_lines(repeat_message, repeat_message_file_path).is_empty()
	return not _load_dialog_lines(intro_message, intro_message_file_path).is_empty()


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
	var player := interactor as CharacterBody2D
	if player_interactor == null:
		_set_player_controls_locked(player, false)
		return

	_set_player_controls_locked(player, true)

	var intro_lines := _load_dialog_lines(intro_message, intro_message_file_path)
	if not intro_lines.is_empty():
		await player_interactor.play_monologue_lines(intro_lines)

	player_interactor.show_choice(
		choice_prompt,
		[
			{"id": CHOICE_YES, "label": GameText.CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.CHOICE_NO},
		],
		_on_choice.bind(player_interactor, player),
	)


func _on_choice(choice_id: String, player_interactor: PlayerInteractor, player: CharacterBody2D) -> void:
	match choice_id:
		CHOICE_YES:
			await _play_detail(player_interactor)
			_set_player_controls_locked(player, false)
		CHOICE_NO:
			player_interactor.hide_text_immediately()
			_set_player_controls_locked(player, false)


func _play_detail(player_interactor: PlayerInteractor) -> void:
	var detail_lines := _load_dialog_lines(detail_message, detail_message_file_path)
	if detail_lines.is_empty():
		player_interactor.hide_text_immediately()
		_mark_investigated()
		return
	await player_interactor.play_monologue_lines(detail_lines)
	_play_memory_relief_sfx()
	_mark_investigated()


func _mark_investigated() -> void:
	if once_flag.is_empty() or GameState == null:
		return
	GameState.set_flag(once_flag)


func _load_dialog_lines(source_message: String, file_path: String) -> Array[DialogLine]:
	if not file_path.is_empty():
		return DialogTextLoader.load_dialog_lines(file_path, _message_as_line_array(source_message))
	return DialogTextLoader.lines_from_strings(_message_as_line_array(source_message))


func _message_as_line_array(source_message: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in source_message.split("\n", false):
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue
		lines.append(stripped)
	return lines


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor


func _set_player_controls_locked(player: CharacterBody2D, locked: bool) -> void:
	if player == null:
		return
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)


func _play_memory_relief_sfx() -> void:
	if memory_relief_sfx == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = memory_relief_sfx
	player.volume_db = memory_relief_sfx_volume_db
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()

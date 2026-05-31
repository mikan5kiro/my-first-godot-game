extends Interactable
class_name InteractableDoor

@export_file("*.tscn") var target_scene: String = "res://scenes/客厅.tscn"
@export var spawn_marker_name: String = "Spawn_FromWorkshop"
@export var transition_delay_after_sfx: float = 0.12
@export var door_sfx: AudioStream
@export var play_close_sfx: bool = true

@export_group("Lock")
@export var unlock_flag: String = ""
@export_multiline var blocked_message: String = ""
@export var blocked_once_flag: String = ""
@export_multiline var blocked_repeat_message: String = ""

var _is_activating: bool = false
var _blocked_dialog_lines: Array[DialogLine] = []
var _blocked_repeat_dialog_lines: Array[DialogLine] = []


func _ready() -> void:
	_reload_blocked_dialog_lines()


func get_interaction_priority() -> int:
	return 1


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _is_unlocked():
		return []
	if _uses_blocked_repeat_dialog():
		return _blocked_repeat_dialog_lines
	return _blocked_dialog_lines


func can_interact(interactor: Node) -> bool:
	if _is_activating:
		return false
	if not super.can_interact(interactor):
		return false
	if not _is_unlocked():
		return not get_interaction_dialog_lines().is_empty()
	return not target_scene.is_empty()


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	if not _is_unlocked():
		_on_blocked_interact()
		return ""
	if target_scene.is_empty():
		return ""

	_is_activating = true

	var facing_name := ""
	if interactor != null and interactor.has_method("get_facing_name"):
		facing_name = String(interactor.call("get_facing_name"))

	_start_transition(facing_name)
	return ""


func _start_transition(facing_name: String) -> void:
	await SceneTransition.transition_to_with_door_sfx(
		target_scene,
		spawn_marker_name,
		facing_name,
		door_sfx,
		transition_delay_after_sfx,
		play_close_sfx,
	)


func _on_blocked_interact() -> void:
	if _uses_blocked_repeat_dialog():
		return
	if blocked_once_flag.is_empty() or GameState == null:
		return
	GameState.set_flag(blocked_once_flag)


func _is_unlocked() -> bool:
	if unlock_flag.is_empty():
		return true
	if GameState == null:
		return false
	return GameState.has_flag(unlock_flag)


func _uses_blocked_repeat_dialog() -> bool:
	if blocked_once_flag.is_empty() or GameState == null:
		return false
	return GameState.has_flag(blocked_once_flag)


func _reload_blocked_dialog_lines() -> void:
	_blocked_dialog_lines = DialogTextLoader.lines_from_strings(_message_as_line_array(blocked_message))
	_blocked_repeat_dialog_lines = DialogTextLoader.lines_from_strings(
		_message_as_line_array(blocked_repeat_message)
	)


func _message_as_line_array(source_message: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in source_message.split("\n", false):
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue
		lines.append(stripped)
	return lines

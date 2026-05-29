extends Interactable
class_name InvestigateItem

@export_multiline var message: String = "这里有一些值得调查的内容。"
@export_file("*.txt") var message_file_path: String = ""
@export_group("Once Only")
@export var once_flag: String = ""
@export_multiline var repeat_message: String = ""
@export_file("*.txt") var repeat_message_file_path: String = ""
@export var effects: Array[StatEffect] = []

var _dialog_lines: Array[DialogLine] = []
var _repeat_dialog_lines: Array[DialogLine] = []


func _ready() -> void:
	_reload_dialog_lines()


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _uses_repeat_dialog():
		return _repeat_dialog_lines
	return _dialog_lines


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	var is_repeat := _uses_repeat_dialog()
	if not is_repeat and not once_flag.is_empty() and GameState != null:
		GameState.set_flag(once_flag)
	if not is_repeat:
		_apply_effects()
	return ""


func _uses_repeat_dialog() -> bool:
	if once_flag.is_empty() or GameState == null:
		return false
	return GameState.has_flag(once_flag)


func _reload_dialog_lines() -> void:
	_dialog_lines = _load_dialog_lines(message, message_file_path)
	_repeat_dialog_lines = _load_dialog_lines(repeat_message, repeat_message_file_path)


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


func _apply_effects() -> void:
	if GameState == null or effects.is_empty():
		return
	GameState.apply_effects(effects)

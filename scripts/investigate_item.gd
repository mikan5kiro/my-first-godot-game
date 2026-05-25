extends Interactable
class_name InvestigateItem

@export_multiline var message: String = "这里有一些值得调查的内容。"
@export_file("*.txt") var message_file_path: String = ""
@export var effects: Array[StatEffect] = []


func _ready() -> void:
	if not message_file_path.is_empty():
		message = DialogTextLoader.load_text(message_file_path, message)


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	_apply_effects()
	return message


func _apply_effects() -> void:
	if GameState == null or effects.is_empty():
		return
	GameState.apply_effects(effects)

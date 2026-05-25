extends Area2D
class_name InvestigateItem

@export_multiline var message: String = "这里有一些值得调查的内容。"
@export_file("*.txt") var message_file_path: String = ""
@export_enum("any", "up", "down", "left", "right") var required_facing: String = "any"

func _ready() -> void:
	if not message_file_path.is_empty():
		message = DialogTextLoader.load_text(message_file_path, message)


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	return message

func can_interact(interactor: Node) -> bool:
	if required_facing != "any":
		if interactor == null or not interactor.has_method("get_facing_name"):
			return false
		var facing_name := String(interactor.call("get_facing_name"))
		if facing_name != required_facing:
			return false
	return true

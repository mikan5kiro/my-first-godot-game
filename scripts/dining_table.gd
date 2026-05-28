extends Interactable
class_name DiningTableInteractable

@export_multiline var message: String = "餐桌。"


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	return message

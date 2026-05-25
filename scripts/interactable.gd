extends Area2D
class_name Interactable

## 可交互物体基类：调查物、门、NPC 等统一继承此类。

@export_enum("any", "up", "down", "left", "right") var required_facing: String = "any"


func get_interaction_priority() -> int:
	return 0


func can_interact(interactor: Node) -> bool:
	if required_facing == "any":
		return true
	if interactor == null or not interactor.has_method("get_facing_name"):
		return false
	return String(interactor.call("get_facing_name")) == required_facing


## 返回非空字符串时 PlayerInteractor 会显示对话框；返回空字符串表示静默执行。
func interact(_interactor: Node) -> String:
	push_warning("%s.interact() 未实现" % name)
	return ""

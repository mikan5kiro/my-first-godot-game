extends Resource
class_name ItemData

## 物品定义：显示名、检视文案、图标等。

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var inspect_text: String = ""
@export var icon: Texture2D
@export var is_food: bool = false
@export_range(0, 100, 1) var hunger_restore: int = 0


func can_use() -> bool:
	return is_food


func get_use_blocked_message() -> String:
	if is_food:
		return "需要到餐桌旁才能使用。"
	return ""


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not id.is_empty():
		return id
	return "未命名物品"


func get_inspect_text() -> String:
	if not inspect_text.is_empty():
		return inspect_text
	return get_display_name() + "。"

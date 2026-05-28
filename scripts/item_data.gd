extends Resource
class_name ItemData

## 物品定义：显示名、检视文案、图标等。

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var inspect_text: String = ""
@export var icon: Texture2D
@export var is_food: bool = false
@export var is_phone: bool = false
@export var is_fridge_storable: bool = false
@export var fridge_content_name: String = ""
@export_range(0, 100, 1) var hunger_restore: int = 0


func can_use() -> bool:
	return is_food or is_phone or is_fridge_storable


func get_use_blocked_message() -> String:
	if is_food:
		return "需要到餐桌旁才能使用。"
	if is_fridge_storable:
		return "需要到冰箱旁才能使用。"
	return ""


func get_fridge_content_name() -> String:
	if not fridge_content_name.is_empty():
		return fridge_content_name
	return get_display_name()


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not id.is_empty():
		return id
	return "未命名物品"


func get_inspect_text() -> String:
	var text: String
	if not inspect_text.is_empty():
		text = inspect_text
	else:
		text = get_display_name() + "。"
	if is_fridge_storable and not text.contains("需要放进冰箱"):
		text += "需要放进冰箱。"
	return text

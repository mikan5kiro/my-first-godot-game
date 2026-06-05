extends Resource
class_name ItemData

## 物品定义：显示名、检视文案、图标等。

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var inspect_text: String = ""
@export var icon: Texture2D
@export var is_phone: bool = false
@export var is_meal: bool = false


func is_meal_item() -> bool:
	return is_meal or id == "meal" or id == "delivery"


func can_use() -> bool:
	return is_phone or is_meal_item()


func get_use_blocked_message() -> String:
	if is_meal_item():
		return GameText.MEAL_USE_NEED_TABLE
	return ""


func get_display_name() -> String:
	if not display_name.is_empty():
		return _localize_text(display_name)
	if not id.is_empty():
		return id
	return _localize_text("common.unnamed_item")


func get_inspect_text() -> String:
	if not inspect_text.is_empty():
		return _localize_text(inspect_text)
	return _localize_text("common.inspect_suffix") % get_display_name()


static func _localize_text(text: String) -> String:
	if LanguageSwitch != null:
		return LanguageSwitch.localize_text(text)
	return TranslationServer.translate(text)

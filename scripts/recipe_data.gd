extends Resource
class_name RecipeData

## 食谱：所需食材名称 + 产出物品。

@export var id: String = ""
@export var ingredients: PackedStringArray = PackedStringArray()
@export var result_item: ItemData


func get_result_name() -> String:
	if result_item != null:
		return result_item.get_display_name()
	if not id.is_empty():
		return id
	if LanguageSwitch != null:
		return LanguageSwitch.translate_text("common.unknown_recipe")
	return TranslationServer.translate("common.unknown_recipe")

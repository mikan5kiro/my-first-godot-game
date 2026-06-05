class_name GameText
extends RefCounted

## 游戏文案统一入口（翻译 key + 运行时取文案）。
## - 单行提示：通过静态属性访问，内部走 TranslationServer
## - 多行旁白 / 引导：通过 *_LINES 静态属性；开场见 scripts/intro_dialogue.gd

const _WORKSHOP_HUNGER_LINE_KEYS: PackedStringArray = [
	"narrative.workshop.hunger.01",
	"narrative.workshop.hunger.02",
	"narrative.workshop.hunger.03",
	"narrative.workshop.hunger.04",
	"narrative.workshop.hunger.05",
	"narrative.workshop.hunger.06",
	"narrative.workshop.hunger.07",
]

const _DELIVERY_ARRIVAL_LINE_KEYS: PackedStringArray = [
	"narrative.delivery.arrival.01",
]

const _DELIVERY_COOKING_LINE_KEYS: PackedStringArray = [
	"narrative.delivery.cooking.01",
	"narrative.delivery.cooking.02",
	"narrative.delivery.cooking.03",
	"narrative.delivery.cooking.04",
	"narrative.delivery.cooking.05",
	"narrative.delivery.cooking.06",
	"narrative.delivery.cooking.07",
]

const _FOOD_ARRIVAL_LINE_KEYS: PackedStringArray = [
	"narrative.food.arrival.01",
]

const _KITCHEN_AFTERNOON_LINE_KEYS: PackedStringArray = [
	"narrative.kitchen.afternoon.01",
	"narrative.kitchen.afternoon.02",
]

const _PHOTO_FRAME_MEMORY_LINE_ENTRIES: PackedStringArray = [
	"narrative.photo.memory.01",
	"narrative.photo.memory.02",
	"narrative.photo.memory.03",
	"[pause 1.7]",
	"narrative.photo.memory.04",
	"narrative.photo.memory.05",
	"[pause 0.7]",
	"narrative.photo.memory.06",
	"narrative.photo.memory.07",
	"[pause 1.2]",
	"narrative.photo.memory.08",
]


static var WORKSHOP_HUNGER_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_WORKSHOP_HUNGER_LINE_KEYS)


static var DELIVERY_ARRIVAL_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_DELIVERY_ARRIVAL_LINE_KEYS)


static var DELIVERY_COOKING_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_DELIVERY_COOKING_LINE_KEYS)


static var FOOD_ARRIVAL_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_FOOD_ARRIVAL_LINE_KEYS)


static var KITCHEN_AFTERNOON_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_KITCHEN_AFTERNOON_LINE_KEYS)


static var PHOTO_FRAME_MEMORY_LINES: PackedStringArray:
	get:
		return _lines_from_entries(_PHOTO_FRAME_MEMORY_LINE_ENTRIES)


static var NOT_MEAL_TIME: String:
	get:
		return _tr("common.not_meal_time")


static var ROOM_DOOR_UNLOCK_PROMPT: String:
	get:
		return _tr("room.door.unlock_prompt")


static var PHOTO_FRAME_CHOICE_PROMPT: String:
	get:
		return _tr("photo.frame.choice_prompt")


static var PHONE_PROMPT: String:
	get:
		return _tr("phone.prompt")


static var PHONE_CHOICE_DELIVERY: String:
	get:
		return _tr("phone.choice.delivery")


static var PHONE_CHOICE_BUY_INGREDIENTS: String:
	get:
		return _tr("phone.choice.buy_ingredients")


static var PHONE_DELIVERY_ORDERED: String:
	get:
		return _tr("phone.delivery.ordered")


static var PHONE_FOOD_ORDERED: String:
	get:
		return _tr("phone.food.ordered")


static var PHONE_DELIVERY_AT_DOOR: String:
	get:
		return _tr("phone.delivery.at_door")


static var PHONE_DELIVERY_IN_TRANSIT: String:
	get:
		return _tr("phone.delivery.in_transit")


static var PHONE_DELIVERY_UNFINISHED: String:
	get:
		return _tr("phone.delivery.unfinished")


static var PHONE_DELIVERY_NO_MONEY: String:
	get:
		return _tr("phone.delivery.no_money")


static var PHONE_FOOD_AT_DOOR: String:
	get:
		return _tr("phone.food.at_door")


static var PHONE_FOOD_IN_TRANSIT: String:
	get:
		return _tr("phone.food.in_transit")


static var PHONE_FOOD_ALREADY_BOUGHT: String:
	get:
		return _tr("phone.food.already_bought")


static var PHONE_FOOD_NO_MONEY: String:
	get:
		return _tr("phone.food.no_money")


static var DELIVERY_PICKUP_OBTAINED: String:
	get:
		return _tr("delivery.pickup.obtained")


static var FOOD_PICKUP_OBTAINED: String:
	get:
		return _tr("food.pickup.obtained")


static var MEAL_EATEN: String:
	get:
		return _tr("meal.eaten")


static var MEAL_COOKED: String:
	get:
		return _tr("meal.cooked")


static var FOOD_SUPPLY_EMPTY: String:
	get:
		return _tr("food.supply.empty")


static var FOOD_SUPPLY_COUNT: String:
	get:
		return _tr("food.supply.count")


static var DINING_TABLE_PROMPT: String:
	get:
		return _tr("dining_table.prompt")


static var CHOICE_YES: String:
	get:
		return _tr("choice.yes")


static var CHOICE_NO: String:
	get:
		return _tr("choice.no")


static var STOVE_LABEL: String:
	get:
		return _tr("stove.label")


static var STOVE_COOK_PROMPT: String:
	get:
		return _tr("stove.cook_prompt")


static var STOVE_OFF_MEAL_TIME: String:
	get:
		return _tr("stove.off_meal_time")


static var STOVE_WAIT_UNTIL: String:
	get:
		return _tr("stove.wait_until")


static var MEAL_USE_NEED_TABLE: String:
	get:
		return _tr("meal.use.need_table")


static var ENDING_DOOR_PROMPT: String:
	get:
		return _tr("ending.door.prompt")


static var ENDING_DOOR_READY_PROMPT: String:
	get:
		return _tr("ending.door.ready_prompt")


static var ENDING_CHOICE_YES: String:
	get:
		return _tr("ending.choice.yes")


static var ENDING_CHOICE_NO: String:
	get:
		return _tr("ending.choice.no")


static var ENDING_DISPLAY_TEXT: String:
	get:
		return _tr("ending.display_text")


static func food_pickup_obtained(meals: int) -> String:
	return FOOD_PICKUP_OBTAINED % meals


static func food_supply_count(meals: int) -> String:
	return FOOD_SUPPLY_COUNT % meals


static func stove_wait_until(next_meal_name: String) -> String:
	return STOVE_WAIT_UNTIL % next_meal_name


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func _lines_from_keys(keys: PackedStringArray) -> PackedStringArray:
	var lines := PackedStringArray()
	for key in keys:
		lines.append(_tr(key))
	return lines


static func _lines_from_entries(entries: PackedStringArray) -> PackedStringArray:
	var lines := PackedStringArray()
	for entry in entries:
		if entry.begins_with("["):
			lines.append(entry)
		else:
			lines.append(_tr(entry))
	return lines

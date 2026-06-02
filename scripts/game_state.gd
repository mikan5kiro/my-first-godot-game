extends Node

## 全局游戏状态（Autoload: GameState）。
## 饥饿度、状态（sanity）、金钱、天数/时段、剧情 flag 的唯一数据源。

signal stats_changed
signal time_changed(day: int, period: TimePeriod)
signal day_ended(day: int)
signal flag_changed(flag: String, enabled: bool)
signal inventory_changed
signal tasks_changed

enum TimePeriod {
	MORNING,
	NOON,
	AFTERNOON,
	EVENING,
	NIGHT,
}

const PERIOD_ORDER: Array[TimePeriod] = [
	TimePeriod.MORNING,
	TimePeriod.NOON,
	TimePeriod.AFTERNOON,
	TimePeriod.EVENING,
	TimePeriod.NIGHT,
]

const PERIOD_NAMES := {
	TimePeriod.MORNING: "morning",
	TimePeriod.NOON: "noon",
	TimePeriod.AFTERNOON: "afternoon",
	TimePeriod.EVENING: "evening",
	TimePeriod.NIGHT: "night",
}

const PERIOD_DISPLAY_NAMES := {
	TimePeriod.MORNING: "早晨",
	TimePeriod.NOON: "中午",
	TimePeriod.AFTERNOON: "下午",
	TimePeriod.EVENING: "傍晚",
	TimePeriod.NIGHT: "夜晚",
}

const FLAG_BEDROOM_INTRO := "bedroom_intro_played"
const FLAG_KITCHEN_UNLOCKED := "kitchen_unlocked"
const FLAG_KITCHEN_DOOR_BLOCKED_SEEN := "kitchen_door_blocked_seen"
const FLAG_ROOM_AREA_UNLOCKED := "room_area_unlocked"
const FLAG_ROOM_AREA_BLOCKED_SEEN := "room_area_blocked_seen"
const FLAG_PHOTO_INVESTIGATED := "photo_investigated"
const FLAG_DESK_INVESTIGATED := "desk_investigated"
const FLAG_BOOKSHELF_INVESTIGATED := "bookshelf_investigated"
const FLAG_WORKSHOP_HUNGER_PROMPT := "workshop_hunger_prompt_played"
const FLAG_WORKSHOP_HUNGER_PENDING := "workshop_hunger_pending"
const FLAG_DELIVERY_ORDERED := "delivery_ordered"
const FLAG_DELIVERY_WAITING_PICKUP := "delivery_waiting_pickup"
const FLAG_DELIVERY_PICKED_UP := "delivery_picked_up"
const FLAG_FOOD_SUPPLY_ORDERED := "food_supply_ordered"
const FLAG_FOOD_SUPPLY_WAITING_PICKUP := "food_supply_waiting_pickup"
const FLAG_DELIVERY_COOKING_PROMPT := "delivery_cooking_prompt_played"
const FLAG_KITCHEN_AFTERNOON_PROMPT := "kitchen_afternoon_prompt_played"
const FLAG_KITCHEN_AFTERNOON_PENDING := "kitchen_afternoon_pending"
const FLAG_STOVE_OFF_MEAL_TIME_PROMPT := "stove_off_meal_time_prompt_played"
const MEAL_ITEM: ItemData = preload("res://resources/items/meal.tres")
const DELIVERY_ITEM: ItemData = preload("res://resources/items/delivery.tres")
const SHINY_ITEM_ID := "shiny_thing"
const ITEM_OBTAINED_SFX: AudioStream = preload("res://audios/決定ボタンを押す26.mp3")
const SAVE_VERSION := 1
const ITEM_RESOURCE_PATH := "res://resources/items/%s.tres"

@export_group("Initial Values")
@export_range(0, 100, 1) var initial_hunger: int = 30
@export_range(0, 100, 1) var initial_sanity: int = 65
@export var initial_money: int = 200
@export var initial_food_meals: int = 0
@export var initial_day: int = 1
@export var initial_period: TimePeriod = TimePeriod.NOON
@export var initial_inventory: Array[ItemData] = []

@export_group("Food")
@export var buy_food_cost: int = 25
@export var buy_food_meals_amount: int = 3
@export var delivery_cost: int = 40
@export var order_arrival_delay_sec: float = 10.0
@export_range(0, 100, 1) var meal_hunger_restore: int = 50

@export_group("Hunger Rhythm")
@export_range(0, 100, 1) var hunger_not_hungry_threshold: int = 50
@export_range(0, 100, 1) var hunger_very_hungry_threshold: int = 20
@export_range(0, 100, 1) var period_hunger_decay: int = 10
@export_range(0, 100, 1) var meal_period_hunger_pulse: int = 35
@export_range(0, 100, 1) var missed_meal_hunger_penalty: int = 25

@export_group("Limits")
@export_range(0, 100, 1) var min_hunger: int = 0
@export_range(0, 100, 1) var max_hunger: int = 100
@export_range(0, 100, 1) var min_sanity: int = 0
@export_range(0, 100, 1) var max_sanity: int = 100

@export_group("Daily Settlement")
@export var daily_hunger_drain: int = 0
@export var daily_sanity_drain: int = 0

var hunger: int = 30
var sanity: int = 65
var money: int = 200
var food_meals: int = 0
var day: int = 1
var period: TimePeriod = TimePeriod.NOON
var flags: Dictionary = {}
var inventory_items: Array[ItemData] = []
var active_tasks: PackedStringArray = PackedStringArray()
var is_locked: bool = false
var _ate_current_meal_period: bool = false
var _bought_food_today: bool = false
var _item_obtained_sfx_player: AudioStreamPlayer


func _ready() -> void:
	_setup_item_obtained_sfx()
	reset_to_defaults()


static func period_to_name(value: TimePeriod) -> String:
	return PERIOD_NAMES.get(value, "morning")


static func period_to_display_name(value: TimePeriod) -> String:
	return PERIOD_DISPLAY_NAMES.get(value, "早晨")


func is_meal_time() -> bool:
	return period == TimePeriod.NOON or period == TimePeriod.EVENING


func get_next_meal_time_display_name() -> String:
	match period:
		TimePeriod.MORNING:
			return period_to_display_name(TimePeriod.NOON)
		TimePeriod.AFTERNOON:
			return period_to_display_name(TimePeriod.EVENING)
		TimePeriod.NIGHT:
			return "明天%s" % period_to_display_name(TimePeriod.NOON)
		_:
			return period_to_display_name(TimePeriod.NOON)


func get_hunger_label() -> String:
	return hunger_label_for(hunger)


func get_sanity_label() -> String:
	return sanity_label_for(sanity)


func get_money_label() -> String:
	return money_label_for(money)


func hunger_label_for(value: int) -> String:
	if value >= hunger_not_hungry_threshold:
		return "不饿"
	if value >= hunger_very_hungry_threshold:
		return "饿了"
	return "很饿"


func sanity_label_for(value: int) -> String:
	if value >= 80:
		return "乐观"
	if value >= 50:
		return "普通"
	if value >= 20:
		return "忧郁"
	return "？？？"


func money_label_for(value: int) -> String:
	return "%d米" % value


func get_time_label_for(day_value: int, period_value: TimePeriod) -> String:
	return "第 %d 天 / %s" % [day_value, period_to_display_name(period_value)]


static func period_from_name(name: String) -> TimePeriod:
	for key in PERIOD_NAMES:
		if PERIOD_NAMES[key] == name:
			return key
	return TimePeriod.NOON


func to_save_data() -> Dictionary:
	var inventory_ids: PackedStringArray = []
	for item in inventory_items:
		if item != null and not item.id.is_empty():
			inventory_ids.append(item.id)

	return {
		"version": SAVE_VERSION,
		"hunger": hunger,
		"sanity": sanity,
		"money": money,
		"food_meals": food_meals,
		"day": day,
		"period": period_to_name(period),
		"flags": flags.duplicate(),
		"inventory": inventory_ids,
		"tasks": active_tasks.duplicate(),
		"ate_current_meal_period": _ate_current_meal_period,
		"bought_food_today": _bought_food_today,
	}


func apply_save_data(data: Dictionary) -> void:
	hunger = int(data.get("hunger", initial_hunger))
	sanity = int(data.get("sanity", initial_sanity))
	money = int(data.get("money", initial_money))
	food_meals = int(data.get("food_meals", initial_food_meals))
	day = int(data.get("day", initial_day))
	period = period_from_name(str(data.get("period", period_to_name(initial_period))))
	flags = data.get("flags", {}).duplicate()
	active_tasks = PackedStringArray(data.get("tasks", []))
	_ate_current_meal_period = bool(data.get("ate_current_meal_period", false))
	_bought_food_today = bool(data.get("bought_food_today", false))
	is_locked = false

	inventory_items.clear()
	for item_id in data.get("inventory", []):
		var resource_path := ITEM_RESOURCE_PATH % String(item_id)
		if ResourceLoader.exists(resource_path):
			inventory_items.append(load(resource_path))

	stats_changed.emit()
	time_changed.emit(day, period)
	inventory_changed.emit()
	tasks_changed.emit()


func get_status_labels_from_data(data: Dictionary, player_name: String = "主人公") -> Dictionary:
	if data.is_empty():
		return {
			"player_name": "空档案",
			"time": "--",
			"hunger": "--",
			"sanity": "--",
			"money": "--",
		}

	var period_value := period_from_name(str(data.get("period", period_to_name(initial_period))))
	return {
		"player_name": str(data.get("player_name", player_name)),
		"time": get_time_label_for(int(data.get("day", initial_day)), period_value),
		"hunger": hunger_label_for(int(data.get("hunger", initial_hunger))),
		"sanity": sanity_label_for(int(data.get("sanity", initial_sanity))),
		"money": money_label_for(int(data.get("money", initial_money))),
	}


func get_money_description() -> String:
	if money >= 500:
		return "宽裕"
	if money >= 100:
		return "够用"
	if money >= 30:
		return "紧张"
	return "见底"


func get_food_meals_label() -> String:
	if food_meals >= 7:
		return "够用"
	if food_meals >= 3:
		return "不多了"
	if food_meals >= 1:
		return "快没了"
	return "没有了"


func get_food_supply_text() -> String:
	if food_meals <= 0:
		return GameText.FOOD_SUPPLY_EMPTY
	return GameText.food_supply_count(food_meals)


func can_cook() -> bool:
	return food_meals > 0


func can_eat() -> bool:
	return get_prepared_meal() != null


func get_prepared_meal() -> ItemData:
	for item in inventory_items:
		if _is_meal_item(item):
			return item
	return null


func _is_meal_item(item: ItemData) -> bool:
	return item != null and item.is_meal_item()


func is_delivery_item(item: ItemData) -> bool:
	return item != null and item.id == "delivery"


func should_play_delivery_cooking_prompt() -> bool:
	return has_flag(FLAG_DELIVERY_PICKED_UP) and not has_flag(FLAG_DELIVERY_COOKING_PROMPT)


func complete_delivery_cooking_prompt() -> void:
	set_flag(FLAG_DELIVERY_COOKING_PROMPT)
	set_flag(FLAG_KITCHEN_UNLOCKED)


func cook_meal() -> bool:
	if is_locked or food_meals <= 0 or not is_meal_time():
		return false
	food_meals -= 1
	add_inventory_item(MEAL_ITEM, false)
	stats_changed.emit()
	return true


func eat_meal(item: ItemData) -> bool:
	if is_locked or not _is_meal_item(item) or not is_meal_time():
		return false
	if find_inventory_index(item) < 0:
		return false
	remove_inventory_item(item)
	_ate_current_meal_period = true
	add_stat(&"hunger", meal_hunger_restore)
	advance_period()
	return true


func has_bought_food_today() -> bool:
	return _bought_food_today


func can_buy_food_supply() -> bool:
	if _bought_food_today:
		return false
	if has_flag(FLAG_FOOD_SUPPLY_ORDERED) or has_flag(FLAG_FOOD_SUPPLY_WAITING_PICKUP):
		return false
	return money >= buy_food_cost


func is_kitchen_unlocked() -> bool:
	return has_flag(FLAG_KITCHEN_UNLOCKED)


func buy_food_supply() -> bool:
	if is_locked or not can_buy_food_supply():
		return false
	money -= buy_food_cost
	_bought_food_today = true
	set_flag(FLAG_FOOD_SUPPLY_ORDERED)
	PendingArrivalController.schedule_food_arrival()
	stats_changed.emit()
	return true


func is_phone_delivery_unlocked() -> bool:
	return has_flag(FLAG_WORKSHOP_HUNGER_PROMPT)


func can_order_delivery() -> bool:
	if money < delivery_cost:
		return false
	if has_flag(FLAG_DELIVERY_ORDERED):
		return false
	if has_flag(FLAG_DELIVERY_WAITING_PICKUP):
		return false
	return find_inventory_index_by_id(DELIVERY_ITEM.id) < 0


func workshop_investigations_complete() -> bool:
	return has_flag(FLAG_DESK_INVESTIGATED)


func should_trigger_workshop_hunger_on_exit() -> bool:
	return workshop_investigations_complete() and not has_flag(FLAG_WORKSHOP_HUNGER_PROMPT)


func mark_stove_off_meal_time_prompt_played() -> void:
	set_flag(FLAG_STOVE_OFF_MEAL_TIME_PROMPT)


func should_trigger_kitchen_afternoon_on_exit() -> bool:
	return has_flag(FLAG_STOVE_OFF_MEAL_TIME_PROMPT) \
		and not has_flag(FLAG_KITCHEN_AFTERNOON_PROMPT)


func is_workshop_delivery_quest_active() -> bool:
	return has_flag(FLAG_WORKSHOP_HUNGER_PROMPT) \
		and not has_flag(FLAG_DELIVERY_ORDERED) \
		and not has_flag(FLAG_DELIVERY_WAITING_PICKUP) \
		and not has_flag(FLAG_DELIVERY_PICKED_UP)


func order_delivery() -> bool:
	if is_locked or not can_order_delivery() or not is_meal_time():
		return false
	money -= delivery_cost
	set_flag(FLAG_DELIVERY_ORDERED)
	PendingArrivalController.schedule_delivery_arrival()
	stats_changed.emit()
	return true


func mark_delivery_waiting_pickup() -> void:
	clear_flag(FLAG_DELIVERY_ORDERED)
	set_flag(FLAG_DELIVERY_WAITING_PICKUP)


func mark_food_supply_waiting_pickup() -> void:
	clear_flag(FLAG_FOOD_SUPPLY_ORDERED)
	set_flag(FLAG_FOOD_SUPPLY_WAITING_PICKUP)


func complete_delivery_pickup(play_item_sfx: bool = true) -> void:
	add_inventory_item(DELIVERY_ITEM, play_item_sfx)
	clear_flag(FLAG_DELIVERY_WAITING_PICKUP)
	set_flag(FLAG_DELIVERY_PICKED_UP)


func complete_food_supply_pickup() -> void:
	food_meals += buy_food_meals_amount
	clear_flag(FLAG_FOOD_SUPPLY_WAITING_PICKUP)
	stats_changed.emit()


func reset_to_defaults() -> void:
	hunger = initial_hunger
	sanity = initial_sanity
	money = initial_money
	food_meals = initial_food_meals
	day = initial_day
	period = initial_period
	flags = {}
	inventory_items = _duplicate_inventory(initial_inventory)
	active_tasks = PackedStringArray()
	is_locked = false
	_ate_current_meal_period = false
	_bought_food_today = false
	stats_changed.emit()
	time_changed.emit(day, period)
	inventory_changed.emit()
	tasks_changed.emit()


func apply_effect(effect: StatEffect) -> void:
	if effect == null or is_locked:
		return

	var stats_dirty := false
	if effect.hunger_delta != 0:
		hunger = clampi(hunger + effect.hunger_delta, min_hunger, max_hunger)
		stats_dirty = true
	if effect.sanity_delta != 0:
		sanity = clampi(sanity + effect.sanity_delta, min_sanity, max_sanity)
		stats_dirty = true
	if effect.money_delta != 0:
		money += effect.money_delta
		stats_dirty = true

	for flag_name in effect.set_flags:
		set_flag(String(flag_name), true)

	for flag_name in effect.clear_flags:
		clear_flag(String(flag_name))

	if stats_dirty:
		stats_changed.emit()

	if effect.advance_time:
		advance_period()


func apply_effects(effects: Array) -> void:
	for effect in effects:
		if effect is StatEffect:
			apply_effect(effect)


func set_stat(stat_name: StringName, value: int) -> void:
	if is_locked:
		return

	match stat_name:
		&"hunger":
			hunger = clampi(value, min_hunger, max_hunger)
		&"sanity":
			sanity = clampi(value, min_sanity, max_sanity)
		&"money":
			money = value
		_:
			push_warning("GameState: 未知属性 '%s'" % stat_name)
			return

	stats_changed.emit()


func add_stat(stat_name: StringName, delta: int) -> void:
	match stat_name:
		&"hunger":
			set_stat(stat_name, hunger + delta)
		&"sanity":
			set_stat(stat_name, sanity + delta)
		&"money":
			set_stat(stat_name, money + delta)
		_:
			push_warning("GameState: 未知属性 '%s'" % stat_name)


func set_flag(flag_name: String, enabled: bool = true) -> bool:
	if flag_name.is_empty():
		return false
	var already_enabled: bool = bool(flags.get(flag_name, false))
	if already_enabled == enabled:
		return false
	flags[flag_name] = enabled
	flag_changed.emit(flag_name, enabled)
	return true


func clear_flag(flag_name: String) -> bool:
	if flag_name.is_empty() or not flags.has(flag_name):
		return false
	flags.erase(flag_name)
	flag_changed.emit(flag_name, false)
	return true


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func set_inventory_items(items: Array[ItemData]) -> void:
	inventory_items = _duplicate_inventory(items)
	inventory_changed.emit()


func add_inventory_item(item: ItemData, play_sfx: bool = true) -> void:
	if item == null:
		return
	inventory_items.append(item)
	inventory_changed.emit()
	if play_sfx:
		_play_item_obtained_sfx()


func remove_inventory_item(item: ItemData) -> bool:
	var index := find_inventory_index(item)
	if index < 0:
		return false
	inventory_items.remove_at(index)
	inventory_changed.emit()
	return true


func remove_inventory_item_by_id(item_id: String) -> bool:
	var index := find_inventory_index_by_id(item_id)
	if index < 0:
		return false
	inventory_items.remove_at(index)
	inventory_changed.emit()
	return true


func find_inventory_index(item: ItemData) -> int:
	if item == null:
		return -1
	for index in inventory_items.size():
		if _items_match(inventory_items[index], item):
			return index
	return -1


func find_inventory_index_by_id(item_id: String) -> int:
	if item_id.is_empty():
		return -1
	for index in inventory_items.size():
		var current := inventory_items[index]
		if current != null and current.id == item_id:
			return index
	return -1


func has_shiny_thing() -> bool:
	return find_inventory_index_by_id(SHINY_ITEM_ID) >= 0


func has_photo_investigated() -> bool:
	return has_flag(FLAG_PHOTO_INVESTIGATED)


func clear_inventory() -> void:
	if inventory_items.is_empty():
		return
	inventory_items = []
	inventory_changed.emit()


func _duplicate_inventory(items: Array[ItemData]) -> Array[ItemData]:
	return items.duplicate()


func _items_match(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false
	if not a.id.is_empty() and not b.id.is_empty():
		return a.id == b.id
	return a == b


func set_tasks(tasks: PackedStringArray) -> void:
	active_tasks = tasks.duplicate()
	tasks_changed.emit()


func add_task(task_text: String) -> void:
	if task_text.is_empty():
		return
	active_tasks.append(task_text)
	tasks_changed.emit()


func remove_task(task_text: String) -> bool:
	var index: int = active_tasks.find(task_text)
	if index < 0:
		return false
	active_tasks.remove_at(index)
	tasks_changed.emit()
	return true


func clear_tasks() -> void:
	if active_tasks.is_empty():
		return
	active_tasks = PackedStringArray()
	tasks_changed.emit()


func advance_period() -> void:
	if is_locked:
		return

	var leaving_period := period
	_apply_period_leave_hunger(leaving_period)

	var period_index: int = PERIOD_ORDER.find(period)
	if period_index < 0:
		period_index = 0

	if period_index >= PERIOD_ORDER.size() - 1:
		end_day()
		return

	period = PERIOD_ORDER[period_index + 1]
	_apply_period_enter_hunger(period)
	stats_changed.emit()
	time_changed.emit(day, period)


func end_day() -> void:
	if is_locked:
		return

	var ended_day: int = day
	day_ended.emit(ended_day)

	if daily_hunger_drain != 0:
		hunger = clampi(hunger - daily_hunger_drain, min_hunger, max_hunger)
	if daily_sanity_drain != 0:
		sanity = clampi(sanity - daily_sanity_drain, min_sanity, max_sanity)

	day += 1
	period = TimePeriod.MORNING
	_bought_food_today = false
	_apply_period_enter_hunger(period)
	stats_changed.emit()
	time_changed.emit(day, period)


static func _is_meal_period(value: TimePeriod) -> bool:
	return value == TimePeriod.NOON or value == TimePeriod.EVENING


func _apply_period_leave_hunger(leaving_period: TimePeriod) -> void:
	if _is_meal_period(leaving_period) and not _ate_current_meal_period:
		_apply_hunger_change(-missed_meal_hunger_penalty)
	if period_hunger_decay > 0:
		_apply_hunger_change(-period_hunger_decay)


func _apply_period_enter_hunger(entering_period: TimePeriod) -> void:
	if not _is_meal_period(entering_period):
		return
	_apply_hunger_change(-meal_period_hunger_pulse)
	_ate_current_meal_period = false


func _apply_hunger_change(delta: int) -> void:
	if delta == 0:
		return
	hunger = clampi(hunger + delta, min_hunger, max_hunger)


func lock() -> void:
	is_locked = true


func unlock() -> void:
	is_locked = false


func _setup_item_obtained_sfx() -> void:
	_item_obtained_sfx_player = AudioStreamPlayer.new()
	_item_obtained_sfx_player.bus = &"Master"
	add_child(_item_obtained_sfx_player)


func _play_item_obtained_sfx() -> void:
	if _item_obtained_sfx_player == null or ITEM_OBTAINED_SFX == null:
		return
	_item_obtained_sfx_player.stream = ITEM_OBTAINED_SFX
	_item_obtained_sfx_player.play()


func play_item_obtained_sfx() -> void:
	_play_item_obtained_sfx()

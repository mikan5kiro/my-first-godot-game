extends Node

## 全局游戏状态（Autoload: GameState）。
## 饱食度、状态（sanity）、金钱、天数/时段、剧情 flag 的唯一数据源。

signal stats_changed
signal time_changed(day: int, period: TimePeriod)
signal day_ended(day: int)
signal flag_changed(flag: String, enabled: bool)
signal inventory_changed
signal tasks_changed

enum TimePeriod {
	MORNING,
	AFTERNOON,
	EVENING,
	NIGHT,
}

const PERIOD_ORDER: Array[TimePeriod] = [
	TimePeriod.MORNING,
	TimePeriod.AFTERNOON,
	TimePeriod.EVENING,
	TimePeriod.NIGHT,
]

const PERIOD_NAMES := {
	TimePeriod.MORNING: "morning",
	TimePeriod.AFTERNOON: "afternoon",
	TimePeriod.EVENING: "evening",
	TimePeriod.NIGHT: "night",
}

const PERIOD_DISPLAY_NAMES := {
	TimePeriod.MORNING: "早晨",
	TimePeriod.AFTERNOON: "下午",
	TimePeriod.EVENING: "傍晚",
	TimePeriod.NIGHT: "夜晚",
}

const FLAG_BEDROOM_INTRO := "bedroom_intro_played"
const FLAG_KITCHEN_UNLOCKED := "kitchen_unlocked"
const FLAG_KITCHEN_DOOR_BLOCKED_SEEN := "kitchen_door_blocked_seen"
const FLAG_ROOM_AREA_UNLOCKED := "room_area_unlocked"
const FLAG_ROOM_AREA_BLOCKED_SEEN := "room_area_blocked_seen"
const DEFAULT_PHONE_ITEM: ItemData = preload("res://resources/items/phone.tres")
const MEAL_ITEM: ItemData = preload("res://resources/items/meal.tres")
const ITEM_OBTAINED_SFX: AudioStream = preload("res://audios/決定ボタンを押す26.mp3")

@export_group("Initial Values")
@export_range(0, 100, 1) var initial_hunger: int = 35
@export_range(0, 100, 1) var initial_sanity: int = 65
@export var initial_money: int = 200
@export var initial_food_days: int = 4
@export var initial_day: int = 1
@export var initial_period: TimePeriod = TimePeriod.MORNING
@export var initial_inventory: Array[ItemData] = [DEFAULT_PHONE_ITEM]

@export_group("Food")
@export var buy_food_cost: int = 25
@export var buy_food_days_amount: int = 3
@export var delivery_cost: int = 40
@export_range(0, 100, 1) var meal_hunger_restore: int = 40

@export_group("Limits")
@export_range(0, 100, 1) var min_hunger: int = 0
@export_range(0, 100, 1) var max_hunger: int = 100
@export_range(0, 100, 1) var min_sanity: int = 0
@export_range(0, 100, 1) var max_sanity: int = 100

@export_group("Daily Settlement")
@export var daily_hunger_drain: int = 10
@export var daily_sanity_drain: int = 0

var hunger: int = 35
var sanity: int = 65
var money: int = 200
var food_days: int = 4
var day: int = 1
var period: TimePeriod = TimePeriod.MORNING
var flags: Dictionary = {}
var inventory_items: Array[ItemData] = []
var active_tasks: PackedStringArray = PackedStringArray()
var is_locked: bool = false
var _item_obtained_sfx_player: AudioStreamPlayer


func _ready() -> void:
	_setup_item_obtained_sfx()
	reset_to_defaults()


static func period_to_name(value: TimePeriod) -> String:
	return PERIOD_NAMES.get(value, "morning")


static func period_to_display_name(value: TimePeriod) -> String:
	return PERIOD_DISPLAY_NAMES.get(value, "早晨")


func get_hunger_label() -> String:
	if hunger >= 70:
		return "吃饱"
	if hunger >= 40:
		return "还行"
	if hunger >= 20:
		return "有点饿"
	return "很饿"


func get_sanity_label() -> String:
	if sanity >= 80:
		return "乐观"
	if sanity >= 50:
		return "普通"
	if sanity >= 20:
		return "忧郁"
	return "？？？"


func get_money_label() -> String:
	if money >= 500:
		return "宽裕"
	if money >= 100:
		return "够用"
	if money >= 30:
		return "紧张"
	return "见底"


func get_food_days_label() -> String:
	if food_days >= 7:
		return "够用"
	if food_days >= 3:
		return "不多了"
	if food_days >= 1:
		return "快没了"
	return "没有了"


func get_food_supply_text() -> String:
	if food_days <= 0:
		return "没有食材了。"
	return "自己做饭还能撑 %d 天。" % food_days


func can_cook() -> bool:
	return food_days > 0


func can_eat() -> bool:
	return get_prepared_meal() != null


func get_prepared_meal() -> ItemData:
	for item in inventory_items:
		if _is_meal_item(item):
			return item
	return null


func _is_meal_item(item: ItemData) -> bool:
	return item != null and item.is_meal_item()


func cook_meal() -> bool:
	if is_locked or food_days <= 0:
		return false
	food_days -= 1
	add_inventory_item(MEAL_ITEM, false)
	stats_changed.emit()
	return true


func eat_meal(item: ItemData) -> bool:
	if is_locked or not _is_meal_item(item):
		return false
	if find_inventory_index(item) < 0:
		return false
	remove_inventory_item(item)
	add_stat(&"hunger", meal_hunger_restore)
	return true


func can_buy_food_supply() -> bool:
	return money >= buy_food_cost


func buy_food_supply() -> bool:
	if is_locked or not can_buy_food_supply():
		return false
	money -= buy_food_cost
	food_days += buy_food_days_amount
	stats_changed.emit()
	return true


func can_order_delivery() -> bool:
	return money >= delivery_cost


func order_delivery() -> bool:
	if is_locked or not can_order_delivery():
		return false
	money -= delivery_cost
	add_stat(&"hunger", meal_hunger_restore)
	return true


func reset_to_defaults() -> void:
	hunger = initial_hunger
	sanity = initial_sanity
	money = initial_money
	food_days = initial_food_days
	day = initial_day
	period = initial_period
	flags = {}
	inventory_items = _duplicate_inventory(initial_inventory)
	active_tasks = PackedStringArray()
	is_locked = false
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

	var period_index: int = PERIOD_ORDER.find(period)
	if period_index < 0:
		period_index = 0

	if period_index >= PERIOD_ORDER.size() - 1:
		end_day()
		return

	period = PERIOD_ORDER[period_index + 1]
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
	stats_changed.emit()

	day += 1
	period = TimePeriod.MORNING
	time_changed.emit(day, period)


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

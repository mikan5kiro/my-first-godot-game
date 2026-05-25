extends Node

## 全局游戏状态（Autoload: GameState）。
## 饱食度、理智、金钱、天数/时段、剧情 flag 的唯一数据源。

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
const DEFAULT_PHONE_ITEM: ItemData = preload("res://resources/items/phone.tres")

@export_group("Initial Values")
@export_range(0, 100, 1) var initial_hunger: int = 80
@export_range(0, 100, 1) var initial_sanity: int = 100
@export var initial_money: int = 0
@export var initial_day: int = 1
@export var initial_period: TimePeriod = TimePeriod.MORNING
@export var initial_inventory: Array[ItemData] = [DEFAULT_PHONE_ITEM]

@export_group("Limits")
@export_range(0, 100, 1) var min_hunger: int = 0
@export_range(0, 100, 1) var max_hunger: int = 100
@export_range(0, 100, 1) var min_sanity: int = 0
@export_range(0, 100, 1) var max_sanity: int = 100

@export_group("Daily Settlement")
@export var daily_hunger_drain: int = 10
@export var daily_sanity_drain: int = 0

var hunger: int = 80
var sanity: int = 100
var money: int = 0
var day: int = 1
var period: TimePeriod = TimePeriod.MORNING
var flags: Dictionary = {}
var inventory_items: Array[ItemData] = []
var active_tasks: PackedStringArray = PackedStringArray()
var is_locked: bool = false


func _ready() -> void:
	reset_to_defaults()


static func period_to_name(value: TimePeriod) -> String:
	return PERIOD_NAMES.get(value, "morning")


static func period_to_display_name(value: TimePeriod) -> String:
	return PERIOD_DISPLAY_NAMES.get(value, "早晨")


func reset_to_defaults() -> void:
	hunger = initial_hunger
	sanity = initial_sanity
	money = initial_money
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


func add_inventory_item(item: ItemData) -> void:
	if item == null:
		return
	inventory_items.append(item)
	inventory_changed.emit()


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

class_name GameText
extends RefCounted

## 游戏事件文案统一入口。
## - 单行提示：改下方「单行提示」常量
## - 多行旁白 / 引导：改 dialogues/events/ 里对应 txt（@ 开头为角色台词）
##
## 多行旁白一览：
##   workshop_hunger_prompt.txt    引导：饿了，可以点外卖了
##   delivery_arrival.txt          外卖送到门口
##   delivery_cooking_prompt.txt   引导：吃完外卖，可以买食材了 / 厨房开放
##   food_arrival.txt              食材送到门口
##   kitchen_afternoon_prompt.txt  触发灶台「非饭点」对话后，离开厨房时的独白

const EVENTS_DIR := "res://dialogues/events/"

# --- 多行旁白 / 引导 ---
const FILE_WORKSHOP_HUNGER_PROMPT := EVENTS_DIR + "workshop_hunger_prompt.txt"
const FILE_DELIVERY_ARRIVAL := EVENTS_DIR + "delivery_arrival.txt"
const FILE_DELIVERY_COOKING_PROMPT := EVENTS_DIR + "delivery_cooking_prompt.txt"
const FILE_FOOD_ARRIVAL := EVENTS_DIR + "food_arrival.txt"
const FILE_KITCHEN_AFTERNOON_PROMPT := EVENTS_DIR + "kitchen_afternoon_prompt.txt"

# --- 单行提示：通用 ---
const NOT_MEAL_TIME := "现在不是饭点。"
const ROOM_DOOR_UNLOCK_PROMPT := "要使用闪闪发光的东西开门吗？"

# --- 单行提示：手机 ---
const PHONE_PROMPT := "要用手机做什么？"
const PHONE_CHOICE_DELIVERY := "点外卖（-%d）"
const PHONE_CHOICE_BUY_INGREDIENTS := "买食材（-%d）"
const PHONE_DELIVERY_ORDERED := "外卖点好了，在送到之前稍微等一下吧。"
const PHONE_FOOD_ORDERED := "食材订好了，在送到之前稍微等一下吧。"
const PHONE_DELIVERY_AT_DOOR := "外卖已经在门口了。"
const PHONE_DELIVERY_IN_TRANSIT := "外卖正在路上。"
const PHONE_DELIVERY_UNFINISHED := "之前的外卖还没吃。"
const PHONE_DELIVERY_NO_MONEY := "没钱点外卖了"
const PHONE_FOOD_AT_DOOR := "食材已经在门口了。"
const PHONE_FOOD_IN_TRANSIT := "食材正在路上。"
const PHONE_FOOD_ALREADY_BOUGHT := "今天已经买过食材了。"
const PHONE_FOOD_NO_MONEY := "没钱买食材了。"

# --- 单行提示：送达 / 取货 ---
const DELIVERY_PICKUP_OBTAINED := "获得外卖。"
const FOOD_PICKUP_OBTAINED := "收到食材，现在有 %d 顿食材。"

# --- 单行提示：吃饭 / 做饭 ---
const MEAL_EATEN := "吃完饭了。"
const MEAL_COOKED := "获得自己做的饭。"
const FOOD_SUPPLY_EMPTY := "没有食材了。"
const FOOD_SUPPLY_COUNT := "里面还有 %d 顿食材。"

# --- 单行提示：冰箱 / 餐桌 ---
const DINING_TABLE_PROMPT := "餐桌。要吃饭吗？"
const CHOICE_YES := "要"
const CHOICE_NO := "不要"

# --- 单行提示：灶台 ---
const STOVE_LABEL := "灶台。"
const STOVE_COOK_PROMPT := "灶台。要做饭吗？"
const STOVE_OFF_MEAL_TIME := "@虽然有食材，但还没到吃饭的时间。"
const STOVE_WAIT_UNTIL := "等%s再来做吧。"

# --- 单行提示：物品使用 ---
const MEAL_USE_NEED_TABLE := "需要到餐桌旁才能吃。"

# --- 单行提示：结局 ---
const ENDING_DOOR_PROMPT := "要离开这里吗？"
const ENDING_CHOICE_YES := "是"
const ENDING_CHOICE_NO := "不是"
const ENDING_DISPLAY_TEXT := "the end"


static func load_dialog(file_path: String) -> Array[DialogLine]:
	return DialogTextLoader.load_dialog_lines(file_path)


static func food_pickup_obtained(meals: int) -> String:
	return FOOD_PICKUP_OBTAINED % meals


static func food_supply_count(meals: int) -> String:
	return FOOD_SUPPLY_COUNT % meals


static func stove_wait_until(next_meal_name: String) -> String:
	return STOVE_WAIT_UNTIL % next_meal_name

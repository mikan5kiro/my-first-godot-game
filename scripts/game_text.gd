class_name GameText
extends RefCounted

## 游戏文案统一入口。
## - 单行提示：改下方「单行提示」常量
## - 多行旁白 / 引导：改下方 *_LINES 常量；开场见 scripts/intro_dialogue.gd

# --- 多行旁白 / 引导 ---
const WORKSHOP_HUNGER_LINES = [
	"@有点饿了。点个外卖吧。",
	"@附近的外卖都吃腻了。虽说一共也没几家。",
	"@虽然不太健康，但饭还是要吃的。",
	"@按时吃饭……好好照顾自己。",
	"@……",
	"#如果那个人在的话……",
	"现在可以使用手机点外卖了。",
]

const DELIVERY_ARRIVAL_LINES = [
	"@外卖到了。去门口拿一下吧。",
]

const DELIVERY_COOKING_LINES = [
	"@……",
	"@不好吃。",
	"@是不是也该买点食材自己做饭了呢……",
	"@以前都是和那个人一起去买的啊。",
	"@那个总是会顺手买一堆零食的人。",
	"@我不要去外面。用手机买就行了。",
	"现在可以使用手机买食材了。厨房已解锁。",
]

const FOOD_ARRIVAL_LINES = [
	"@食材到了。去门口拿一下吧。",
]

const KITCHEN_AFTERNOON_LINES = [
	"@还有时间，做点什么呢……",
	"@总之先回工作间吧。",
]

const PHOTO_FRAME_MEMORY_LINES = [
	"拿起相框，里面是一张两个人的合照。",
	"像是在游乐园的缆车上拍的，一个人笑得很开心，另一个人笑得有些拘谨。",
	"@……当时没想到这张照片会留下来。如果更认真一点拍就好了。",
	"[pause 1.7]",
	"@……嗯。",
	"@那些在这里留下的记忆，还好好地保存着。",
	"[pause 0.7]",
	"@那个曾经逃避离别，害怕面对孤身一人的我。",
	"@一定很难过吧。",
	"[pause 1.2]",
	"@但是，现在已经没事了。",
]

# --- 单行提示：通用 ---
const NOT_MEAL_TIME := "现在不是饭点。"
const ROOM_DOOR_UNLOCK_PROMPT := "要现在打开门吗？"
const PHOTO_FRAME_CHOICE_PROMPT := "要查看相框吗？"

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
const ENDING_DOOR_READY_PROMPT := "准备好告别这段回忆了吗？"
const ENDING_CHOICE_YES := "是"
const ENDING_CHOICE_NO := "不是"
const ENDING_DISPLAY_TEXT := "the end"


static func food_pickup_obtained(meals: int) -> String:
	return FOOD_PICKUP_OBTAINED % meals


static func food_supply_count(meals: int) -> String:
	return FOOD_SUPPLY_COUNT % meals


static func stove_wait_until(next_meal_name: String) -> String:
	return STOVE_WAIT_UNTIL % next_meal_name

extends RefCounted
class_name EventDialogue

const WORKSHOP_HUNGER_LINES := PackedStringArray([
	"@有点饿了。点个外卖吧。",
	"@附近的外卖都吃腻了。虽说一共也没几家。",
	"@虽然不太健康，但饭还是要吃的。",
	"@按时吃饭……好好照顾自己。",
	"@……",
	"#如果那个人在的话……",
	"现在可以使用手机点外卖了。",
])

const DELIVERY_ARRIVAL_LINES := PackedStringArray([
	"@外卖到了。去门口拿一下吧。",
])

const DELIVERY_COOKING_LINES := PackedStringArray([
	"@……",
	"@不好吃。",
	"@是不是也该买点食材自己做饭了呢……",
	"@以前都是和那个人一起去买的啊。",
	"@那个总是会顺手买一堆零食的人。",
	"@我不要去外面。用手机买就行了。",
	"现在可以使用手机买食材了。厨房已解锁。",
])

const FOOD_ARRIVAL_LINES := PackedStringArray([
	"@食材到了。去门口拿一下吧。",
])

const KITCHEN_AFTERNOON_LINES := PackedStringArray([
	"@还有时间，做点什么呢……",
	"@总之先回工作间吧。",
])

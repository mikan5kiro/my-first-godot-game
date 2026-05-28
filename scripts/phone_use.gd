class_name PhoneUse
extends RefCounted

const CHOICE_DELIVERY := "delivery"
const CHOICE_BUY_INGREDIENTS := "buy_ingredients"
const BEEF_ITEM: ItemData = preload("res://resources/items/beef.tres")


static func run_use(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	player_interactor.show_choice(
		"要用手机做什么？",
		[
			{"id": CHOICE_DELIVERY, "label": "点外卖"},
			{"id": CHOICE_BUY_INGREDIENTS, "label": "买食材"},
		],
		_on_choice.bind(player_interactor),
	)


static func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	match choice_id:
		CHOICE_DELIVERY:
			player_interactor.show_text("点外卖功能尚未开放。")
		CHOICE_BUY_INGREDIENTS:
			if GameState != null:
				GameState.add_inventory_item(BEEF_ITEM)
			player_interactor.show_text("已购入牛肉。")

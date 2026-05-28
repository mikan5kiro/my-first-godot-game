class_name PhoneUse
extends RefCounted

const CHOICE_DELIVERY := "delivery"
const CHOICE_BUY_INGREDIENTS := "buy_ingredients"


static func run_use(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	player_interactor.show_choice(
		"要用手机做什么？",
		[
			{
				"id": CHOICE_DELIVERY,
				"label": "点外卖（-%d）" % GameState.delivery_cost,
			},
			{
				"id": CHOICE_BUY_INGREDIENTS,
				"label": "买食材（-%d）" % GameState.buy_food_cost,
			},
		],
		_on_choice.bind(player_interactor),
	)


static func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	match choice_id:
		CHOICE_DELIVERY:
			if not GameState.can_order_delivery():
				player_interactor.show_text("手头有点紧，点不起外卖。")
				return
			GameState.order_delivery()
			player_interactor.show_text("外卖到了，凑合填填肚子。")
		CHOICE_BUY_INGREDIENTS:
			if not GameState.can_buy_food_supply():
				player_interactor.show_text("手头有点紧，买不起食材。")
				return
			GameState.buy_food_supply()
			player_interactor.show_text(
				"买了些食材，现在还能自己做 %d 天。" % GameState.food_days,
			)

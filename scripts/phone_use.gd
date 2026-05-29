class_name PhoneUse
extends RefCounted

const CHOICE_DELIVERY := "delivery"
const CHOICE_BUY_INGREDIENTS := "buy_ingredients"


static func can_use() -> bool:
	if GameState == null:
		return false
	return not _build_phone_choices().is_empty()


static func run_use(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	var choices := _build_phone_choices()
	if choices.is_empty():
		return
	player_interactor.show_choice("要用手机做什么？", choices, _on_choice.bind(player_interactor))


static func _build_phone_choices() -> Array:
	var choices: Array = []
	if GameState.is_phone_delivery_unlocked():
		choices.append(
			{
				"id": CHOICE_DELIVERY,
				"label": "点外卖（-%d）" % GameState.delivery_cost,
			},
		)
	if GameState.is_kitchen_unlocked():
		choices.append(
			{
				"id": CHOICE_BUY_INGREDIENTS,
				"label": "买食材（-%d）" % GameState.buy_food_cost,
			},
		)
	return choices


static func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	match choice_id:
		CHOICE_DELIVERY:
			if not GameState.is_phone_delivery_unlocked():
				return
			if not GameState.is_meal_time():
				player_interactor.show_text(GameState.MSG_NOT_MEAL_TIME)
				return
			if not GameState.can_order_delivery():
				player_interactor.show_text("手头有点紧，点不起外卖。")
				return
			if GameState.is_workshop_delivery_quest_active():
				await _run_workshop_delivery_order(player_interactor)
				return
			GameState.order_delivery()
			player_interactor.show_text("外卖到了，凑合填填肚子。")
		CHOICE_BUY_INGREDIENTS:
			if not GameState.is_kitchen_unlocked():
				return
			if not GameState.can_buy_food_supply():
				player_interactor.show_text("手头有点紧，买不起食材。")
				return
			GameState.buy_food_supply()
			player_interactor.show_text(
				"买了些食材，现在有 %d 顿食材。" % GameState.food_meals,
			)


static func _run_workshop_delivery_order(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	if not GameState.is_meal_time():
		player_interactor.show_text(GameState.MSG_NOT_MEAL_TIME)
		return
	if not GameState.order_delivery_quest():
		return

	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	await DeliverySequence.run_arrival(player_interactor)
	GameState.mark_delivery_waiting_pickup()

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)

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
	player_interactor.show_choice(GameText.PHONE_PROMPT, choices, _on_choice.bind(player_interactor))


static func _build_phone_choices() -> Array:
	var choices: Array = []
	if GameState.is_phone_delivery_unlocked():
		choices.append(
			{
				"id": CHOICE_DELIVERY,
				"label": GameText.PHONE_CHOICE_DELIVERY % GameState.delivery_cost,
			},
		)
	if GameState.is_kitchen_unlocked():
		choices.append(
			{
				"id": CHOICE_BUY_INGREDIENTS,
				"label": GameText.PHONE_CHOICE_BUY_INGREDIENTS % GameState.buy_food_cost,
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
				player_interactor.show_text(GameText.NOT_MEAL_TIME)
				return
			if GameState.has_flag(GameState.FLAG_DELIVERY_WAITING_PICKUP):
				player_interactor.show_text(GameText.PHONE_DELIVERY_AT_DOOR)
				return
			if GameState.has_flag(GameState.FLAG_DELIVERY_ORDERED):
				player_interactor.show_text(GameText.PHONE_DELIVERY_IN_TRANSIT)
				return
			if GameState.find_inventory_index_by_id(GameState.DELIVERY_ITEM.id) >= 0:
				player_interactor.show_text(GameText.PHONE_DELIVERY_UNFINISHED)
				return
			if not GameState.can_order_delivery():
				player_interactor.show_text(GameText.PHONE_DELIVERY_NO_MONEY)
				return
			_run_delivery_order(player_interactor)
		CHOICE_BUY_INGREDIENTS:
			if not GameState.is_kitchen_unlocked():
				return
			if GameState.has_flag(GameState.FLAG_FOOD_SUPPLY_WAITING_PICKUP):
				player_interactor.show_text(GameText.PHONE_FOOD_AT_DOOR)
				return
			if GameState.has_flag(GameState.FLAG_FOOD_SUPPLY_ORDERED):
				player_interactor.show_text(GameText.PHONE_FOOD_IN_TRANSIT)
				return
			if GameState.has_bought_food_today():
				player_interactor.show_text(GameText.PHONE_FOOD_ALREADY_BOUGHT)
				return
			if not GameState.can_buy_food_supply():
				player_interactor.show_text(GameText.PHONE_FOOD_NO_MONEY)
				return
			GameState.buy_food_supply()
			player_interactor.show_text(GameText.PHONE_FOOD_ORDERED)


static func _run_delivery_order(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	if not GameState.is_meal_time():
		player_interactor.show_text(GameText.NOT_MEAL_TIME)
		return
	if not GameState.order_delivery():
		return
	player_interactor.show_text(GameText.PHONE_DELIVERY_ORDERED)

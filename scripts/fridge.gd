extends Interactable
class_name FridgeInteractable

const CHOICE_YES := "yes"
const CHOICE_NO := "no"


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""

	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return ""

	player_interactor.show_choice(
		GameText.FRIDGE_PROMPT,
		[
			{"id": CHOICE_YES, "label": GameText.CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.CHOICE_NO},
		],
		_on_choice.bind(player_interactor),
	)
	return ""


func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	match choice_id:
		CHOICE_YES:
			if GameState == null or GameState.food_meals <= 0:
				player_interactor.show_text(GameText.FOOD_SUPPLY_EMPTY)
			else:
				player_interactor.show_text(GameState.get_food_supply_text())
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

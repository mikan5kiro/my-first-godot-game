extends Interactable
class_name DiningTableInteractable

const CHOICE_YES := "yes"
const CHOICE_NO := "no"

@export_multiline var message: String = "餐桌。"


func _ready() -> void:
	add_to_group("dining_table")


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""

	if GameState == null or GameState.get_prepared_meal() == null:
		return message

	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return message

	player_interactor.show_choice(
		"餐桌。要吃饭吗？",
		[
			{"id": CHOICE_YES, "label": "要"},
			{"id": CHOICE_NO, "label": "不要"},
		],
		_on_choice.bind(player_interactor),
	)
	return ""


func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	match choice_id:
		CHOICE_YES:
			_start_eating(player_interactor)
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _start_eating(player_interactor: PlayerInteractor) -> void:
	if GameState == null:
		return
	var meal := GameState.get_prepared_meal()
	if meal == null:
		return
	await FoodUse.run_eat_sequence(self, player_interactor, meal)


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

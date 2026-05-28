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
		"冰箱。要打开吗？",
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
			player_interactor.show_text(GameState.get_fridge_contents_text())
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

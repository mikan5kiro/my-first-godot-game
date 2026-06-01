extends Interactable
class_name EndingDoor

const CHOICE_YES := "yes"
const CHOICE_NO := "no"

@export var door_sfx: AudioStream

var _is_activating := false


func get_interaction_priority() -> int:
	return 1


func can_interact(interactor: Node) -> bool:
	if _is_activating:
		return false
	return super.can_interact(interactor)


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""

	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return ""

	player_interactor.show_choice(
		GameText.ENDING_DOOR_PROMPT,
		[
			{"id": CHOICE_YES, "label": GameText.ENDING_CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.ENDING_CHOICE_NO},
		],
		_on_choice.bind(player_interactor, interactor),
	)
	return ""


func _on_choice(choice_id: String, player_interactor: PlayerInteractor, interactor: Node) -> void:
	match choice_id:
		CHOICE_YES:
			_start_ending(player_interactor, interactor)
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _start_ending(player_interactor: PlayerInteractor, interactor: Node) -> void:
	_is_activating = true
	player_interactor.hide_text_immediately()
	if interactor != null and interactor.has_method("set_controls_locked"):
		interactor.set_controls_locked(true)
	await EndingSequence.run(door_sfx)
	_is_activating = false


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

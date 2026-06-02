extends Interactable
class_name EndingDoor

const CHOICE_YES := "yes"
const CHOICE_NO := "no"
const TURN_TO_DOOR_HOLD_DURATION := 0.6

@export var door_sfx: AudioStream
@export_range(0.0, 2.0, 0.05) var black_hold_after_open_sfx: float = 0.4

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

	var has_shiny_thing := _has_shiny_thing()
	var prompt := GameText.ENDING_DOOR_READY_PROMPT if has_shiny_thing else GameText.ENDING_DOOR_PROMPT

	player_interactor.show_choice(
		prompt,
		[
			{"id": CHOICE_YES, "label": GameText.ENDING_CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.ENDING_CHOICE_NO},
		],
		_on_choice.bind(player_interactor, interactor),
	)
	return ""


func _has_shiny_thing() -> bool:
	return GameState != null and GameState.has_shiny_thing()


func _has_photo_investigated() -> bool:
	return GameState != null and GameState.has_photo_investigated()


func _can_play_departure_effect() -> bool:
	return _has_shiny_thing() and _has_photo_investigated()


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
	if _can_play_departure_effect() and interactor is CharacterBody2D:
		await EndingDepartureEffect.run(interactor as CharacterBody2D)
	if TURN_TO_DOOR_HOLD_DURATION > 0.0:
		await get_tree().create_timer(TURN_TO_DOOR_HOLD_DURATION).timeout
	await EndingSequence.run(door_sfx, black_hold_after_open_sfx)
	_is_activating = false


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

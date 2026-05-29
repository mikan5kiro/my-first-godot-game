extends Interactable
class_name DeliveryPickupInteractable


func get_interaction_priority() -> int:
	return 2


func can_interact(interactor: Node) -> bool:
	if GameState == null or not GameState.has_flag(GameState.FLAG_DELIVERY_WAITING_PICKUP):
		return false
	return super.can_interact(interactor)


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""

	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return ""

	_start_pickup(player_interactor)
	return ""


func _start_pickup(player_interactor: PlayerInteractor) -> void:
	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	await DeliverySequence.run_pickup(self, player_interactor)
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor

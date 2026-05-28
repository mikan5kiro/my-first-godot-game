class_name FoodUse
extends RefCounted

const EAT_SFX: AudioStream = preload("res://audios/お菓子を食べる2.mp3")
const EAT_SFX_DURATION: float = 2.0


static func is_dining_table_available(player_interactor: PlayerInteractor, interactor: Node2D) -> bool:
	if player_interactor == null:
		return false
	for area in player_interactor.get_overlapping_areas():
		if area is DiningTableInteractable:
			var table := area as DiningTableInteractable
			if table.can_interact(interactor):
				return true
	return false


static func run_eat_sequence(context_node: Node, player_interactor: PlayerInteractor, item: ItemData) -> void:
	if item == null or not item.is_food or player_interactor == null or context_node == null:
		return
	if GameState == null or GameState.find_inventory_index(item) < 0:
		return

	player_interactor.hide_text_immediately()
	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	await SceneTransition.play_action_with_fade(
		_perform_eat_on_black.bind(context_node, item),
		-1.0,
		_on_eat_fade_out_start.bind(player_interactor, item),
	)

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


static func _perform_eat_on_black(context_node: Node, item: ItemData) -> void:
	if GameState != null:
		GameState.consume_food_item(item)

	var sfx_player := AudioStreamPlayer.new()
	sfx_player.bus = &"Master"
	sfx_player.stream = EAT_SFX
	context_node.add_child(sfx_player)
	sfx_player.play()
	await context_node.get_tree().create_timer(maxf(EAT_SFX_DURATION, 0.01)).timeout
	sfx_player.queue_free()


static func _on_eat_fade_out_start(player_interactor: PlayerInteractor, item: ItemData) -> void:
	if player_interactor == null or item == null:
		return
	player_interactor.show_text("吃完了%s。" % item.get_display_name())

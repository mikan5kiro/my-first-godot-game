class_name FoodUse
extends RefCounted

const EAT_SFX: AudioStream = preload("res://audios/お菓子を食べる2.mp3")
const EAT_SFX_DURATION: float = 2.0
const DINING_TABLE_MAX_DISTANCE := 40.0


static func is_dining_table_available(player_interactor: PlayerInteractor, interactor: Node2D) -> bool:
	if interactor == null:
		return false

	if player_interactor != null:
		for area in player_interactor.get_overlapping_areas():
			if area is DiningTableInteractable:
				var table := area as DiningTableInteractable
				if table.can_interact(interactor):
					return true

	# 打开背包时游戏暂停，Area2D 重叠检测可能失效，改用距离兜底。
	var tree := interactor.get_tree()
	if tree == null:
		return false
	for table in tree.get_nodes_in_group("dining_table"):
		if table is Interactable and table.can_interact(interactor):
			if interactor.global_position.distance_to(table.global_position) <= DINING_TABLE_MAX_DISTANCE:
				return true
	return false


static func run_eat_sequence(context_node: Node, player_interactor: PlayerInteractor, item: ItemData) -> void:
	if item == null or not item.is_meal_item() or player_interactor == null or context_node == null:
		return
	if GameState == null or GameState.find_inventory_index(item) < 0:
		return
	if not GameState.is_meal_time():
		player_interactor.show_text(GameText.NOT_MEAL_TIME)
		return

	player_interactor.hide_text_immediately()
	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	var follow_up_delivery_prompt := GameState != null \
		and GameState.is_delivery_item(item) \
		and GameState.should_play_delivery_cooking_prompt()

	await SceneTransition.play_action_with_fade(
		_perform_eat_on_black.bind(context_node, item),
		-1.0,
		_on_eat_fade_out_start.bind(player_interactor),
	)

	if follow_up_delivery_prompt:
		await DeliveryCookingPrompt.run_after_delivery_eaten(player_interactor)

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


static func _perform_eat_on_black(context_node: Node, item: ItemData) -> void:
	if GameState != null:
		GameState.eat_meal(item)

	var sfx_player := AudioStreamPlayer.new()
	sfx_player.bus = &"Master"
	sfx_player.stream = EAT_SFX
	context_node.add_child(sfx_player)
	sfx_player.play()
	await context_node.get_tree().create_timer(maxf(EAT_SFX_DURATION, 0.01)).timeout
	sfx_player.queue_free()


static func _on_eat_fade_out_start(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	player_interactor.show_text(GameText.MEAL_EATEN)

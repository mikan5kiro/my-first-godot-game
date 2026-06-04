class_name DeliverySequence
extends RefCounted

const DOORBELL_SFX: AudioStream = preload("res://audios/ドアチャイム1.mp3")
const PICKUP_BLACK_HOLD_AFTER_DOOR := 0.5


static func run_arrival(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	player_interactor.hide_text_immediately()
	await SceneTransition.play_action_with_fade(_doorbell_on_black, -1.0)
	await _play_arrived_dialog(player_interactor, GameText.DELIVERY_ARRIVAL_LINES)


static func run_food_arrival(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	player_interactor.hide_text_immediately()
	await SceneTransition.play_action_with_fade(_doorbell_on_black, -1.0)
	await _play_arrived_dialog(player_interactor, GameText.FOOD_ARRIVAL_LINES)


static func run_pickup(context_node: Node, player_interactor: PlayerInteractor) -> void:
	if context_node == null or player_interactor == null or GameState == null:
		return
	player_interactor.hide_text_immediately()
	await SceneTransition.play_action_with_fade(_pickup_on_black, -1.0, Callable(), true)
	_on_pickup_obtained(player_interactor, GameText.DELIVERY_PICKUP_OBTAINED)


static func run_food_pickup(context_node: Node, player_interactor: PlayerInteractor) -> void:
	if context_node == null or player_interactor == null or GameState == null:
		return
	player_interactor.hide_text_immediately()
	await SceneTransition.play_action_with_fade(_food_pickup_on_black, -1.0, Callable(), true)
	_on_pickup_obtained(
		player_interactor,
		GameText.food_pickup_obtained(GameState.food_meals),
	)


static func _doorbell_on_black() -> void:
	if not is_instance_valid(SceneTransition) or DOORBELL_SFX == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = DOORBELL_SFX
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	SceneTransition.add_child(player)
	player.play()
	await player.finished
	player.queue_free()


static func _pickup_on_black() -> void:
	await SceneTransition.play_door_sfx_and_wait()
	if GameState != null:
		GameState.complete_delivery_pickup(false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(PICKUP_BLACK_HOLD_AFTER_DOOR).timeout


static func _food_pickup_on_black() -> void:
	await SceneTransition.play_door_sfx_and_wait()
	if GameState != null:
		GameState.complete_food_supply_pickup()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(PICKUP_BLACK_HOLD_AFTER_DOOR).timeout


static func _on_pickup_obtained(player_interactor: PlayerInteractor, message: String) -> void:
	if player_interactor == null or GameState == null:
		return
	GameState.play_item_obtained_sfx()
	player_interactor.show_text(message)


static func _play_arrived_dialog(
	player_interactor: PlayerInteractor,
	raw_lines: Array,
) -> void:
	if player_interactor == null:
		return
	var lines := DialogTextLoader.lines_from_strings(raw_lines)
	if lines.is_empty():
		return
	await player_interactor.play_monologue_lines(lines)

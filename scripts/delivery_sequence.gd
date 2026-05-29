class_name DeliverySequence
extends RefCounted

const DOORBELL_PLACEHOLDER_DURATION := 0.8
const PICKUP_BLACK_HOLD_AFTER_DOOR := 0.5


static func run_arrival(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	player_interactor.hide_text_immediately()
	await SceneTransition.play_action_with_fade(_doorbell_on_black, -1.0)
	await _play_arrived_dialog(player_interactor)


static func run_pickup(context_node: Node, player_interactor: PlayerInteractor) -> void:
	if context_node == null or player_interactor == null or GameState == null:
		return
	player_interactor.hide_text_immediately()
	await SceneTransition.play_action_with_fade(_pickup_on_black, -1.0)
	_on_pickup_obtained(player_interactor)


static func _doorbell_on_black() -> void:
	# 门铃音效预留：接入 AudioStream 后在此播放并 await finished。
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(DOORBELL_PLACEHOLDER_DURATION).timeout


static func _pickup_on_black() -> void:
	await SceneTransition.play_door_sfx_and_wait()
	if GameState != null:
		GameState.complete_delivery_pickup(false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(PICKUP_BLACK_HOLD_AFTER_DOOR).timeout


static func _on_pickup_obtained(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	GameState.play_item_obtained_sfx()
	player_interactor.show_text("获得外卖。")


static func _play_arrived_dialog(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	var lines := DialogTextLoader.lines_from_strings(
		PackedStringArray(["@外卖到了。", "去客厅大门取外卖吧。"]),
	)
	if lines.is_empty():
		return
	await player_interactor.play_monologue_lines(lines)

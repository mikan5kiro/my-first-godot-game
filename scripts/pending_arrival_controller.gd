class_name PendingArrivalController
extends RefCounted

static var _is_triggering := false


static func schedule_delivery_arrival() -> void:
	_delivery_arrival_after_delay()


static func schedule_food_arrival() -> void:
	_food_arrival_after_delay()


static func _delivery_arrival_after_delay() -> void:
	if GameState == null or not GameState.is_inside_tree():
		return
	await _wait_arrival_delay()
	if GameState == null or not GameState.has_flag(GameState.FLAG_DELIVERY_ORDERED):
		return
	await _run_delivery_arrival()


static func _food_arrival_after_delay() -> void:
	if GameState == null or not GameState.is_inside_tree():
		return
	await _wait_arrival_delay()
	if GameState == null or not GameState.has_flag(GameState.FLAG_FOOD_SUPPLY_ORDERED):
		return
	await _run_food_arrival()


static func _run_delivery_arrival() -> void:
	await _run_arrival_when_ready(
		DeliverySequence.run_arrival,
		GameState.mark_delivery_waiting_pickup,
	)


static func _run_food_arrival() -> void:
	await _run_arrival_when_ready(
		DeliverySequence.run_food_arrival,
		GameState.mark_food_supply_waiting_pickup,
	)


static func _run_arrival_when_ready(
	arrival_fn: Callable,
	mark_waiting_fn: Callable,
) -> void:
	if GameState == null:
		return
	while _is_triggering:
		await GameState.get_tree().process_frame

	await _wait_until_player_panel_closed()
	if GameState == null:
		return

	_is_triggering = true
	var player_interactor := _get_player_interactor()
	if player_interactor == null:
		mark_waiting_fn.call()
		_is_triggering = false
		return

	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	await arrival_fn.call(player_interactor)
	mark_waiting_fn.call()

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_is_triggering = false


static func _get_player_interactor() -> PlayerInteractor:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var player := tree.get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return null
	return player.get_node_or_null("Area2D") as PlayerInteractor


static func _wait_until_player_panel_closed() -> void:
	if GameState == null or not GameState.is_inside_tree():
		return
	var tree := GameState.get_tree()
	while _is_player_panel_open():
		await tree.process_frame


static func _wait_arrival_delay() -> void:
	if GameState == null or not GameState.is_inside_tree():
		return
	var tree := GameState.get_tree()
	var elapsed := 0.0
	var duration := GameState.order_arrival_delay_sec
	while elapsed < duration:
		if GameState == null:
			return
		var frame_start_usec := Time.get_ticks_usec()
		await tree.process_frame
		if _is_arrival_delay_paused():
			continue
		elapsed += float(Time.get_ticks_usec() - frame_start_usec) / 1_000_000.0


static func _is_arrival_delay_paused() -> bool:
	if _is_player_panel_open():
		return true
	if GameState == null or not GameState.is_inside_tree():
		return false
	return GameState.get_tree().paused


static func _is_player_panel_open() -> bool:
	if not is_instance_valid(PlayerPanel):
		return false
	return PlayerPanel.is_open()

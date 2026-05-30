class_name DeliveryCookingPrompt
extends RefCounted


static func run_after_delivery_eaten(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null or GameState == null:
		return
	if not GameState.should_play_delivery_cooking_prompt():
		return

	await _wait_until_interactor_idle(player_interactor)

	var dialog_lines := GameText.load_dialog(GameText.FILE_DELIVERY_COOKING_PROMPT)
	if dialog_lines.is_empty():
		return

	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	await player_interactor.play_monologue_lines(dialog_lines)
	GameState.complete_delivery_cooking_prompt()
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


static func _wait_until_interactor_idle(player_interactor: PlayerInteractor) -> void:
	while player_interactor.is_text_visible():
		await player_interactor.get_tree().process_frame
	await player_interactor.get_tree().process_frame

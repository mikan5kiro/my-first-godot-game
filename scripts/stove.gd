extends Interactable
class_name StoveInteractable

const CHOICE_YES := "yes"
const CHOICE_NO := "no"

const STOVE_IGNITION_SFX: AudioStream = preload("res://audios/ガスコンロ点火.mp3")
const COOKING_SFX: AudioStream = preload("res://audios/餃子を揚げる.mp3")
const STOVE_TURN_OFF_SFX: AudioStream = preload("res://audios/ガスコンロの火を止める.mp3")

@export_range(0.1, 10.0, 0.1) var cooking_sfx_duration: float = 2.0
@export_range(0.1, 3.0, 0.05) var ignition_sfx_duration: float = 2.0

var _cooking_sfx_player: AudioStreamPlayer


func _ready() -> void:
	_cooking_sfx_player = AudioStreamPlayer.new()
	_cooking_sfx_player.bus = &"Master"
	add_child(_cooking_sfx_player)


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if not _should_show_off_meal_time_lines():
		return []
	var next_meal := GameState.get_next_meal_time_display_name()
	return DialogTextLoader.lines_from_strings(
		PackedStringArray([
			GameText.STOVE_LABEL,
			GameText.STOVE_OFF_MEAL_TIME,
			GameText.stove_wait_until(next_meal),
		]),
	)


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""

	if _should_show_off_meal_time_lines():
		if GameState != null:
			GameState.mark_stove_off_meal_time_prompt_played()
		return ""

	if GameState == null or not GameState.can_cook() or not GameState.is_meal_time():
		return GameText.STOVE_LABEL

	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return GameText.STOVE_LABEL

	player_interactor.show_choice(
		GameText.STOVE_COOK_PROMPT,
		[
			{"id": CHOICE_YES, "label": GameText.CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.CHOICE_NO},
		],
		_on_choice.bind(player_interactor),
	)
	return ""


func _on_choice(choice_id: String, player_interactor: PlayerInteractor) -> void:
	match choice_id:
		CHOICE_YES:
			_start_cooking(player_interactor)
		CHOICE_NO:
			player_interactor.hide_text_immediately()


func _start_cooking(player_interactor: PlayerInteractor) -> void:
	if GameState == null or not GameState.can_cook():
		return
	_run_cooking_sequence(player_interactor)


func _run_cooking_sequence(player_interactor: PlayerInteractor) -> void:
	player_interactor.hide_text_immediately()
	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	await _play_sfx_capped(STOVE_IGNITION_SFX, ignition_sfx_duration)

	await SceneTransition.play_action_with_fade(
		_perform_cooking_on_black,
		-1.0,
		_on_cooking_fade_out_start.bind(player_interactor),
	)

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


func _perform_cooking_on_black() -> void:
	if GameState != null:
		GameState.cook_meal()
	await _play_sfx_capped(COOKING_SFX, cooking_sfx_duration)
	await _play_sfx_full(STOVE_TURN_OFF_SFX)


func _on_cooking_fade_out_start(player_interactor: PlayerInteractor) -> void:
	if player_interactor == null:
		return
	GameState.play_item_obtained_sfx()
	player_interactor.show_text(GameText.MEAL_COOKED)


func _play_sfx_full(stream: AudioStream) -> void:
	if _cooking_sfx_player == null or stream == null:
		return
	_cooking_sfx_player.stop()
	_cooking_sfx_player.stream = stream
	_cooking_sfx_player.play()
	if _cooking_sfx_player.playing:
		await _cooking_sfx_player.finished


func _play_sfx_capped(stream: AudioStream, duration: float) -> void:
	if _cooking_sfx_player == null or stream == null:
		return
	_cooking_sfx_player.stop()
	_cooking_sfx_player.stream = stream
	_cooking_sfx_player.play()
	await get_tree().create_timer(maxf(duration, 0.01)).timeout
	_cooking_sfx_player.stop()


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor


func _should_show_off_meal_time_lines() -> bool:
	return GameState != null and GameState.can_cook() and not GameState.is_meal_time()

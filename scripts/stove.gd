extends Interactable
class_name StoveInteractable

const CHOICE_YES := "yes"
const CHOICE_NO := "no"

const MSG_NO_INGREDIENTS := "没有足够的食材。"
const RECIPES: Array[RecipeData] = [
	preload("res://resources/recipes/tomato_egg.tres"),
	preload("res://resources/recipes/beef_pasta.tres"),
]
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


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""

	var player_interactor := _get_player_interactor(interactor)
	if player_interactor == null:
		return ""

	player_interactor.show_choice(
		"灶台。要做饭吗？",
		[
			{"id": CHOICE_YES, "label": "要"},
			{"id": CHOICE_NO, "label": "不要"},
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
	var cookable_recipes := _get_cookable_recipes()
	if cookable_recipes.is_empty():
		player_interactor.show_text(MSG_NO_INGREDIENTS)
		return
	if cookable_recipes.size() == 1:
		_run_cooking_sequence(player_interactor, cookable_recipes[0])
		return
	_show_recipe_choice(player_interactor, cookable_recipes)


func _show_recipe_choice(player_interactor: PlayerInteractor, cookable_recipes: Array[RecipeData]) -> void:
	var choices: Array = []
	for recipe in cookable_recipes:
		choices.append({"id": recipe.id, "label": recipe.get_result_name()})
	choices.append({"id": CHOICE_NO, "label": "算了"})
	player_interactor.show_choice(
		"要做哪道菜？",
		choices,
		_on_recipe_choice.bind(player_interactor, cookable_recipes),
	)


func _on_recipe_choice(
	choice_id: String,
	player_interactor: PlayerInteractor,
	cookable_recipes: Array[RecipeData],
) -> void:
	if choice_id == CHOICE_NO:
		player_interactor.hide_text_immediately()
		return
	for recipe in cookable_recipes:
		if recipe.id == choice_id:
			_run_cooking_sequence(player_interactor, recipe)
			return


func _get_cookable_recipes() -> Array[RecipeData]:
	var cookable: Array[RecipeData] = []
	for recipe in RECIPES:
		if GameState.has_recipe_ingredients(recipe):
			cookable.append(recipe)
	return cookable


func _run_cooking_sequence(player_interactor: PlayerInteractor, recipe: RecipeData) -> void:
	if recipe == null or not GameState.has_recipe_ingredients(recipe):
		player_interactor.show_text(MSG_NO_INGREDIENTS)
		return

	player_interactor.hide_text_immediately()
	var player := player_interactor.get_parent() as CharacterBody2D
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	await _play_sfx_capped(STOVE_IGNITION_SFX, ignition_sfx_duration)

	await SceneTransition.play_action_with_fade(
		_perform_cooking_on_black.bind(recipe),
		-1.0,
		_on_cooking_fade_out_start.bind(player_interactor, recipe),
	)

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


func _perform_cooking_on_black(recipe: RecipeData) -> void:
	GameState.cook_recipe(recipe, false)
	await _play_sfx_capped(COOKING_SFX, cooking_sfx_duration)
	await _play_sfx_full(STOVE_TURN_OFF_SFX)


func _on_cooking_fade_out_start(player_interactor: PlayerInteractor, recipe: RecipeData) -> void:
	GameState.play_item_obtained_sfx()
	player_interactor.show_text("获得 %s。" % recipe.get_result_name())


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

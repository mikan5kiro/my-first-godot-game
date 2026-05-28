extends Area2D
class_name PlayerInteractor

# 玩家交互检测器：
# - 挂在玩家的 Area2D 上（这个 Area2D 就是“交互检测范围”）
# - 按下 interact 时由 player.gd 调用 try_interact(player)
# - 目标选择委托 InteractionSelector；对话委托 DialogPresenter / MonologuePlayer / ChoicePlayer

@export var typewriter_chars_per_sec: float = 36.0
@export var type_sfx_enabled: bool = true
@export var type_sfx_bus: StringName = &"Master"
@export_range(0.0, 1.0, 0.01) var type_sfx_char_chance: float = 0.75
@export var dialog_scene: PackedScene = preload("res://scenes/interaction_dialog.tscn")
@export var choice_hover_sfx: AudioStream = preload("res://audios/カーソル移動12.mp3")
@export var choice_confirm_sfx: AudioStream = preload("res://audios/決定ボタンを押す38.mp3")
@export var choice_cancel_sfx: AudioStream = preload("res://audios/決定ボタンを押す35.mp3")

var _dialog_presenter: DialogPresenter
var _monologue_player: MonologuePlayer
var _choice_player: ChoicePlayer


func _ready() -> void:
	_dialog_presenter = DialogPresenter.new()
	_dialog_presenter.typewriter_chars_per_sec = typewriter_chars_per_sec
	_dialog_presenter.type_sfx_enabled = type_sfx_enabled
	_dialog_presenter.type_sfx_bus = type_sfx_bus
	_dialog_presenter.type_sfx_char_chance = type_sfx_char_chance
	_dialog_presenter.dialog_scene = dialog_scene
	add_child(_dialog_presenter)

	_monologue_player = MonologuePlayer.new()
	_monologue_player.setup(_dialog_presenter)
	add_child(_monologue_player)

	_choice_player = ChoicePlayer.new()
	_choice_player.setup(_dialog_presenter, choice_hover_sfx, choice_confirm_sfx, choice_cancel_sfx)
	add_child(_choice_player)


func try_interact(interactor: Node2D, event: InputEvent = null) -> void:
	if _choice_player.is_active():
		if _should_ignore_interact_event(event):
			return
		_choice_player.confirm_selection()
		return

	if _dialog_presenter.is_visible():
		if _dialog_presenter.is_typing():
			if _should_ignore_interact_event(event):
				return
			_dialog_presenter.skip_typing()
		elif _monologue_player.is_active():
			if _should_ignore_interact_event(event):
				return
			_monologue_player.request_advance()
		else:
			if _should_ignore_interact_event(event):
				return
			hide_text_immediately()
		return

	var target := InteractionSelector.find_best(self, get_overlapping_areas(), interactor)
	if target == null:
		return

	var result: String = target.interact(interactor)
	if not result.is_empty():
		show_text(result)


func try_handle_choice_input(event: InputEvent) -> bool:
	if not _choice_player.is_active():
		return false
	if event.is_action_pressed("up"):
		_choice_player.move_selection(-1)
		return true
	if event.is_action_pressed("down"):
		_choice_player.move_selection(1)
		return true
	return false


func try_cancel(event: InputEvent) -> bool:
	if not _is_cancel_input(event) or event.is_echo():
		return false
	if _choice_player.is_active():
		_choice_player.dismiss()
		hide_text_immediately()
		return true
	if _dialog_presenter.is_visible():
		_choice_player.play_cancel_sfx()
		hide_text_immediately()
		return true
	return false


func show_choice(prompt: String, choices: Array, callback: Callable) -> void:
	_choice_player.start(prompt, choices, callback)


func show_text(text: String) -> void:
	_dialog_presenter.show_text(text)


func is_text_visible() -> bool:
	return _dialog_presenter.is_visible() or _choice_player.is_active()


func is_choice_active() -> bool:
	return _choice_player.is_active()


func play_monologue_lines(lines: PackedStringArray) -> void:
	await _monologue_player.play_lines(lines)


func hide_text_immediately() -> void:
	_choice_player.cancel()
	_monologue_player.cancel()
	_dialog_presenter.hide()


func _should_ignore_interact_event(event: InputEvent) -> bool:
	return event != null and event.is_echo()


func _is_cancel_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel"):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false

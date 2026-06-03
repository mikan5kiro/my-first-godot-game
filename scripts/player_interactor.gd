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
	if _monologue_player.is_waiting_pause():
		# [pause] 等待期间对话框会隐藏；这里直接吞掉交互，避免触发其他操作。
		return

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

	var dialog_lines: Array[DialogLine] = target.get_interaction_dialog_lines()
	var result: String = target.interact(interactor)
	if not dialog_lines.is_empty():
		play_monologue_lines(dialog_lines)
		return
	if not result.is_empty():
		show_text(result)


func try_seat_toggle(interactor: Node2D, _event: InputEvent = null) -> bool:
	if interactor == null:
		return false
	if is_text_visible():
		return false

	var seat_candidates: Array[Area2D] = []
	for area in get_overlapping_areas():
		if area == null or not area.has_method("try_toggle_sit"):
			continue
		seat_candidates.append(area)

	if seat_candidates.is_empty():
		return false

	seat_candidates.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		var pa := _get_interaction_priority(a)
		var pb := _get_interaction_priority(b)
		if pa != pb:
			return pa > pb
		var da := interactor.global_position.distance_to(a.global_position)
		var db := interactor.global_position.distance_to(b.global_position)
		return da < db
	)

	for candidate in seat_candidates:
		if bool(candidate.call("try_toggle_sit", interactor)):
			return true
	return false


func _get_interaction_priority(target: Area2D) -> int:
	if target == null or not target.has_method("get_interaction_priority"):
		return 0
	return int(target.call("get_interaction_priority"))


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


func show_text(
	text: String,
	mode: InteractionDialog.DialogMode = InteractionDialog.DialogMode.NARRATION,
) -> void:
	_dialog_presenter.show_text(text, mode)


func is_text_visible() -> bool:
	return _dialog_presenter.is_visible() or _choice_player.is_active() or _monologue_player.is_waiting_pause()


func is_choice_active() -> bool:
	return _choice_player.is_active()


func play_monologue_lines(lines: Array[DialogLine]) -> void:
	await _monologue_player.play_dialog_lines(lines)


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

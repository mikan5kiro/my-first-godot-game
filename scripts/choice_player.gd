extends Node
class_name ChoicePlayer

## 带选项的对话：显示 prompt + 选项列表，上下键切换，interact 确认。

const CHOICE_ID_CANCEL := "no"

var _presenter: DialogPresenter
var _choices: Array = []
var _selected_index: int = 0
var _active: bool = false
var _callback: Callable
var _hover_sfx: AudioStream
var _confirm_sfx: AudioStream
var _cancel_sfx: AudioStream
var _hover_sfx_player: AudioStreamPlayer
var _confirm_sfx_player: AudioStreamPlayer
var _cancel_sfx_player: AudioStreamPlayer


func setup(
	presenter: DialogPresenter,
	hover_sfx: AudioStream = null,
	confirm_sfx: AudioStream = null,
	cancel_sfx: AudioStream = null,
) -> void:
	_presenter = presenter
	_hover_sfx = hover_sfx
	_confirm_sfx = confirm_sfx
	_cancel_sfx = cancel_sfx
	_setup_audio_players()


func is_active() -> bool:
	return _active


func start(prompt: String, choices: Array, callback: Callable) -> void:
	if _presenter == null or choices.is_empty():
		return
	_choices = choices
	_selected_index = 0
	_callback = callback
	_active = true
	_presenter.show_text_instant(prompt)
	_refresh_choices()


func move_selection(delta: int) -> void:
	if not _active or _choices.is_empty():
		return
	var previous_index := _selected_index
	_selected_index = posmod(_selected_index + delta, _choices.size())
	if _selected_index == previous_index:
		return
	_refresh_choices()
	_play_hover_sfx()


func confirm_selection() -> void:
	if not _active or _choices.is_empty():
		return
	var choice: Dictionary = _choices[_selected_index]
	var choice_id: String = String(choice.get("id", ""))
	if _is_cancel_choice(choice_id):
		_play_cancel_sfx()
	else:
		_play_choice_confirm_sfx(choice)
	var callback := _callback
	cancel()
	if callback.is_valid():
		callback.call(choice_id)


func cancel() -> void:
	_active = false
	_choices = []
	_selected_index = 0
	_callback = Callable()
	if _presenter != null:
		_presenter.clear_choices()


func dismiss() -> void:
	if not _active:
		return
	_play_cancel_sfx()
	cancel()


func play_cancel_sfx() -> void:
	_play_cancel_sfx()


func _refresh_choices() -> void:
	if _presenter == null:
		return
	var labels := PackedStringArray()
	for choice in _choices:
		labels.append(String(choice.get("label", "")))
	_presenter.set_choices(labels, _selected_index)


func _is_cancel_choice(choice_id: String) -> bool:
	return choice_id == CHOICE_ID_CANCEL


func _setup_audio_players() -> void:
	_hover_sfx_player = _create_sfx_player()
	_confirm_sfx_player = _create_sfx_player()
	_cancel_sfx_player = _create_sfx_player()


func _create_sfx_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	return player


func _play_hover_sfx() -> void:
	_play_ui_sfx(_hover_sfx_player, _hover_sfx)


func _play_confirm_sfx() -> void:
	_play_ui_sfx(_confirm_sfx_player, _confirm_sfx)


func _play_choice_confirm_sfx(choice: Dictionary) -> void:
	var override: AudioStream = choice.get("confirm_sfx") as AudioStream
	if override == null:
		_play_confirm_sfx()
		return
	var duration: float = float(choice.get("confirm_sfx_duration", -1.0))
	_play_capped_sfx(_confirm_sfx_player, override, duration)


func _play_cancel_sfx() -> void:
	_play_ui_sfx(_cancel_sfx_player, _cancel_sfx)


func _play_ui_sfx(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()


func _play_capped_sfx(player: AudioStreamPlayer, stream: AudioStream, duration: float) -> void:
	if player == null or stream == null:
		return
	player.stop()
	player.stream = stream
	player.play()
	if duration <= 0.0:
		return
	var timer := get_tree().create_timer(maxf(duration, 0.01))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.stop()
	, CONNECT_ONE_SHOT)

extends Control

@onready var start_button: Button = $Menu/StartButton
@onready var quit_button: Button = $Menu/QuitButton
@onready var fade_overlay: ColorRect = $FadeOverlay
@export_file("*.tscn") var first_scene_path := "res://scenes/卧室.tscn"
@export var hover_sfx: AudioStream
@export var confirm_sfx: AudioStream
@export_range(0.0, 3.0, 0.05) var fade_in_duration := 0.4
@export_range(0.4, 4.0, 0.05) var breath_cycle_duration := 1.2

const BREATH_BORDER_MIN := Color(0.58, 0.62, 0.74, 0.45)
const BREATH_BORDER_MAX := Color(1, 1, 1, 1)
const PRESSED_BORDER := Color(0.38, 0.4, 0.48, 1)

var _menu_buttons: Array[Button] = []
var _selected_index := 0
var _is_confirming := false
var _is_starting_game := false
var _hover_sfx_player: AudioStreamPlayer
var _confirm_sfx_player: AudioStreamPlayer
var _breath_tween: Tween
var _breath_style: StyleBoxFlat
var _breath_button: Button


func _ready() -> void:
	fade_overlay.color = Color(0, 0, 0, 1)
	_setup_audio_players()
	_menu_buttons = [start_button, quit_button]
	_bind_button_actions()
	_configure_keyboard_only_ui()
	_refresh_selection_visuals(true)
	_play_fade_in()


func _bind_button_actions() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _configure_keyboard_only_ui() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	for button in _menu_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE
		button.set_meta("_normal_style", button.get_theme_stylebox("normal").duplicate())
		button.set_meta("_selected_style", button.get_theme_stylebox("hover").duplicate())


func _unhandled_input(event: InputEvent) -> void:
	if _is_confirming or _is_starting_game:
		return

	if event.is_action_pressed("up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_confirm_selection()
		get_viewport().set_input_as_handled()


func _move_selection(step: int) -> void:
	if _menu_buttons.is_empty():
		return
	var previous_index := _selected_index
	_selected_index = posmod(_selected_index + step, _menu_buttons.size())
	if _selected_index != previous_index:
		_play_ui_sfx(_hover_sfx_player, hover_sfx)
	_refresh_selection_visuals(false)


func _refresh_selection_visuals(_immediate: bool) -> void:
	_stop_button_breath()
	var half_cycle := breath_cycle_duration * 0.5

	for index in _menu_buttons.size():
		var button := _menu_buttons[index]
		var selected := index == _selected_index
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE

		if selected:
			_start_button_breath(button, half_cycle)
		else:
			_apply_button_style(button, button.get_meta("_normal_style") as StyleBox)


func _apply_button_style(button: Button, style: StyleBox) -> void:
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("focus", style)


func _start_button_breath(button: Button, half_cycle: float) -> void:
	_stop_button_breath()
	var template := button.get_meta("_selected_style") as StyleBoxFlat
	_breath_style = template.duplicate()
	_breath_button = button
	_breath_style.border_color = BREATH_BORDER_MIN
	_apply_button_style(button, _breath_style)

	_breath_tween = create_tween().set_loops()
	_breath_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_breath_tween.tween_property(_breath_style, "border_color", BREATH_BORDER_MAX, half_cycle)
	_breath_tween.tween_property(_breath_style, "border_color", BREATH_BORDER_MIN, half_cycle)


func _stop_button_breath() -> void:
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null
	_breath_style = null
	_breath_button = null


func _confirm_selection() -> void:
	if _menu_buttons.is_empty():
		return

	_is_confirming = true
	var button := _menu_buttons[_selected_index]
	_play_ui_sfx(_confirm_sfx_player, confirm_sfx)

	var style: StyleBoxFlat
	if _breath_button == button and _breath_style != null:
		style = _breath_style
	else:
		style = (button.get_meta("_selected_style") as StyleBoxFlat).duplicate()
		_apply_button_style(button, style)
	_stop_button_breath()
	_breath_style = style
	_breath_button = button

	_tween_border_color(style, PRESSED_BORDER, 0.06)
	await get_tree().create_timer(0.06).timeout
	_tween_border_color(style, BREATH_BORDER_MIN, 0.08)
	await get_tree().create_timer(0.05).timeout
	button.emit_signal("pressed")
	if is_inside_tree() and not _is_starting_game:
		_is_confirming = false
		_refresh_selection_visuals(true)


func _tween_border_color(style: StyleBoxFlat, target: Color, duration: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(style, "border_color", target, duration)


func _setup_audio_players() -> void:
	_hover_sfx_player = AudioStreamPlayer.new()
	_hover_sfx_player.bus = "Master"
	add_child(_hover_sfx_player)

	_confirm_sfx_player = AudioStreamPlayer.new()
	_confirm_sfx_player.bus = "Master"
	add_child(_confirm_sfx_player)


func _play_ui_sfx(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()


func _play_fade_in() -> void:
	if fade_in_duration <= 0.0:
		fade_overlay.color = Color(0, 0, 0, 0)
		return

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fade_overlay, "color:a", 0.0, fade_in_duration)


func _on_start_pressed() -> void:
	_is_starting_game = true
	_stop_button_breath()
	if first_scene_path.is_empty():
		_is_starting_game = false
		push_warning("TitleScreen: first_scene_path is empty")
		return
	SceneTransition.transition_to(first_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	_stop_button_breath()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

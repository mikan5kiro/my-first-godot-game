extends Control

@onready var start_button: Button = $Menu/StartButton
@onready var load_button: Button = $Menu/LoadButton
@onready var quit_button: Button = $Menu/QuitButton
@onready var language_button: TextureButton = $LanguageButton
@onready var title_text: TextureRect = $TitleText
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var load_page: Control = $LoadPage
@onready var load_slot_list: VBoxContainer = $LoadPage/PanelRoot/Margin/SlotList
@export_file("*.tscn") var first_scene_path := "res://scenes/卧室.tscn"
@export var status_panel_scene: PackedScene = preload("res://scenes/status_panel_view.tscn")
@export var player_display_name: String = "ui.common.player_name_default"
@export var title_bgm: AudioStream
@export_range(-80.0, 24.0, 0.5) var title_bgm_volume_db := -6.0
@export var title_bgm_bus := &"Master"
@export var hover_sfx: AudioStream
@export var confirm_sfx: AudioStream
@export_range(0.0, 3.0, 0.05) var fade_in_duration := 0.4
@export_range(0.4, 4.0, 0.05) var breath_cycle_duration := 1.2
@export_range(0.0, 40.0, 0.5) var title_float_amplitude := 4.0
@export_range(0.1, 6.0, 0.05) var title_float_speed := 0.5

const PRESSED_BORDER := Color(0.38, 0.4, 0.48, 1)
const LOAD_BUTTON_INDEX := 1
const LANGUAGE_BUTTON_INDEX := 3
const MAIN_MENU_ITEM_COUNT := 4
const ENABLED_FONT_COLOR := Color(0.95, 0.98, 1, 1)
const ENABLED_FONT_PRESSED_COLOR := Color(0.86, 0.9, 1, 1)
const DISABLED_FONT_COLOR := Color(0.62, 0.62, 0.62, 1)
const LANGUAGE_TEXTURE_ZH := preload("res://images/buttonch.png")
const LANGUAGE_TEXTURE_EN := preload("res://images/buttonen.png")
const LANGUAGE_BUTTON_MARGIN := Vector2(12.0, 12.0)
const LANGUAGE_BUTTON_DISPLAY_SCALE := 0.5

enum Screen {
	MAIN,
	LOAD,
}

var _menu_buttons: Array[Button] = []
var _load_rows: Array[StatusPanelView] = []
var _selected_index := 0
var _load_selected_index := 0
var _active_screen := Screen.MAIN
var _is_confirming := false
var _is_starting_game := false
var _is_loading_game := false
var _bgm_player: AudioStreamPlayer
var _hover_sfx_player: AudioStreamPlayer
var _confirm_sfx_player: AudioStreamPlayer
var _button_breath := BorderBreathAnimator.new()
var _breath_button: Button
var _title_text_base_position := Vector2.ZERO
var _title_float_time := 0.0
var _language_breath_tween: Tween


func _ready() -> void:
	_title_text_base_position = title_text.position
	fade_overlay.color = Color(0, 0, 0, 1)
	_setup_audio_players()
	_play_title_bgm()
	_menu_buttons = [start_button, load_button, quit_button]
	_bind_button_actions()
	if LanguageSwitch != null:
		LanguageSwitch.language_changed.connect(_on_language_changed)
	call_deferred("_apply_localized_texts")
	_configure_keyboard_only_ui(_menu_buttons)
	_configure_language_button()
	_build_load_slot_rows()
	_configure_load_page_input()
	load_page.hide()
	_ensure_valid_main_selection()
	_refresh_selection_visuals(true)
	_play_fade_in()


func _process(delta: float) -> void:
	if title_text == null or title_float_amplitude <= 0.0 or title_float_speed <= 0.0:
		return
	_title_float_time += delta
	title_text.position = _title_text_base_position + Vector2(
		0.0,
		sin(_title_float_time * TAU * title_float_speed) * title_float_amplitude
	)


func _bind_button_actions() -> void:
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	language_button.pressed.connect(_on_language_pressed)


func _configure_keyboard_only_ui(buttons: Array[Button]) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE
		button.show()
		button.set_meta("_normal_style", button.get_theme_stylebox("normal").duplicate())
		button.set_meta("_selected_style", button.get_theme_stylebox("hover").duplicate())


func _configure_language_button() -> void:
	if language_button == null:
		return
	language_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	language_button.focus_mode = Control.FOCUS_NONE
	_apply_language_button_layout()


func _configure_load_page_input() -> void:
	load_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$LoadPage/PanelRoot.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_load_slot_rows() -> void:
	_load_rows.clear()
	for child in load_slot_list.get_children():
		child.queue_free()

	for slot in SaveManager.SLOT_COUNT:
		var row := _create_load_slot_row(slot)
		load_slot_list.add_child(row)
		_apply_slot_data(row, slot)
		_load_rows.append(row)


func _create_load_slot_row(slot: int) -> StatusPanelView:
	var row := status_panel_scene.instantiate() as StatusPanelView
	row.player_display_name = _translate(player_display_name)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(RpgUiStyle.BOTTOM_PANEL_WIDTH, RpgUiStyle.BOTTOM_PANEL_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("slot", slot)
	row.set_meta("_normal_style", RpgUiStyle.make_box_style(8.0))
	row.set_meta("_selected_style", RpgUiStyle.make_selection_style(8.0))
	return row


func _apply_slot_data(row: StatusPanelView, slot: int) -> void:
	row.player_display_name = _translate(player_display_name)
	row.set_slot_title(_translate("ui.save.slot_short") % (slot + 1))
	if SaveManager.has_save(slot):
		row.apply_from_save_data(SaveManager.read_save_data(slot))
	else:
		row.apply_blank_slot()


func _refresh_load_slot_data() -> void:
	for row in _load_rows:
		var slot: int = int(row.get_meta("slot", -1))
		if slot >= 0:
			_apply_slot_data(row, slot)


func _input(event: InputEvent) -> void:
	if _is_confirming or _is_starting_game or _is_loading_game:
		return

	match _active_screen:
		Screen.MAIN:
			if _handle_main_menu_input(event):
				get_viewport().set_input_as_handled()
		Screen.LOAD:
			if _handle_load_menu_input(event):
				get_viewport().set_input_as_handled()


func _handle_main_menu_input(event: InputEvent) -> bool:
	if event.is_action_pressed("up"):
		_move_selection(-1)
		return true
	if event.is_action_pressed("down"):
		_move_selection(1)
		return true
	if event.is_action_pressed("interact"):
		_confirm_selection()
		return true
	return false


func _handle_load_menu_input(event: InputEvent) -> bool:
	if event.is_action_pressed("up"):
		_move_load_selection(-1)
		return true
	if event.is_action_pressed("down"):
		_move_load_selection(1)
		return true
	if event.is_action_pressed("interact"):
		_confirm_load_selection()
		return true
	if event.is_action_pressed("ui_cancel"):
		_show_main_menu()
		return true
	return false


func _is_menu_index_selectable(index: int) -> bool:
	if index == LANGUAGE_BUTTON_INDEX:
		return true
	if index == LOAD_BUTTON_INDEX:
		return SaveManager.has_any_save()
	return index >= 0 and index < _menu_buttons.size()


func _ensure_valid_main_selection() -> void:
	if _is_menu_index_selectable(_selected_index):
		return
	_selected_index = 0


func _move_selection(step: int) -> void:
	var previous_index := _selected_index
	for _attempt in MAIN_MENU_ITEM_COUNT:
		_selected_index = posmod(_selected_index + step, MAIN_MENU_ITEM_COUNT)
		if _is_menu_index_selectable(_selected_index):
			break
	if not _is_menu_index_selectable(_selected_index):
		_selected_index = previous_index
		return
	if _selected_index != previous_index:
		_play_ui_sfx(_hover_sfx_player, hover_sfx)
	_refresh_selection_visuals(false)


func _move_load_selection(step: int) -> void:
	if _load_rows.is_empty():
		return
	var previous_index := _load_selected_index
	_load_selected_index = posmod(_load_selected_index + step, _load_rows.size())
	if _load_selected_index != previous_index:
		_play_ui_sfx(_hover_sfx_player, hover_sfx)
	_refresh_load_selection_visuals(false)


func _refresh_selection_visuals(_immediate: bool) -> void:
	_button_breath.stop()
	_stop_language_breath()
	_breath_button = null
	var half_cycle := breath_cycle_duration * 0.5
	var language_selected := _selected_index == LANGUAGE_BUTTON_INDEX

	for index in _menu_buttons.size():
		var button := _menu_buttons[index]
		var selectable := _is_menu_index_selectable(index)
		var selected := index == _selected_index and selectable and not language_selected
		var ui_font_color := ENABLED_FONT_COLOR if selectable else DISABLED_FONT_COLOR
		var ui_pressed_color := ENABLED_FONT_PRESSED_COLOR if selectable else DISABLED_FONT_COLOR
		button.scale = Vector2.ONE
		button.modulate = Color.WHITE
		button.show()
		button.add_theme_color_override(
			"font_color",
			ui_font_color
		)
		button.add_theme_color_override(
			"font_hover_color",
			ui_font_color
		)
		button.add_theme_color_override(
			"font_pressed_color",
			ui_pressed_color
		)
		button.add_theme_color_override(
			"font_focus_color",
			ui_font_color
		)
		button.add_theme_color_override(
			"font_disabled_color",
			ui_font_color
		)

		if selected:
			var template := button.get_meta("_selected_style") as StyleBoxFlat
			var style: StyleBoxFlat = _button_breath.start(self, template, half_cycle)
			_breath_button = button
			_apply_button_style(button, style)
		else:
			_apply_button_style(button, button.get_meta("_normal_style") as StyleBox)

	_refresh_language_button_visual(language_selected, half_cycle)


func _refresh_language_button_visual(selected: bool, half_cycle: float) -> void:
	if language_button == null:
		return
	_stop_language_breath()
	language_button.scale = Vector2.ONE
	if not selected:
		language_button.modulate = Color.WHITE
		return
	language_button.modulate = Color(0.9, 0.9, 0.9, 1.0)
	_language_breath_tween = create_tween().set_loops()
	_language_breath_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_language_breath_tween.tween_property(
		language_button,
		"modulate",
		Color(1.25, 1.25, 1.25, 1.0),
		half_cycle,
	)
	_language_breath_tween.tween_property(
		language_button,
		"modulate",
		Color(0.85, 0.85, 0.85, 1.0),
		half_cycle,
	)


func _stop_language_breath() -> void:
	if _language_breath_tween != null and _language_breath_tween.is_valid():
		_language_breath_tween.kill()
	_language_breath_tween = null


func _refresh_load_selection_visuals(_immediate: bool) -> void:
	_button_breath.stop()
	var half_cycle := breath_cycle_duration * 0.5

	for index in _load_rows.size():
		var row := _load_rows[index]
		var selected := index == _load_selected_index
		if selected:
			var template := row.get_meta("_selected_style") as StyleBoxFlat
			var style: StyleBoxFlat = _button_breath.start(self, template, half_cycle)
			_apply_row_style(row, style)
		else:
			_apply_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)


func _apply_button_style(button: Button, style: StyleBox) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)


func _apply_row_style(row: StatusPanelView, style: StyleBoxFlat) -> void:
	row.add_theme_stylebox_override("panel", style)


func _confirm_selection() -> void:
	if not _is_menu_index_selectable(_selected_index):
		return
	if _selected_index == LANGUAGE_BUTTON_INDEX:
		await _confirm_language_selection()
		return
	if _menu_buttons.is_empty():
		return

	_is_confirming = true
	var button := _menu_buttons[_selected_index]
	_play_ui_sfx(_confirm_sfx_player, confirm_sfx)

	var style: StyleBoxFlat
	if _breath_button == button and _button_breath.get_style() != null:
		style = _button_breath.get_style()
	else:
		style = (button.get_meta("_selected_style") as StyleBoxFlat).duplicate()
		_apply_button_style(button, style)
	_button_breath.stop()
	_breath_button = button

	_tween_border_color(style, PRESSED_BORDER, 0.06)
	await get_tree().create_timer(0.06).timeout
	_tween_border_color(style, RpgUiStyle.BREATH_BORDER_MIN, 0.08)
	await get_tree().create_timer(0.05).timeout
	button.emit_signal("pressed")
	if is_inside_tree() and not _is_starting_game and not _is_loading_game:
		_is_confirming = false
		if _active_screen == Screen.MAIN:
			_refresh_selection_visuals(true)


func _confirm_load_selection() -> void:
	if _load_rows.is_empty():
		return

	var row := _load_rows[_load_selected_index]
	var slot: int = int(row.get_meta("slot", -1))
	if slot < 0 or not SaveManager.has_save(slot):
		return

	_is_confirming = true
	_play_ui_sfx(_confirm_sfx_player, confirm_sfx)
	var style := (row.get_meta("_selected_style") as StyleBoxFlat).duplicate()
	_apply_row_style(row, style)
	_button_breath.stop()
	_tween_border_color(style, PRESSED_BORDER, 0.06)
	await get_tree().create_timer(0.06).timeout
	_tween_border_color(style, RpgUiStyle.BREATH_BORDER_MIN, 0.08)
	await get_tree().create_timer(0.05).timeout

	await _load_slot(slot)

	if is_inside_tree() and not _is_loading_game:
		_is_confirming = false
		_refresh_load_selection_visuals(true)


func _tween_border_color(style: StyleBoxFlat, target: Color, duration: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(style, "border_color", target, duration)


func _play_title_bgm() -> void:
	if SceneTransition != null:
		var claimed := SceneTransition.claim_title_bgm(self, title_bgm_bus, title_bgm_volume_db)
		if claimed != null:
			_bgm_player = claimed
			return

	if title_bgm == null:
		return

	var stream := title_bgm.duplicate(true)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = title_bgm_bus
	_bgm_player.volume_db = title_bgm_volume_db
	_bgm_player.stream = stream
	add_child(_bgm_player)
	_bgm_player.play()


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
	_button_breath.stop()
	if first_scene_path.is_empty():
		_is_starting_game = false
		push_warning("TitleScreen: first_scene_path is empty")
		return
	SaveManager.active_slot = -1
	GameState.reset_to_defaults()
	SceneTransition.transition_to(first_scene_path)


func _on_load_menu_pressed() -> void:
	if not SaveManager.has_any_save():
		return
	_show_load_menu()


func _confirm_language_selection() -> void:
	if language_button == null:
		return
	_is_confirming = true
	_play_ui_sfx(_confirm_sfx_player, confirm_sfx)
	_button_breath.stop()
	_stop_language_breath()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(language_button, "scale", Vector2(0.88, 0.88), 0.06)
	tween.tween_property(language_button, "scale", Vector2.ONE, 0.08)
	await tween.finished
	_on_language_pressed()
	if is_inside_tree():
		_is_confirming = false
		_refresh_selection_visuals(true)


func _on_language_pressed() -> void:
	if LanguageSwitch == null:
		return
	LanguageSwitch.toggle_locale()


func _on_language_changed(_locale: String) -> void:
	_apply_localized_texts()
	_refresh_load_slot_data()


func _apply_localized_texts() -> void:
	start_button.text = _translate("ui.title.start")
	load_button.text = _translate("ui.title.load")
	quit_button.text = _translate("ui.title.quit")
	_refresh_language_button_texture()


func _refresh_language_button_texture() -> void:
	if language_button == null or LanguageSwitch == null:
		return
	if LanguageSwitch.get_current_locale() == LanguageSwitch.LOCALE_EN:
		language_button.texture_normal = LANGUAGE_TEXTURE_ZH
	else:
		language_button.texture_normal = LANGUAGE_TEXTURE_EN
	_apply_language_button_layout()


func _apply_language_button_layout() -> void:
	if language_button == null:
		return
	var texture := language_button.texture_normal
	if texture == null:
		return
	var size := texture.get_size() * LANGUAGE_BUTTON_DISPLAY_SCALE
	language_button.offset_left = -size.x - LANGUAGE_BUTTON_MARGIN.x
	language_button.offset_top = -size.y - LANGUAGE_BUTTON_MARGIN.y
	language_button.offset_right = -LANGUAGE_BUTTON_MARGIN.x
	language_button.offset_bottom = -LANGUAGE_BUTTON_MARGIN.y


func _translate(key: String) -> String:
	if LanguageSwitch != null:
		return LanguageSwitch.translate_text(key)
	return TranslationServer.translate(key)


func _show_load_menu() -> void:
	_is_confirming = false
	_active_screen = Screen.LOAD
	_load_selected_index = 0
	_refresh_load_slot_data()
	load_page.show()
	_refresh_load_selection_visuals(true)


func _show_main_menu() -> void:
	_active_screen = Screen.MAIN
	load_page.hide()
	_button_breath.stop()
	_ensure_valid_main_selection()
	_refresh_selection_visuals(true)


func _load_slot(slot: int) -> void:
	_is_loading_game = true
	_button_breath.stop()
	var success: bool = await SaveManager.load_game(slot)
	if not success:
		_is_loading_game = false
		_is_confirming = false
		push_warning("TitleScreen: failed loading slot %d" % (slot + 1))


func _on_quit_pressed() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	_button_breath.stop()
	_stop_language_breath()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

extends CanvasLayer

enum Tab {
	ITEMS,
	READ,
}

@export_file("*.tscn") var title_scene_path: String = "res://scenes/title_screen.tscn"
@export var panel_toggle_action: StringName = &"ui_cancel"
@export var player_display_name: String = "玩家"
@export_range(0.4, 4.0, 0.05) var menu_breath_cycle_duration := 1.2
@export var main_menu_width := RpgUiStyle.BOTTOM_PANEL_WIDTH
@export var item_menu_columns := 2
@export var item_slot_min_width := 148.0
@export var hover_sfx: AudioStream
@export var confirm_sfx: AudioStream
@export var open_panel_sfx: AudioStream
@export var close_panel_sfx: AudioStream
@export var close_detail_sfx: AudioStream

const MENU_ROW_HEIGHT := 34.0

@onready var main_menu_root: Control = $MainMenuRoot
@onready var detail_menu_root: Control = $MainMenuRoot/StatusPanel/Margin/StatusContent/DetailMenuRoot
@onready var items_row: PanelContainer = $MainMenuRoot/MenuPanel/Margin/MenuList/ItemsRow
@onready var read_row: PanelContainer = $MainMenuRoot/MenuPanel/Margin/MenuList/ReadRow
@onready var player_name_label: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/InfoColumn/PlayerName
@onready var time_value: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/InfoColumn/StatGrid/TimeRow/Value
@onready var hunger_value: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/InfoColumn/StatGrid/HungerRow/Value
@onready var sanity_value: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/InfoColumn/StatGrid/SanityRow/Value
@onready var money_value: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/InfoColumn/StatGrid/MoneyRow/Value
@onready var status_content: Control = $MainMenuRoot/StatusPanel/Margin/StatusContent
@onready var status_body: Control = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody
@onready var avatar_slot: AspectRatioContainer = $MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/AvatarSlot
@onready var _detail_list_panel: SelectableListPanel = $MainMenuRoot/StatusPanel/Margin/StatusContent/DetailMenuRoot

var _active_tab: Tab = Tab.ITEMS
var _detail_menu_open: bool = false
var _menu_rows: Array[PanelContainer] = []
var _menu_breath := BorderBreathAnimator.new()
var _hover_sfx_player: AudioStreamPlayer
var _confirm_sfx_player: AudioStreamPlayer
var _panel_sfx_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_setup_audio_players()
	_apply_panel_styles()
	_detail_list_panel.breath_cycle_duration = menu_breath_cycle_duration
	_detail_list_panel.navigation_moved.connect(_on_detail_navigation_moved)
	_detail_list_panel.confirmed.connect(_on_detail_confirmed)
	_menu_rows = [items_row, read_row]
	_configure_menu_rows()
	items_row.gui_input.connect(_on_items_row_gui_input)
	read_row.gui_input.connect(_on_read_row_gui_input)

	if get_tree() != null:
		get_tree().scene_changed.connect(_on_scene_changed)

	if GameState != null:
		GameState.stats_changed.connect(_refresh_status)
		GameState.time_changed.connect(_on_time_changed)
		GameState.inventory_changed.connect(_on_inventory_changed)
		GameState.tasks_changed.connect(_on_tasks_changed)

	player_name_label.text = player_display_name
	status_content.resized.connect(_apply_avatar_size)
	_refresh_all()
	_set_active_tab(Tab.ITEMS)
	_close_detail_menu()
	call_deferred("_apply_main_menu_layout")
	call_deferred("_apply_avatar_size")


func _apply_detail_binding(tab: Tab) -> void:
	match tab:
		Tab.ITEMS:
			_detail_list_panel.columns = item_menu_columns
			_detail_list_panel.slot_min_width = item_slot_min_width
			_detail_list_panel.show_count_suffix = true
			_detail_list_panel.empty_detail_text = ""
			_detail_list_panel.bind(
				_get_inventory_entries,
				_get_item_title,
				_get_item_detail,
				_get_item_stable_id,
			)
		Tab.READ:
			_detail_list_panel.columns = 1
			_detail_list_panel.slot_min_width = 0.0
			_detail_list_panel.show_count_suffix = false
			_detail_list_panel.empty_detail_text = "读取功能预留"
			_detail_list_panel.bind(
				_get_task_entries,
				_get_task_title,
				_get_task_detail,
				_get_task_stable_id,
			)


func _get_inventory_entries() -> Array:
	return _get_grouped_inventory()


func _get_grouped_inventory() -> Array:
	if GameState == null:
		return []

	var groups: Array = []
	var group_index_by_id: Dictionary = {}
	for item in GameState.inventory_items:
		if item == null:
			continue
		var item_id := item.id if not item.id.is_empty() else str(item.get_instance_id())
		if group_index_by_id.has(item_id):
			var group: Dictionary = groups[group_index_by_id[item_id]]
			group["count"] = int(group["count"]) + 1
		else:
			group_index_by_id[item_id] = groups.size()
			groups.append({"item": item, "count": 1})
	return groups


func _get_inventory_entry(index: int) -> Dictionary:
	var groups := _get_grouped_inventory()
	if index < 0 or index >= groups.size():
		return {}
	return groups[index]


func _get_item_title(index: int) -> String:
	var entry := _get_inventory_entry(index)
	if entry.is_empty():
		return ""
	var item: ItemData = entry.get("item")
	if item == null:
		return "未知物品"
	return item.get_display_name()


func _get_item_detail(index: int) -> String:
	var entry := _get_inventory_entry(index)
	if entry.is_empty():
		return ""
	var item: ItemData = entry.get("item")
	return item.get_inspect_text() if item != null else ""


func _get_item_stable_id(index: int) -> String:
	var entry := _get_inventory_entry(index)
	if entry.is_empty():
		return ""
	var item: ItemData = entry.get("item")
	return item.id if item != null else ""


func _get_task_entries() -> Array:
	if GameState == null:
		return []
	return Array(GameState.active_tasks)


func _get_task_title(index: int) -> String:
	if GameState == null or index < 0 or index >= GameState.active_tasks.size():
		return ""
	return String(GameState.active_tasks[index])


func _get_task_detail(index: int) -> String:
	if GameState == null or index < 0 or index >= GameState.active_tasks.size():
		return ""
	return String(GameState.active_tasks[index])


func _get_task_stable_id(index: int) -> String:
	if GameState == null or index < 0 or index >= GameState.active_tasks.size():
		return ""
	return String(GameState.active_tasks[index])


func _configure_menu_rows() -> void:
	for row in _menu_rows:
		row.custom_minimum_size = Vector2(0.0, MENU_ROW_HEIGHT)
		row.set_meta("_normal_style", RpgUiStyle.make_menu_row_normal_style())
		row.set_meta("_selected_style", RpgUiStyle.make_menu_row_selected_style())
		_apply_menu_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)


func _apply_menu_row_style(row: PanelContainer, style: StyleBoxFlat) -> void:
	row.add_theme_stylebox_override("panel", style)


func _apply_panel_styles() -> void:
	var box_style: StyleBoxFlat = RpgUiStyle.make_box_style(8.0)
	var list_style: StyleBoxFlat = RpgUiStyle.make_box_style(8.0)
	$MainMenuRoot/MenuPanel.add_theme_stylebox_override("panel", box_style)
	$MainMenuRoot/StatusPanel.add_theme_stylebox_override("panel", box_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/DetailMenuRoot/DescriptionPanel.add_theme_stylebox_override("panel", list_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/DetailMenuRoot/ListPanel.add_theme_stylebox_override("panel", list_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/AvatarSlot/AvatarFrame.add_theme_stylebox_override(
		"panel", RpgUiStyle.make_avatar_style(4.0)
	)


func _apply_main_menu_layout() -> void:
	if main_menu_root == null:
		return
	main_menu_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half_width: float = main_menu_width * 0.5
	main_menu_root.offset_left = -half_width
	main_menu_root.offset_top = -RpgUiStyle.BOTTOM_PANEL_HEIGHT
	main_menu_root.offset_right = half_width
	main_menu_root.offset_bottom = -RpgUiStyle.BOTTOM_PANEL_BOTTOM_OFFSET


func _apply_avatar_size() -> void:
	if status_content == null or avatar_slot == null:
		return
	var max_side: float = status_content.size.y
	if max_side <= 0.0:
		max_side = 104.0
	max_side = clampf(max_side - 2.0, 56.0, 104.0)
	avatar_slot.custom_minimum_size = Vector2(max_side, max_side)


func _refresh_status_panel_content() -> void:
	detail_menu_root.visible = _detail_menu_open
	status_body.visible = not _detail_menu_open


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if _is_toggle_input(event) and _can_open_menu():
			_open_panel()
			get_viewport().set_input_as_handled()
		return

	if _is_toggle_input(event):
		if _detail_menu_open:
			_close_detail_menu(true)
		else:
			_close_panel()
		get_viewport().set_input_as_handled()
		return

	if _detail_menu_open:
		if _detail_list_panel.try_handle_input(event):
			get_viewport().set_input_as_handled()
		return

	_handle_main_menu_input(event)


func _handle_main_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("up"):
		_move_tab_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down"):
		_move_tab_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_open_detail_menu()
		get_viewport().set_input_as_handled()


func _is_toggle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(panel_toggle_action):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false


func _is_title_scene() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false
	return current_scene.scene_file_path == title_scene_path


func _can_open_menu() -> bool:
	if _is_title_scene():
		return false
	if SceneTransition.is_transitioning():
		return false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null and player.has_method("is_controls_locked") and player.is_controls_locked():
		return false
	return true


func _open_panel() -> void:
	_play_open_panel_sfx()
	_refresh_all()
	_set_active_tab(Tab.ITEMS)
	_close_detail_menu()
	main_menu_root.show()
	show()
	get_tree().paused = true
	call_deferred("_apply_main_menu_layout")
	call_deferred("_apply_avatar_size")


func _close_panel() -> void:
	_play_close_panel_sfx()
	_close_detail_menu()
	_menu_breath.stop()
	hide()
	get_tree().paused = false


func _open_detail_menu() -> void:
	_play_confirm_sfx()
	_detail_menu_open = true
	_apply_detail_binding(_active_tab)
	_detail_list_panel.refresh()
	_refresh_status_panel_content()


func _close_detail_menu(play_sfx: bool = false) -> void:
	if not _detail_menu_open:
		return
	_detail_menu_open = false
	if play_sfx:
		_play_close_detail_sfx()
	_detail_list_panel.clear_detail()
	_refresh_status_panel_content()


func _on_scene_changed() -> void:
	if visible and _is_title_scene():
		_close_panel()


func _on_items_row_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var previous_tab: Tab = _active_tab
			_set_active_tab(Tab.ITEMS)
			if previous_tab != Tab.ITEMS:
				_play_hover_sfx()
			_open_detail_menu()
			get_viewport().set_input_as_handled()


func _on_read_row_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var previous_tab: Tab = _active_tab
			_set_active_tab(Tab.READ)
			if previous_tab != Tab.READ:
				_play_hover_sfx()
			_open_detail_menu()
			get_viewport().set_input_as_handled()


func _set_active_tab(tab: Tab) -> void:
	if tab != _active_tab:
		_close_detail_menu()
	_active_tab = tab
	_refresh_tab_visuals()
	_refresh_status_panel_content()
	call_deferred("_apply_avatar_size")


func _move_tab_selection(step: int) -> void:
	var previous_tab: Tab = _active_tab
	var tab_index: int = posmod(int(_active_tab) + step, _menu_rows.size())
	var next_tab := tab_index as Tab
	if next_tab != previous_tab:
		_play_hover_sfx()
	_set_active_tab(next_tab)


func _setup_audio_players() -> void:
	_hover_sfx_player = AudioStreamPlayer.new()
	_hover_sfx_player.bus = &"Master"
	add_child(_hover_sfx_player)

	_confirm_sfx_player = AudioStreamPlayer.new()
	_confirm_sfx_player.bus = &"Master"
	add_child(_confirm_sfx_player)

	_panel_sfx_player = AudioStreamPlayer.new()
	_panel_sfx_player.bus = &"Master"
	add_child(_panel_sfx_player)


func _play_open_panel_sfx() -> void:
	_play_ui_sfx(_panel_sfx_player, open_panel_sfx)


func _play_close_panel_sfx() -> void:
	_play_ui_sfx(_panel_sfx_player, close_panel_sfx)


func _play_close_detail_sfx() -> void:
	_play_ui_sfx(_panel_sfx_player, close_detail_sfx)


func _play_hover_sfx() -> void:
	_play_ui_sfx(_hover_sfx_player, hover_sfx)


func _play_confirm_sfx() -> void:
	_play_ui_sfx(_confirm_sfx_player, confirm_sfx)


func _play_ui_sfx(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()


func _on_detail_navigation_moved(_index: int) -> void:
	_play_hover_sfx()


func _on_detail_confirmed() -> void:
	_play_confirm_sfx()
	if _active_tab != Tab.ITEMS or GameState == null:
		return

	var index := _detail_list_panel.get_selected_index()
	var entry := _get_inventory_entry(index)
	if entry.is_empty():
		return

	var item: ItemData = entry.get("item")
	if item == null or not item.can_use():
		return

	_try_use_selected_item(item)


func _try_use_selected_item(item: ItemData) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return

	var player_interactor := player.get_node_or_null("Area2D") as PlayerInteractor
	if player_interactor == null:
		return

	if item.is_phone:
		if not PhoneUse.can_use():
			return
		_close_panel()
		PhoneUse.run_use(player_interactor)
		return

	if item.is_meal_item():
		_close_panel()
		if not FoodUse.is_dining_table_available(player_interactor, player):
			player_interactor.show_text(item.get_use_blocked_message())
			return

		await FoodUse.run_eat_sequence(self, player_interactor, item)
		return

func _refresh_tab_visuals() -> void:
	_menu_breath.stop()
	var half_cycle: float = menu_breath_cycle_duration * 0.5
	for index in _menu_rows.size():
		var row: PanelContainer = _menu_rows[index]
		if index == int(_active_tab):
			var template: StyleBoxFlat = row.get_meta("_selected_style") as StyleBoxFlat
			var style: StyleBoxFlat = _menu_breath.start(self, template, half_cycle)
			_apply_menu_row_style(row, style)
		else:
			_apply_menu_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)


func _refresh_all() -> void:
	_refresh_status()
	if _detail_menu_open:
		_apply_detail_binding(_active_tab)
		_detail_list_panel.refresh()


func _on_tasks_changed() -> void:
	if visible and _detail_menu_open and _active_tab == Tab.READ:
		_detail_list_panel.refresh()


func _refresh_status() -> void:
	if GameState == null:
		return
	time_value.text = "第 %d 天 / %s" % [GameState.day, GameState.period_to_display_name(GameState.period)]
	hunger_value.text = GameState.get_hunger_label()
	sanity_value.text = GameState.get_sanity_label()
	money_value.text = GameState.get_money_label()


func _on_time_changed(_day: int, _period: int) -> void:
	_refresh_status()


func _on_inventory_changed() -> void:
	if visible and _detail_menu_open and _active_tab == Tab.ITEMS:
		_detail_list_panel.refresh()


func _exit_tree() -> void:
	_menu_breath.stop()
	if visible:
		get_tree().paused = false

extends CanvasLayer

enum Tab {
	ITEMS,
	READ,
}

@export_file("*.tscn") var title_scene_path: String = "res://scenes/title_screen.tscn"
@export var panel_toggle_action: StringName = &"ui_cancel"
@export var player_display_name: String = "玩家"
@export_range(0.4, 4.0, 0.05) var menu_breath_cycle_duration := 1.2
@export var main_menu_width := 640.0
@export var item_menu_columns := 2
@export var item_slot_min_width := 148.0

const MENU_ROW_HEIGHT := 34.0

@onready var main_menu_root: Control = $MainMenuRoot
@onready var menu_panel: PanelContainer = $MainMenuRoot/MenuPanel
@onready var item_menu_root: Control = $MainMenuRoot/StatusPanel/Margin/StatusContent/ItemMenuRoot
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
@onready var inspect_label: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/ItemMenuRoot/DescriptionPanel/Margin/InspectLabel
@onready var item_list: GridContainer = $MainMenuRoot/StatusPanel/Margin/StatusContent/ItemMenuRoot/ListPanel/Margin/ItemList
@onready var read_menu_root: Control = $MainMenuRoot/StatusPanel/Margin/StatusContent/ReadMenuRoot
@onready var read_detail_label: Label = $MainMenuRoot/StatusPanel/Margin/StatusContent/ReadMenuRoot/DescriptionPanel/Margin/ReadDetailLabel
@onready var read_list: VBoxContainer = $MainMenuRoot/StatusPanel/Margin/StatusContent/ReadMenuRoot/ListPanel/Margin/ReadList

var _active_tab: Tab = Tab.ITEMS
var _item_menu_open: bool = false
var _read_menu_open: bool = false
var _selected_item_index: int = -1
var _selected_read_index: int = -1
var _item_rows: Array[PanelContainer] = []
var _read_rows: Array[PanelContainer] = []
var _menu_rows: Array[PanelContainer] = []
var _menu_breath_tween: Tween
var _menu_breath_style: StyleBoxFlat
var _menu_breath_row: PanelContainer
var _item_breath_tween: Tween
var _item_breath_style: StyleBoxFlat
var _item_breath_row: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_apply_panel_styles()
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
	_close_item_menu()
	_close_read_menu()
	call_deferred("_apply_main_menu_layout")
	call_deferred("_apply_avatar_size")


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
	$MainMenuRoot/StatusPanel/Margin/StatusContent/ItemMenuRoot/DescriptionPanel.add_theme_stylebox_override("panel", list_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/ItemMenuRoot/ListPanel.add_theme_stylebox_override("panel", list_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/ReadMenuRoot/DescriptionPanel.add_theme_stylebox_override("panel", list_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/ReadMenuRoot/ListPanel.add_theme_stylebox_override("panel", list_style)
	$MainMenuRoot/StatusPanel/Margin/StatusContent/StatusBody/AvatarSlot/AvatarFrame.add_theme_stylebox_override(
		"panel", RpgUiStyle.make_avatar_style(4.0)
	)


func _apply_main_menu_layout() -> void:
	if main_menu_root == null:
		return
	var half_width: float = main_menu_width * 0.5
	main_menu_root.set_anchor(SIDE_LEFT, 0.5)
	main_menu_root.set_anchor(SIDE_RIGHT, 0.5)
	main_menu_root.set_anchor(SIDE_TOP, 1.0)
	main_menu_root.set_anchor(SIDE_BOTTOM, 1.0)
	main_menu_root.offset_left = -half_width
	main_menu_root.offset_right = half_width


func _apply_avatar_size() -> void:
	if status_content == null or avatar_slot == null:
		return
	var max_side: float = status_content.size.y
	if max_side <= 0.0:
		max_side = 104.0
	max_side = clampf(max_side - 2.0, 56.0, 104.0)
	avatar_slot.custom_minimum_size = Vector2(max_side, max_side)


func _refresh_status_panel_content() -> void:
	var show_item_menu: bool = _item_menu_open and _active_tab == Tab.ITEMS
	var show_read_menu: bool = _read_menu_open and _active_tab == Tab.READ
	item_menu_root.visible = show_item_menu
	read_menu_root.visible = show_read_menu
	status_body.visible = not show_item_menu and not show_read_menu


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if _is_toggle_input(event) and not _is_title_scene():
			_open_panel()
			get_viewport().set_input_as_handled()
		return

	if _is_toggle_input(event):
		if _item_menu_open:
			_close_item_menu()
		elif _read_menu_open:
			_close_read_menu()
		else:
			_close_panel()
		get_viewport().set_input_as_handled()
		return

	if _item_menu_open:
		_handle_item_menu_input(event)
		return

	if _read_menu_open:
		_handle_read_menu_input(event)
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
		if _active_tab == Tab.ITEMS:
			_open_item_menu()
		elif _active_tab == Tab.READ:
			_open_read_menu()
		get_viewport().set_input_as_handled()


func _handle_read_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("up"):
		_move_read_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down"):
		_move_read_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_update_selected_read_description()
		get_viewport().set_input_as_handled()


func _handle_item_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("up"):
		_move_item_selection_grid(0, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("down"):
		_move_item_selection_grid(0, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("left"):
		_move_item_selection_grid(-1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		_move_item_selection_grid(1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_inspect_selected_item()
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


func _open_panel() -> void:
	_refresh_all()
	_set_active_tab(Tab.ITEMS)
	_close_item_menu()
	_close_read_menu()
	main_menu_root.show()
	show()
	get_tree().paused = true
	call_deferred("_apply_main_menu_layout")
	call_deferred("_apply_avatar_size")


func _close_panel() -> void:
	_close_item_menu()
	_close_read_menu()
	_stop_menu_row_breath()
	_stop_item_row_breath()
	hide()
	get_tree().paused = false


func _open_item_menu() -> void:
	if _active_tab != Tab.ITEMS:
		return
	_item_menu_open = true
	item_list.columns = item_menu_columns
	_refresh_item_menu()
	_refresh_status_panel_content()


func _close_item_menu() -> void:
	_item_menu_open = false
	_stop_item_row_breath()
	inspect_label.text = ""
	_refresh_status_panel_content()


func _open_read_menu() -> void:
	if _active_tab != Tab.READ:
		return
	_read_menu_open = true
	_refresh_read_menu()
	_refresh_status_panel_content()


func _close_read_menu() -> void:
	_read_menu_open = false
	_stop_item_row_breath()
	read_detail_label.text = ""
	_refresh_status_panel_content()


func _on_scene_changed() -> void:
	if visible and _is_title_scene():
		_close_panel()


func _on_items_row_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_active_tab(Tab.ITEMS)
			_open_item_menu()
			get_viewport().set_input_as_handled()


func _on_read_row_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_active_tab(Tab.READ)
			_open_read_menu()
			get_viewport().set_input_as_handled()


func _set_active_tab(tab: Tab) -> void:
	_active_tab = tab
	_refresh_tab_visuals()
	if tab == Tab.READ:
		_close_item_menu()
	elif tab == Tab.ITEMS:
		_close_read_menu()
	_refresh_status_panel_content()
	call_deferred("_apply_avatar_size")


func _move_tab_selection(step: int) -> void:
	var tab_index: int = int(_active_tab)
	tab_index = posmod(tab_index + step, _menu_rows.size())
	_set_active_tab(tab_index as Tab)


func _refresh_tab_visuals() -> void:
	_stop_menu_row_breath()
	var half_cycle: float = menu_breath_cycle_duration * 0.5
	for index in _menu_rows.size():
		var row: PanelContainer = _menu_rows[index]
		if index == int(_active_tab):
			_start_menu_row_breath(row, half_cycle)
		else:
			_apply_menu_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)


func _start_menu_row_breath(row: PanelContainer, half_cycle: float) -> void:
	_stop_menu_row_breath()
	var template: StyleBoxFlat = row.get_meta("_selected_style") as StyleBoxFlat
	_menu_breath_style = template.duplicate()
	_menu_breath_row = row
	_menu_breath_style.border_color = RpgUiStyle.BREATH_BORDER_MIN
	_apply_menu_row_style(row, _menu_breath_style)

	_menu_breath_tween = create_tween().set_loops()
	_menu_breath_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_menu_breath_tween.tween_property(_menu_breath_style, "border_color", RpgUiStyle.BREATH_BORDER_MAX, half_cycle)
	_menu_breath_tween.tween_property(_menu_breath_style, "border_color", RpgUiStyle.BREATH_BORDER_MIN, half_cycle)


func _stop_menu_row_breath() -> void:
	if _menu_breath_tween != null and _menu_breath_tween.is_valid():
		_menu_breath_tween.kill()
	_menu_breath_tween = null
	_menu_breath_style = null
	_menu_breath_row = null


func _refresh_all() -> void:
	_refresh_status()
	_refresh_item_menu()
	_refresh_read_menu()


func _on_tasks_changed() -> void:
	if visible and _read_menu_open:
		_refresh_read_menu()


func _refresh_status() -> void:
	if GameState == null:
		return
	time_value.text = "第 %d 天 / %s" % [GameState.day, GameState.period_to_display_name(GameState.period)]
	hunger_value.text = str(GameState.hunger)
	sanity_value.text = str(GameState.sanity)
	money_value.text = str(GameState.money)


func _on_time_changed(_day: int, _period: int) -> void:
	_refresh_status()


func _on_inventory_changed() -> void:
	if visible and _item_menu_open:
		_refresh_item_menu()


func _refresh_item_menu() -> void:
	if GameState == null:
		return

	_stop_item_row_breath()
	for child in item_list.get_children():
		child.free()
	_item_rows.clear()

	var previous_selection: String = ""
	if _selected_item_index >= 0 and _selected_item_index < GameState.inventory_items.size():
		previous_selection = GameState.inventory_items[_selected_item_index]

	for item_name in GameState.inventory_items:
		var row: PanelContainer = _create_item_row(String(item_name))
		item_list.add_child(row)
		_item_rows.append(row)

	_selected_item_index = -1
	if not previous_selection.is_empty():
		_selected_item_index = GameState.inventory_items.find(previous_selection)
	if _selected_item_index < 0 and not GameState.inventory_items.is_empty():
		_selected_item_index = 0

	_refresh_item_selection_visuals()


func _create_item_row(item_name: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(item_slot_min_width, 28.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_item_row_gui_input.bind(row))
	row.set_meta("_normal_style", RpgUiStyle.make_item_row_normal_style())
	row.set_meta("_selected_style", RpgUiStyle.make_item_row_selected_style())
	_apply_item_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	var body := HBoxContainer.new()
	margin.add_child(body)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)
	body.add_child(name_label)

	var count_label := Label.new()
	count_label.text = ": 1"
	count_label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)
	body.add_child(count_label)

	return row


func _move_item_selection_grid(column_step: int, row_step: int) -> void:
	if _item_rows.is_empty():
		return
	var columns: int = maxi(item_menu_columns, 1)
	var row_index: int = _selected_item_index / columns
	var column_index: int = _selected_item_index % columns
	column_index += column_step
	row_index += row_step
	var max_row: int = (_item_rows.size() - 1) / columns
	column_index = clampi(column_index, 0, columns - 1)
	row_index = clampi(row_index, 0, max_row)
	var new_index: int = row_index * columns + column_index
	if new_index >= _item_rows.size():
		new_index = _item_rows.size() - 1
	_selected_item_index = new_index
	_refresh_item_selection_visuals()


func _apply_item_row_style(row: PanelContainer, style: StyleBoxFlat) -> void:
	row.add_theme_stylebox_override("panel", style)


func _refresh_item_selection_visuals() -> void:
	_stop_item_row_breath()
	var half_cycle: float = menu_breath_cycle_duration * 0.5
	for index in _item_rows.size():
		var row: PanelContainer = _item_rows[index]
		if index == _selected_item_index:
			_start_item_row_breath(row, half_cycle)
		else:
			_apply_item_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)
	_update_selected_item_description()


func _start_item_row_breath(row: PanelContainer, half_cycle: float) -> void:
	_stop_item_row_breath()
	var template: StyleBoxFlat = row.get_meta("_selected_style") as StyleBoxFlat
	_item_breath_style = template.duplicate()
	_item_breath_row = row
	_item_breath_style.border_color = RpgUiStyle.BREATH_BORDER_MIN
	_apply_item_row_style(row, _item_breath_style)

	_item_breath_tween = create_tween().set_loops()
	_item_breath_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_item_breath_tween.tween_property(_item_breath_style, "border_color", RpgUiStyle.BREATH_BORDER_MAX, half_cycle)
	_item_breath_tween.tween_property(_item_breath_style, "border_color", RpgUiStyle.BREATH_BORDER_MIN, half_cycle)


func _stop_item_row_breath() -> void:
	if _item_breath_tween != null and _item_breath_tween.is_valid():
		_item_breath_tween.kill()
	_item_breath_tween = null
	_item_breath_style = null
	_item_breath_row = null


func _on_item_row_gui_input(event: InputEvent, row: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_item_index = _item_rows.find(row)
			_refresh_item_selection_visuals()
			get_viewport().set_input_as_handled()


func _update_selected_item_description() -> void:
	if GameState == null or _selected_item_index < 0:
		inspect_label.text = ""
		return
	if _selected_item_index >= GameState.inventory_items.size():
		inspect_label.text = ""
		return
	var item_name: String = GameState.inventory_items[_selected_item_index]
	inspect_label.text = GameState.get_item_inspect_message(item_name)


func _inspect_selected_item() -> void:
	_update_selected_item_description()


func _refresh_read_menu() -> void:
	if GameState == null:
		return

	_stop_item_row_breath()
	for child in read_list.get_children():
		child.free()
	_read_rows.clear()

	var previous_selection: String = ""
	if _selected_read_index >= 0 and _selected_read_index < GameState.active_tasks.size():
		previous_selection = GameState.active_tasks[_selected_read_index]

	for task_text in GameState.active_tasks:
		var row: PanelContainer = _create_read_row(String(task_text))
		read_list.add_child(row)
		_read_rows.append(row)

	_selected_read_index = -1
	if not previous_selection.is_empty():
		_selected_read_index = GameState.active_tasks.find(previous_selection)
	if _selected_read_index < 0 and not GameState.active_tasks.is_empty():
		_selected_read_index = 0

	_refresh_read_selection_visuals()


func _create_read_row(task_text: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 28.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_read_row_item_gui_input.bind(row))
	row.set_meta("_normal_style", RpgUiStyle.make_item_row_normal_style())
	row.set_meta("_selected_style", RpgUiStyle.make_item_row_selected_style())
	_apply_item_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	var name_label := Label.new()
	name_label.text = task_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)
	margin.add_child(name_label)

	return row


func _move_read_selection(step: int) -> void:
	if _read_rows.is_empty():
		return
	_selected_read_index = posmod(_selected_read_index + step, _read_rows.size())
	_refresh_read_selection_visuals()


func _refresh_read_selection_visuals() -> void:
	_stop_item_row_breath()
	var half_cycle: float = menu_breath_cycle_duration * 0.5
	for index in _read_rows.size():
		var row: PanelContainer = _read_rows[index]
		if index == _selected_read_index:
			_start_item_row_breath(row, half_cycle)
		else:
			_apply_item_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)
	_update_selected_read_description()


func _update_selected_read_description() -> void:
	if GameState == null or _selected_read_index < 0:
		read_detail_label.text = "读取功能预留"
		return
	if _selected_read_index >= GameState.active_tasks.size():
		read_detail_label.text = "读取功能预留"
		return
	read_detail_label.text = GameState.active_tasks[_selected_read_index]


func _on_read_row_item_gui_input(event: InputEvent, row: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_read_index = _read_rows.find(row)
			_refresh_read_selection_visuals()
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_stop_menu_row_breath()
	_stop_item_row_breath()
	if visible:
		get_tree().paused = false

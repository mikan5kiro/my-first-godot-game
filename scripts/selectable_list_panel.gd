extends Control
class_name SelectableListPanel

## 可复用列表：条目渲染、选中高亮、详情区、键盘/鼠标导航。

signal selection_changed(index: int)
signal navigation_moved(index: int)
signal confirmed

@export_node_path("Container") var list_container_path: NodePath
@export_node_path("Label") var detail_label_path: NodePath
@export_range(0.4, 4.0, 0.05) var breath_cycle_duration := 1.2
@export var columns := 1
@export var slot_min_width := 148.0
@export var empty_detail_text := ""
@export var show_count_suffix := false

var _list_container: Container
var _detail_label: Label
var _get_entries: Callable
var _get_title: Callable
var _get_detail: Callable
var _get_stable_id: Callable

var _entries: Array = []
var _rows: Array[PanelContainer] = []
var _selected_index: int = -1
var _row_breath := BorderBreathAnimator.new()


func _ready() -> void:
	_ensure_nodes()


func bind(
	get_entries: Callable,
	get_title: Callable,
	get_detail: Callable,
	get_stable_id: Callable = Callable(),
) -> void:
	_get_entries = get_entries
	_get_title = get_title
	_get_detail = get_detail
	_get_stable_id = get_stable_id
	_selected_index = -1


func get_selected_index() -> int:
	return _selected_index


func refresh() -> void:
	if not _get_entries.is_valid() or not _ensure_nodes():
		return

	var previous_id := ""
	if _selected_index >= 0 and _selected_index < _entries.size():
		previous_id = _stable_id_for_index(_selected_index)
	_entries = _get_entries.call()
	_rebuild_rows(previous_id)


func try_handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("up"):
		move_selection_grid(0, -1)
		return true
	if event.is_action_pressed("down"):
		move_selection_grid(0, 1)
		return true
	if event.is_action_pressed("left") and _uses_grid_navigation():
		move_selection_grid(-1, 0)
		return true
	if event.is_action_pressed("right") and _uses_grid_navigation():
		move_selection_grid(1, 0)
		return true
	if event.is_action_pressed("interact"):
		_refresh_detail()
		confirmed.emit()
		return true
	return false


func clear_detail() -> void:
	_row_breath.stop()
	if _detail_label != null:
		_detail_label.text = ""


func move_selection_grid(column_step: int, row_step: int) -> void:
	if _rows.is_empty():
		return
	var previous_index := _selected_index
	if _uses_grid_navigation():
		_move_grid(column_step, row_step)
	else:
		_move_linear(row_step)
	_refresh_selection_visuals()
	if _selected_index != previous_index:
		navigation_moved.emit(_selected_index)


func _uses_grid_navigation() -> bool:
	return _list_container is GridContainer and columns > 1


func _move_linear(row_step: int) -> void:
	if row_step == 0:
		return
	_selected_index = posmod(_selected_index + row_step, _rows.size())


func _move_grid(column_step: int, row_step: int) -> void:
	var grid_columns: int = maxi(columns, 1)
	var row_index: int = _selected_index / grid_columns
	var column_index: int = _selected_index % grid_columns
	column_index += column_step
	row_index += row_step
	var max_row: int = (_rows.size() - 1) / grid_columns
	column_index = clampi(column_index, 0, grid_columns - 1)
	row_index = clampi(row_index, 0, max_row)
	var new_index: int = row_index * grid_columns + column_index
	if new_index >= _rows.size():
		new_index = _rows.size() - 1
	_selected_index = new_index


func _ensure_nodes() -> bool:
	if _list_container == null and not list_container_path.is_empty():
		_list_container = get_node_or_null(list_container_path) as Container
	if _detail_label == null and not detail_label_path.is_empty():
		_detail_label = get_node_or_null(detail_label_path) as Label
	return _list_container != null


func _rebuild_rows(previous_id: String) -> void:
	if _list_container == null:
		return

	_row_breath.stop()
	for child in _list_container.get_children():
		child.free()
	_rows.clear()

	if _list_container is GridContainer:
		(_list_container as GridContainer).columns = maxi(columns, 1)

	for index in _entries.size():
		var title: String = String(_get_title.call(index)) if _get_title.is_valid() else ""
		var row := _create_row(title)
		_list_container.add_child(row)
		_rows.append(row)

	_selected_index = -1
	if not previous_id.is_empty():
		for index in _entries.size():
			if _stable_id_for_index(index) == previous_id:
				_selected_index = index
				break
	if _selected_index < 0 and not _entries.is_empty():
		_selected_index = 0

	_refresh_selection_visuals()


func _create_row(title: String) -> PanelContainer:
	var row := PanelContainer.new()
	var min_width: float = slot_min_width if _uses_grid_navigation() else 0.0
	row.custom_minimum_size = Vector2(min_width, 28.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_gui_input.bind(row))
	row.set_meta("_normal_style", RpgUiStyle.make_item_row_normal_style())
	row.set_meta("_selected_style", RpgUiStyle.make_item_row_selected_style())
	_apply_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	if show_count_suffix:
		var body := HBoxContainer.new()
		margin.add_child(body)

		var name_label := Label.new()
		name_label.text = title
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)
		body.add_child(name_label)

		var count_label := Label.new()
		count_label.text = ": 1"
		count_label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)
		body.add_child(count_label)
	else:
		var name_label := Label.new()
		name_label.text = title
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL)
		margin.add_child(name_label)

	return row


func _refresh_selection_visuals() -> void:
	_row_breath.stop()
	var half_cycle: float = breath_cycle_duration * 0.5
	for index in _rows.size():
		var row: PanelContainer = _rows[index]
		if index == _selected_index:
			var template: StyleBoxFlat = row.get_meta("_selected_style") as StyleBoxFlat
			var style: StyleBoxFlat = _row_breath.start(self, template, half_cycle)
			_apply_row_style(row, style)
		else:
			_apply_row_style(row, row.get_meta("_normal_style") as StyleBoxFlat)
	_refresh_detail()
	selection_changed.emit(_selected_index)


func _refresh_detail() -> void:
	if _detail_label == null:
		return
	if not _get_detail.is_valid() or _selected_index < 0 or _selected_index >= _entries.size():
		_detail_label.text = empty_detail_text
		return
	_detail_label.text = String(_get_detail.call(_selected_index))


func _stable_id_for_index(index: int) -> String:
	if index < 0 or index >= _entries.size():
		return ""
	if _get_stable_id.is_valid():
		return String(_get_stable_id.call(index))
	return str(index)


func _apply_row_style(row: PanelContainer, style: StyleBoxFlat) -> void:
	row.add_theme_stylebox_override("panel", style)


func _on_row_gui_input(event: InputEvent, row: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var previous_index := _selected_index
			_selected_index = _rows.find(row)
			_refresh_selection_visuals()
			if _selected_index != previous_index:
				navigation_moved.emit(_selected_index)
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_row_breath.stop()

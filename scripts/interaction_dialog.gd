extends CanvasLayer
class_name InteractionDialog

enum DialogMode {
	NARRATION,
	CHARACTER,
}

const PANEL_HEIGHT := 112.0
const CHOICE_ROW_HEIGHT := 20.0
const CHOICE_CURSOR_WIDTH := 14.0

@onready var panel: PanelContainer = $Panel
@onready var avatar_slot: AspectRatioContainer = $Panel/Margin/Content/TextRow/AvatarSlot
@onready var avatar_frame: PanelContainer = $Panel/Margin/Content/TextRow/AvatarSlot/AvatarFrame
@onready var avatar_image: TextureRect = $Panel/Margin/Content/TextRow/AvatarSlot/AvatarFrame/AvatarContent/AvatarImage
@onready var text_label: Label = $Panel/Margin/Content/TextRow/TextColumn/TextLabel
@onready var choices_container: VBoxContainer = $Panel/Margin/Content/ChoicesContainer

var _choice_rows: Array[PanelContainer] = []
var _dialog_mode: DialogMode = DialogMode.NARRATION


func _ready() -> void:
	layer = 100
	_apply_styles()
	hide_dialog()


func _apply_styles() -> void:
	panel.add_theme_stylebox_override("panel", RpgUiStyle.make_box_style(8.0))
	avatar_frame.add_theme_stylebox_override("panel", RpgUiStyle.make_avatar_style(4.0))
	RpgUiStyle.apply_dialog_label_theme(text_label)


func show_dialog() -> void:
	panel.show()


func hide_dialog() -> void:
	panel.hide()
	text_label.text = ""
	set_dialog_mode(DialogMode.NARRATION)
	clear_choices()


func set_dialog_mode(mode: DialogMode) -> void:
	_dialog_mode = mode
	var show_avatar := mode == DialogMode.CHARACTER
	if avatar_slot != null:
		avatar_slot.visible = show_avatar
	if avatar_image != null:
		avatar_image.visible = show_avatar


func set_text(value: String) -> void:
	text_label.text = value


func set_choices(labels: PackedStringArray, selected_index: int) -> void:
	clear_choices()
	if labels.is_empty():
		return

	for index in labels.size():
		var row := _create_choice_row(labels[index], index == selected_index)
		choices_container.add_child(row)
		_choice_rows.append(row)

	choices_container.show()


func clear_choices() -> void:
	for row in _choice_rows:
		if is_instance_valid(row):
			row.queue_free()
	_choice_rows.clear()
	if choices_container != null:
		choices_container.hide()
	_set_panel_height(PANEL_HEIGHT)


func _create_choice_row(label_text: String, selected: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, CHOICE_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := RpgUiStyle.make_item_row_selected_style() if selected else RpgUiStyle.make_item_row_normal_style()
	row.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 1)
	row.add_child(margin)

	var row_body := HBoxContainer.new()
	row_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row_body)

	var cursor := ChoiceRowCursor.new()
	cursor.show_marker = selected
	cursor.marker_color = RpgUiStyle.TEXT_NORMAL if selected else RpgUiStyle.TEXT_DIM
	cursor.custom_minimum_size = Vector2(CHOICE_CURSOR_WIDTH, 0)
	cursor.size_flags_vertical = Control.SIZE_FILL
	row_body.add_child(cursor)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", RpgUiStyle.TEXT_NORMAL if selected else RpgUiStyle.TEXT_DIM)
	label.add_theme_font_size_override("font_size", RpgUiStyle.DIALOG_FONT_SIZE)
	row_body.add_child(label)

	return row


class ChoiceRowCursor extends Control:
	var show_marker := false
	var marker_color := Color.WHITE

	func _draw() -> void:
		if not show_marker:
			return
		var h := size.y
		if h < 4.0:
			return
		var mid_y := h * 0.5
		var tip_x := CHOICE_CURSOR_WIDTH - 3.0
		var pts := PackedVector2Array([
			Vector2(2.0, 3.0),
			Vector2(2.0, h - 3.0),
			Vector2(tip_x, mid_y),
		])
		draw_colored_polygon(pts, marker_color)


func _set_panel_height(height: float) -> void:
	if panel == null:
		return
	panel.offset_top = -height
	panel.offset_bottom = -RpgUiStyle.BOTTOM_PANEL_BOTTOM_OFFSET

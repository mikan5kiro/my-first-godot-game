extends RefCounted
class_name RpgUiStyle

const LABEL_ACCENT := Color(0.58, 0.78, 0.95, 1)
const TEXT_NORMAL := Color(0.95, 0.98, 1, 1)
const TEXT_DIM := Color(0.72, 0.76, 0.82, 0.85)
const BOTTOM_PANEL_WIDTH := 640.0
const BOTTOM_PANEL_BOTTOM_OFFSET := 12.0
const BOTTOM_PANEL_HEIGHT := 136.0
const BOTTOM_DIALOG_HEIGHT := 88.0
const DIALOG_FONT_SIZE := 16
const MENU_ROW_MARGIN := 4.0
const MENU_ROW_BORDER := 2
const SELECTED_BORDER := Color(0.93, 0.96, 1, 0.9)
const BREATH_BORDER_MIN := Color(0.58, 0.62, 0.74, 0.45)
const BREATH_BORDER_MAX := SELECTED_BORDER


static func _apply_menu_row_layout(style: StyleBoxFlat, content_margin: float) -> void:
	style.border_width_left = MENU_ROW_BORDER
	style.border_width_top = MENU_ROW_BORDER
	style.border_width_right = MENU_ROW_BORDER
	style.border_width_bottom = MENU_ROW_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.anti_aliasing = true


static func make_menu_row_normal_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.6, 0.67, 0.78, 0)
	_apply_menu_row_layout(style, MENU_ROW_MARGIN)
	return style


static func make_menu_row_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.19, 0.28, 0.85)
	style.border_color = SELECTED_BORDER
	_apply_menu_row_layout(style, MENU_ROW_MARGIN)
	return style


static func make_item_row_normal_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.6, 0.67, 0.78, 0)
	_apply_menu_row_layout(style, 2.0)
	return style


static func make_item_row_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.19, 0.28, 0.85)
	style.border_color = SELECTED_BORDER
	_apply_menu_row_layout(style, 2.0)
	return style


static func make_box_style(content_margin: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.67, 0.78, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.anti_aliasing = true
	return style


static func make_selection_style(content_margin: float = 6.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.19, 0.28, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.93, 0.96, 1, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.anti_aliasing = true
	return style


static func make_avatar_style(content_margin: float = 4.0) -> StyleBoxFlat:
	var style := make_box_style(content_margin)
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.45, 0.48, 0.56, 1)
	return style


static func apply_bottom_panel_layout(control: Control, height: float = BOTTOM_PANEL_HEIGHT) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half_width: float = BOTTOM_PANEL_WIDTH * 0.5
	control.offset_left = -half_width
	control.offset_top = -height
	control.offset_right = half_width
	control.offset_bottom = -BOTTOM_PANEL_BOTTOM_OFFSET
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH


static func apply_dialog_label_theme(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_NORMAL)
	label.add_theme_font_size_override("font_size", DIALOG_FONT_SIZE)

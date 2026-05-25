extends CanvasLayer
class_name InteractionDialog

@onready var panel: PanelContainer = $Panel
@onready var text_label: Label = $Panel/Margin/TextLabel


func _ready() -> void:
	layer = 100
	_apply_styles()
	hide_dialog()


func _apply_styles() -> void:
	panel.add_theme_stylebox_override("panel", RpgUiStyle.make_box_style(8.0))
	RpgUiStyle.apply_dialog_label_theme(text_label)


func show_dialog() -> void:
	panel.show()


func hide_dialog() -> void:
	panel.hide()
	text_label.text = ""


func set_text(value: String) -> void:
	text_label.text = value

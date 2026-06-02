extends PanelContainer
class_name StatusPanelView

## 与 ESC 人物面板一致的状态展示区，可绑定 GameState 或存档数据。

const HIDDEN_STAT_LABEL := "？？？"

@export var player_display_name: String = "主人公"

@onready var player_name_label: Label = $Margin/StatusContent/StatusBody/InfoColumn/PlayerName
@onready var time_value: Label = $Margin/StatusContent/StatusBody/InfoColumn/StatGrid/TimeRow/Value
@onready var hunger_value: Label = $Margin/StatusContent/StatusBody/InfoColumn/StatGrid/StatsRow/HungerRow/Value
@onready var sanity_value: Label = $Margin/StatusContent/StatusBody/InfoColumn/StatGrid/StatsRow/SanityRow/Value
@onready var money_value: Label = $Margin/StatusContent/StatusBody/InfoColumn/StatGrid/StatsRow/MoneyRow/Value
@onready var status_content: VBoxContainer = $Margin/StatusContent
@onready var slot_title_label: Label = $Margin/StatusContent/SlotTitle
@onready var status_body: HBoxContainer = $Margin/StatusContent/StatusBody
@onready var avatar_slot: AspectRatioContainer = $Margin/StatusContent/StatusBody/AvatarSlot


func _ready() -> void:
	_apply_panel_styles()
	status_content.resized.connect(_apply_avatar_size)
	call_deferred("_apply_avatar_size")


func apply_from_game_state() -> void:
	if GameState == null:
		apply_empty_slot()
		return

	apply_labels({
		"player_name": player_display_name,
		"time": HIDDEN_STAT_LABEL,
		"hunger": HIDDEN_STAT_LABEL,
		"sanity": HIDDEN_STAT_LABEL,
		"money": HIDDEN_STAT_LABEL,
	})


func apply_from_save_data(data: Dictionary) -> void:
	if GameState == null:
		apply_empty_slot()
		return
	var labels := GameState.get_status_labels_from_data(data, player_display_name)
	labels["time"] = HIDDEN_STAT_LABEL
	labels["hunger"] = HIDDEN_STAT_LABEL
	labels["sanity"] = HIDDEN_STAT_LABEL
	labels["money"] = HIDDEN_STAT_LABEL
	apply_labels(labels)


func apply_empty_slot() -> void:
	apply_labels({
		"player_name": "空档案",
		"time": "--",
		"hunger": "--",
		"sanity": "--",
		"money": "--",
	})


func set_slot_title(text: String) -> void:
	if slot_title_label == null:
		return
	slot_title_label.text = text
	slot_title_label.visible = not text.is_empty()


func apply_blank_slot() -> void:
	status_body.visible = false
	player_name_label.text = ""
	time_value.text = ""
	hunger_value.text = ""
	sanity_value.text = ""
	money_value.text = ""


func apply_labels(labels: Dictionary) -> void:
	status_body.visible = true
	player_name_label.text = str(labels.get("player_name", player_display_name))
	time_value.text = str(labels.get("time", "--"))
	hunger_value.text = str(labels.get("hunger", "--"))
	sanity_value.text = str(labels.get("sanity", "--"))
	money_value.text = str(labels.get("money", "--"))


func _apply_panel_styles() -> void:
	add_theme_stylebox_override("panel", RpgUiStyle.make_box_style(8.0))
	$Margin/StatusContent/StatusBody/AvatarSlot/AvatarFrame.add_theme_stylebox_override(
		"panel", RpgUiStyle.make_avatar_style(4.0)
	)


func _apply_avatar_size() -> void:
	if status_content == null or avatar_slot == null or status_body == null:
		return
	if not status_body.visible:
		return
	var max_side: float = status_body.size.y
	if max_side <= 0.0:
		max_side = status_content.size.y - slot_title_label.size.y - 4.0
	if max_side <= 0.0:
		max_side = 88.0
	max_side = clampf(max_side - 2.0, 48.0, 88.0)
	avatar_slot.custom_minimum_size = Vector2(max_side, max_side)

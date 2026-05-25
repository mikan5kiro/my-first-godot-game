extends Area2D
class_name PlayerInteractor

# 玩家交互检测器：
# - 挂在玩家的 Area2D 上（这个 Area2D 就是“交互检测范围”）
# - 按下 interact 时由 player.gd 调用 try_interact(player)
# - 目标选择委托 InteractionSelector；对话委托 DialogPresenter / MonologuePlayer

@export var typewriter_chars_per_sec: float = 36.0
@export var type_sfx_enabled: bool = true
@export var type_sfx_bus: StringName = &"Master"
@export_range(0.0, 1.0, 0.01) var type_sfx_char_chance: float = 0.75
@export var dialog_scene: PackedScene = preload("res://scenes/interaction_dialog.tscn")

var _dialog_presenter: DialogPresenter
var _monologue_player: MonologuePlayer


func _ready() -> void:
	_dialog_presenter = DialogPresenter.new()
	_dialog_presenter.typewriter_chars_per_sec = typewriter_chars_per_sec
	_dialog_presenter.type_sfx_enabled = type_sfx_enabled
	_dialog_presenter.type_sfx_bus = type_sfx_bus
	_dialog_presenter.type_sfx_char_chance = type_sfx_char_chance
	_dialog_presenter.dialog_scene = dialog_scene
	add_child(_dialog_presenter)

	_monologue_player = MonologuePlayer.new()
	_monologue_player.setup(_dialog_presenter)
	add_child(_monologue_player)


func try_interact(interactor: Node2D) -> void:
	if _dialog_presenter.is_visible():
		if _dialog_presenter.is_typing():
			_dialog_presenter.skip_typing()
		elif _monologue_player.is_active():
			_monologue_player.request_advance()
		else:
			hide_text_immediately()
		return

	var target := InteractionSelector.find_best(self, get_overlapping_areas(), interactor)
	if target == null:
		return

	var result: String = target.interact(interactor)
	if not result.is_empty():
		_dialog_presenter.show_text(result)


func is_text_visible() -> bool:
	return _dialog_presenter.is_visible()


func play_monologue_lines(lines: PackedStringArray) -> void:
	await _monologue_player.play_lines(lines)


func hide_text_immediately() -> void:
	_monologue_player.cancel()
	_dialog_presenter.hide()

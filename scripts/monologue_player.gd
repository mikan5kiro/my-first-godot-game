extends Node
class_name MonologuePlayer

## 多句独白：逐句打字，按交互键切下一句，最后一句后关闭。

var _presenter: DialogPresenter
var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1
var _active: bool = false
var _advance_requested: bool = false


func setup(presenter: DialogPresenter) -> void:
	_presenter = presenter


func is_active() -> bool:
	return _active


func request_advance() -> void:
	_advance_requested = true


func cancel() -> void:
	_active = false
	_advance_requested = false
	_lines = PackedStringArray()
	_index = -1


func play_lines(lines: PackedStringArray) -> void:
	if lines.is_empty() or _presenter == null:
		return
	_lines = lines
	_index = 0
	_active = true
	_advance_requested = false
	_presenter.show_text(lines[0])
	while _active:
		if _advance_requested:
			_advance_requested = false
			_advance_line()
		await get_tree().process_frame


func _advance_line() -> void:
	if _index < _lines.size() - 1:
		_index += 1
		_presenter.show_text(_lines[_index])
	else:
		cancel()
		_presenter.hide()

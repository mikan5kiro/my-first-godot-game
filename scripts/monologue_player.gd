extends Node
class_name MonologuePlayer

## 多句独白：逐句打字，按交互键切下一句，最后一句后关闭。
## 文本行以 @ 开头表示角色说话，其余为旁白。

var _presenter: DialogPresenter
var _lines: Array[DialogLine] = []
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
	_lines = []
	_index = -1


func play_lines(lines: PackedStringArray) -> void:
	await play_dialog_lines(DialogTextLoader.lines_from_strings(lines))


func play_dialog_lines(lines: Array[DialogLine]) -> void:
	if lines.is_empty() or _presenter == null:
		return
	_lines = lines
	_index = 0
	_active = true
	_advance_requested = false
	_show_line(_lines[0])
	while _active:
		if _advance_requested:
			_advance_requested = false
			_advance_line()
		await get_tree().process_frame


func _show_line(line: DialogLine) -> void:
	var mode := InteractionDialog.DialogMode.CHARACTER if line.dialog_type == DialogLine.Type.CHARACTER else InteractionDialog.DialogMode.NARRATION
	_presenter.show_text(line.text, mode)


func _advance_line() -> void:
	if _index < _lines.size() - 1:
		_index += 1
		_show_line(_lines[_index])
	else:
		cancel()
		_presenter.hide()

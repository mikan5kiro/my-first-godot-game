extends Node
class_name MonologuePlayer

## 多句独白：逐句打字，按交互键切下一句，最后一句后关闭。
## 文本行以 @ 开头表示角色说话，其余为旁白。
## [pause 1.0] 表示收起对话框并等待指定秒数后自动推进。
const PAUSE_SENTINEL_PREFIX := "__pause__:"

var _presenter: DialogPresenter
var _lines: Array[DialogLine] = []
var _index: int = -1
var _active: bool = false
var _advance_requested: bool = false
var _is_waiting_pause: bool = false
var _pause_timer: Timer


func setup(presenter: DialogPresenter) -> void:
	_presenter = presenter
	_ensure_pause_timer()


func is_active() -> bool:
	return _active


func is_waiting_pause() -> bool:
	return _is_waiting_pause


func request_advance() -> void:
	if _is_waiting_pause:
		return
	_advance_requested = true


func cancel() -> void:
	_active = false
	_advance_requested = false
	_is_waiting_pause = false
	if _pause_timer != null:
		_pause_timer.stop()
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
	_is_waiting_pause = false
	_ensure_pause_timer()
	_show_line(_lines[0])
	while _active:
		if _advance_requested and not _is_waiting_pause:
			_advance_requested = false
			_advance_line()
		await get_tree().process_frame


func _show_line(line: DialogLine) -> void:
	var pause_seconds := _extract_pause_seconds(line.text)
	if pause_seconds >= 0.0:
		_start_pause(pause_seconds)
		return
	if line.play_item_obtained_sfx and GameState != null:
		GameState.play_item_obtained_sfx()
	var mode := InteractionDialog.DialogMode.CHARACTER if line.dialog_type == DialogLine.Type.CHARACTER else InteractionDialog.DialogMode.NARRATION
	_presenter.show_text(line.text, mode)


func _advance_line() -> void:
	if _index < _lines.size() - 1:
		_index += 1
		_show_line(_lines[_index])
	else:
		cancel()
		_presenter.hide()


func _ensure_pause_timer() -> void:
	if _pause_timer != null:
		return
	_pause_timer = Timer.new()
	_pause_timer.one_shot = true
	_pause_timer.timeout.connect(_on_pause_timeout)
	add_child(_pause_timer)


func _start_pause(seconds: float) -> void:
	_presenter.hide()
	_is_waiting_pause = true
	_advance_requested = false
	if _pause_timer == null:
		_ensure_pause_timer()
	var pause_seconds := maxf(seconds, 0.0)
	if pause_seconds <= 0.0:
		_on_pause_timeout()
		return
	_pause_timer.start(pause_seconds)


func _on_pause_timeout() -> void:
	if not _active:
		return
	_is_waiting_pause = false
	_advance_line()


func _extract_pause_seconds(text: String) -> float:
	if not text.begins_with(PAUSE_SENTINEL_PREFIX):
		return -1.0
	var value_text := text.substr(PAUSE_SENTINEL_PREFIX.length()).strip_edges()
	if value_text.is_empty():
		return 0.0
	return maxf(value_text.to_float(), 0.0)

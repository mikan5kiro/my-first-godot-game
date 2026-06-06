extends Node

## F11 切换全屏/窗口，并优先保持整数缩放清晰度。

@export var toggle_action: StringName = &"toggle_fullscreen"
@export var toggle_key: Key = KEY_F11

var _last_windowed_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_ensure_toggle_action()
	_apply_clarity_defaults()
	if OS.has_feature("web"):
		_setup_web_viewport()
	else:
		_apply_default_windowed_1x()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(toggle_action):
		return
	if event is InputEventKey and event.is_echo():
		return
	_toggle_window_mode()
	get_viewport().set_input_as_handled()


func _toggle_window_mode() -> void:
	var window := get_window()
	if window == null:
		return

	var window_id := window.get_window_id()
	var mode := DisplayServer.window_get_mode(window_id)

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
		if _last_windowed_size.x <= 0 or _last_windowed_size.y <= 0:
			_last_windowed_size = _base_viewport_size()
		window.size = _last_windowed_size
		window.move_to_center()
		return

	_last_windowed_size = window.size
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, window_id)


func _base_viewport_size() -> Vector2i:
	var base_width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 960))
	var base_height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 540))
	return Vector2i(maxi(1, base_width), maxi(1, base_height))


func _apply_clarity_defaults() -> void:
	# 运行时兜底，防止工程设置被改动后出现模糊缩放。
	ProjectSettings.set_setting("display/window/dpi/allow_hidpi", true)
	ProjectSettings.set_setting("display/window/stretch/scale_mode", "integer")
	ProjectSettings.set_setting("display/window/stretch/aspect", "keep")


func _setup_web_viewport() -> void:
	var window := get_window()
	if window == null:
		return
	if not window.size_changed.is_connected(_on_web_window_size_changed):
		window.size_changed.connect(_on_web_window_size_changed)
	call_deferred("_sync_web_viewport_stretch")


func _on_web_window_size_changed() -> void:
	call_deferred("_sync_web_viewport_stretch")


func _sync_web_viewport_stretch() -> void:
	var window := get_window()
	if window == null:
		return
	# Web 嵌入 canvas 尺寸常在首帧后才稳定；刷新 content scale 触发 stretch 重算。
	window.content_scale_size = _base_viewport_size()


func _apply_default_windowed_1x() -> void:
	var window := get_window()
	if window == null:
		return
	var window_id := window.get_window_id()
	var base_size := _base_viewport_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
	window.size = base_size
	window.move_to_center()
	_last_windowed_size = base_size


func _ensure_toggle_action() -> void:
	if not InputMap.has_action(toggle_action):
		InputMap.add_action(toggle_action)
	if _has_key_binding(toggle_action, toggle_key):
		return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = toggle_key
	InputMap.action_add_event(toggle_action, key_event)


func _has_key_binding(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false

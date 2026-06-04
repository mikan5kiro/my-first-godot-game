extends Node

## 开发者截图工具：按键后保存当前整屏到指定目录。

@export var enabled: bool = true
@export var screenshot_action: StringName = &"dev_screenshot"
@export var screenshot_key: Key = KEY_F12
@export var screenshot_dir: String = "res://screenshots"
@export var filename_prefix: String = "devshot_"
@export var developer_only: bool = true


func _ready() -> void:
	if developer_only and not _is_developer_runtime():
		enabled = false
		return
	_ensure_input_action()
	set_process_input(true)
	set_process_unhandled_input(true)


func _input(event: InputEvent) -> void:
	_try_handle_capture(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_handle_capture(event)


func _try_handle_capture(event: InputEvent) -> void:
	if not enabled:
		return
	if not event.is_action_pressed(screenshot_action):
		return
	if event is InputEventKey and event.is_echo():
		return

	get_viewport().set_input_as_handled()
	_capture_screenshot.call_deferred()


func _ensure_input_action() -> void:
	if InputMap.has_action(screenshot_action):
		return

	InputMap.add_action(screenshot_action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = screenshot_key
	InputMap.action_add_event(screenshot_action, key_event)


func _capture_screenshot() -> void:
	await RenderingServer.frame_post_draw

	var viewport := get_viewport()
	if viewport == null:
		push_warning("DevScreenshot: 当前无可用视口，截图失败。")
		return

	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_warning("DevScreenshot: 未获取到画面图像，截图失败。")
		return

	var normalized_dir := screenshot_dir.strip_edges()
	if normalized_dir.is_empty():
		normalized_dir = "res://screenshots"
	if normalized_dir.ends_with("/"):
		normalized_dir = normalized_dir.trim_suffix("/")

	var absolute_dir := ProjectSettings.globalize_path(normalized_dir)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_dir_error != OK:
		push_warning("DevScreenshot: 无法创建目录 %s (错误码: %d)" % [normalized_dir, make_dir_error])
		return

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file_path := "%s/%s%s.png" % [absolute_dir, filename_prefix, timestamp]
	var save_error := image.save_png(file_path)
	if save_error != OK:
		push_warning("DevScreenshot: 保存截图失败 %s (错误码: %d)" % [file_path, save_error])
		return

	print("DevScreenshot: 已保存截图 -> %s" % file_path)


func _is_developer_runtime() -> bool:
	return Engine.is_editor_hint() or OS.is_debug_build()

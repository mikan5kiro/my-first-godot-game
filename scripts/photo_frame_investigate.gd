extends Interactable
class_name PhotoFrameInvestigateItem

const CHOICE_YES := "yes"
const CHOICE_NO := "no"
const MEMORY_RELIEF_SFX: AudioStream = preload("res://audios/鍵を開ける1.mp3")
const MEMORY_SCENE_PATH_DEFAULT := "res://scenes/房间差分.tscn"
const MEMORY_TRIGGER_TEXT := "那个曾经逃避离别，害怕面对孤身一人的我。"
const MEMORY_FLASH_COLOR := Color(1.0, 1.0, 1.0, 1.0)

@export_multiline var intro_message: String = ""
@export_file("*.txt") var intro_message_file_path: String = ""
@export_multiline var detail_message: String = ""
@export_file("*.txt") var detail_message_file_path: String = ""
@export var choice_prompt: String = GameText.PHOTO_FRAME_CHOICE_PROMPT
@export var once_flag: String = GameState.FLAG_PHOTO_INVESTIGATED
@export_multiline var repeat_message: String = ""
@export_file("*.txt") var repeat_message_file_path: String = ""
@export var memory_relief_sfx: AudioStream = MEMORY_RELIEF_SFX
@export_range(-40.0, 12.0, 0.5) var memory_relief_sfx_volume_db: float = 0.0
@export_file("*.tscn") var memory_scene_path: String = MEMORY_SCENE_PATH_DEFAULT
@export var memory_trigger_text: String = MEMORY_TRIGGER_TEXT
@export_range(0.0, 3.0, 0.05) var memory_hold_duration: float = 1.
@export_range(0.05, 1.5, 0.05) var memory_fade_duration: float = 0.5
@export var memory_overlay_tint: Color = Color(1.0, 0.93, 0.78, 0.86)
@export var memory_overlay_drift: Vector2 = Vector2(2.0, -2.0)
@export_range(0.1, 2.0, 0.05) var memory_pulse_duration: float = 0.8
@export_range(0.1, 1.0, 0.05) var memory_pulse_alpha: float = 0.72

var _memory_overlay_scene: Node = null


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _uses_repeat_dialog():
		return _load_dialog_lines(repeat_message, repeat_message_file_path)
	return []


func can_interact(interactor: Node) -> bool:
	if not super.can_interact(interactor):
		return false
	if _uses_repeat_dialog():
		return not _load_dialog_lines(repeat_message, repeat_message_file_path).is_empty()
	return not _load_dialog_lines(intro_message, intro_message_file_path).is_empty()


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	if _uses_repeat_dialog():
		return ""
	_run_first_investigation(interactor)
	return ""


func _uses_repeat_dialog() -> bool:
	return not once_flag.is_empty() and GameState != null and GameState.has_flag(once_flag)


func _run_first_investigation(interactor: Node) -> void:
	_first_investigation_flow(interactor)


func _first_investigation_flow(interactor: Node) -> void:
	var player_interactor := _get_player_interactor(interactor)
	var player := interactor as CharacterBody2D
	if player_interactor == null:
		_set_player_controls_locked(player, false)
		return

	_set_player_controls_locked(player, true)

	var intro_lines := _load_dialog_lines(intro_message, intro_message_file_path)
	if not intro_lines.is_empty():
		await player_interactor.play_monologue_lines(intro_lines)

	player_interactor.show_choice(
		choice_prompt,
		[
			{"id": CHOICE_YES, "label": GameText.CHOICE_YES},
			{"id": CHOICE_NO, "label": GameText.CHOICE_NO},
		],
		_on_choice.bind(player_interactor, player),
	)


func _on_choice(choice_id: String, player_interactor: PlayerInteractor, player: CharacterBody2D) -> void:
	match choice_id:
		CHOICE_YES:
			await _play_detail(player_interactor, player)
			_set_player_controls_locked(player, false)
		CHOICE_NO:
			player_interactor.hide_text_immediately()
			_set_player_controls_locked(player, false)


func _play_detail(player_interactor: PlayerInteractor, player: CharacterBody2D) -> void:
	var detail_lines := _load_dialog_lines(detail_message, detail_message_file_path)
	if detail_lines.is_empty():
		player_interactor.hide_text_immediately()
		_mark_investigated()
		return
	var trigger_index := _find_trigger_line_index(detail_lines, memory_trigger_text)
	if trigger_index < 0:
		await player_interactor.play_monologue_lines(detail_lines)
	else:
		var lines_before_trigger := _slice_dialog_lines(detail_lines, 0, trigger_index)
		var lines_after_trigger := _slice_dialog_lines(detail_lines, trigger_index, detail_lines.size())
		if not lines_before_trigger.is_empty():
			await player_interactor.play_monologue_lines(lines_before_trigger)
		await _play_memory_flashback(player)
		if not lines_after_trigger.is_empty():
			await player_interactor.play_monologue_lines(lines_after_trigger)
	_play_memory_relief_sfx()
	_mark_investigated()


func _mark_investigated() -> void:
	if once_flag.is_empty() or GameState == null:
		return
	GameState.set_flag(once_flag)


func _load_dialog_lines(source_message: String, file_path: String) -> Array[DialogLine]:
	if not file_path.is_empty():
		return DialogTextLoader.load_dialog_lines(file_path, _message_as_line_array(source_message))
	return DialogTextLoader.lines_from_strings(_message_as_line_array(source_message))


func _message_as_line_array(source_message: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in source_message.split("\n", false):
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue
		lines.append(stripped)
	return lines


func _get_player_interactor(interactor: Node) -> PlayerInteractor:
	if interactor == null:
		return null
	return interactor.get_node_or_null("Area2D") as PlayerInteractor


func _set_player_controls_locked(player: CharacterBody2D, locked: bool) -> void:
	if player == null:
		return
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)


func _play_memory_relief_sfx() -> void:
	if memory_relief_sfx == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.stream = memory_relief_sfx
	player.volume_db = memory_relief_sfx_volume_db
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _find_trigger_line_index(lines: Array[DialogLine], target_text: String) -> int:
	var trimmed_target := target_text.strip_edges()
	if trimmed_target.is_empty():
		return -1
	for i in range(lines.size()):
		var line := lines[i]
		if line == null:
			continue
		if line.text.strip_edges() == trimmed_target:
			return i
	return -1


func _slice_dialog_lines(lines: Array[DialogLine], from_index: int, to_index: int) -> Array[DialogLine]:
	var result: Array[DialogLine] = []
	var safe_from := clampi(from_index, 0, lines.size())
	var safe_to := clampi(to_index, safe_from, lines.size())
	for i in range(safe_from, safe_to):
		result.append(lines[i])
	return result


func _play_memory_flashback(source_player: CharacterBody2D) -> void:
	if SceneTransition == null:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var player_position := Vector2.ZERO
	var player_facing := ""
	if source_player != null:
		player_position = source_player.global_position
		if source_player.has_method("get_facing_name"):
			player_facing = String(source_player.call("get_facing_name"))

	await SceneTransition.play_action_with_fade_color(
		_show_memory_scene_overlay.bind(current_scene, player_position, player_facing),
		memory_fade_duration,
		MEMORY_FLASH_COLOR,
	)
	await _play_memory_hold_effect()
	await SceneTransition.play_action_with_fade_color(
		_hide_memory_scene_overlay,
		memory_fade_duration,
		MEMORY_FLASH_COLOR,
	)


func _show_memory_scene_overlay(current_scene: Node, player_position: Vector2, player_facing: String) -> void:
	_hide_memory_scene_overlay()
	if current_scene == null:
		return
	if memory_scene_path.is_empty():
		return
	var packed := load(memory_scene_path) as PackedScene
	if packed == null:
		push_warning("PhotoFrameInvestigateItem: 无法加载回忆差分场景 %s" % memory_scene_path)
		return
	var overlay_instance := packed.instantiate()
	if overlay_instance == null:
		return
	current_scene.add_child(overlay_instance)
	current_scene.move_child(overlay_instance, current_scene.get_child_count() - 1)
	_disable_overlay_collisions(overlay_instance)
	_sync_overlay_player(overlay_instance, player_position, player_facing)
	_apply_memory_overlay_style(overlay_instance)
	_memory_overlay_scene = overlay_instance


func _hide_memory_scene_overlay() -> void:
	if _memory_overlay_scene == null:
		return
	if is_instance_valid(_memory_overlay_scene):
		_memory_overlay_scene.queue_free()
	_memory_overlay_scene = null


func _disable_overlay_collisions(overlay_root: Node) -> void:
	for area in overlay_root.find_children("*", "Area2D", true, false):
		var area_node := area as Area2D
		if area_node == null:
			continue
		area_node.monitoring = false
		area_node.monitorable = false
	for shape in overlay_root.find_children("*", "CollisionShape2D", true, false):
		var shape_node := shape as CollisionShape2D
		if shape_node == null:
			continue
		shape_node.disabled = true


func _sync_overlay_player(overlay_root: Node, player_position: Vector2, player_facing: String) -> void:
	for node in overlay_root.find_children("*", "CharacterBody2D", true, false):
		var overlay_player := node as CharacterBody2D
		if overlay_player == null:
			continue
		overlay_player.visible = false
		overlay_player.global_position = player_position
		if not player_facing.is_empty() and overlay_player.has_method("set_facing_direction"):
			overlay_player.call("set_facing_direction", player_facing)
		if overlay_player.has_method("set_controls_locked"):
			overlay_player.call("set_controls_locked", true)
		overlay_player.set_process(false)
		overlay_player.set_physics_process(false)
		overlay_player.set_process_input(false)
		overlay_player.set_process_unhandled_input(false)
		overlay_player.set_process_unhandled_key_input(false)
		var camera := overlay_player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.enabled = false
		break


func _apply_memory_overlay_style(overlay_root: Node) -> void:
	var canvas_item := overlay_root as CanvasItem
	if canvas_item == null:
		return
	canvas_item.modulate = memory_overlay_tint


func _play_memory_hold_effect() -> void:
	if memory_hold_duration <= 0.0:
		return
	var overlay := _memory_overlay_scene
	if overlay == null or not is_instance_valid(overlay):
		await get_tree().create_timer(memory_hold_duration).timeout
		return

	var canvas_item := overlay as CanvasItem
	var node_2d := overlay as Node2D
	var pulse_tween: Tween = null
	var drift_tween: Tween = null
	var base_alpha := 1.0
	var base_position := Vector2.ZERO
	var pulse_target := clampf(memory_pulse_alpha, 0.0, 1.0)
	var half_pulse := maxf(memory_pulse_duration * 0.5, 0.05)

	if canvas_item != null:
		base_alpha = canvas_item.modulate.a
		pulse_tween = create_tween()
		pulse_tween.set_loops()
		pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_method(
			_set_canvas_item_alpha.bind(canvas_item),
			base_alpha,
			pulse_target,
			half_pulse
		)
		pulse_tween.tween_method(
			_set_canvas_item_alpha.bind(canvas_item),
			pulse_target,
			base_alpha,
			half_pulse
		)

	if node_2d != null and memory_overlay_drift != Vector2.ZERO:
		base_position = node_2d.position
		drift_tween = create_tween()
		drift_tween.set_loops()
		drift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift_tween.tween_property(node_2d, "position", base_position + memory_overlay_drift, half_pulse)
		drift_tween.tween_property(node_2d, "position", base_position, half_pulse)

	await get_tree().create_timer(memory_hold_duration).timeout

	if pulse_tween != null:
		pulse_tween.kill()
		if canvas_item != null and is_instance_valid(canvas_item):
			_set_canvas_item_alpha(base_alpha, canvas_item)
	if drift_tween != null:
		drift_tween.kill()
		if node_2d != null and is_instance_valid(node_2d):
			node_2d.position = base_position


func _set_canvas_item_alpha(alpha: float, target: CanvasItem) -> void:
	if target == null or not is_instance_valid(target):
		return
	var color := target.modulate
	color.a = clampf(alpha, 0.0, 1.0)
	target.modulate = color

extends Interactable
class_name InvestigateItem

@export_multiline var message: String = "这里有一些值得调查的内容。"
@export_file("*.txt") var message_file_path: String = ""
@export_group("Once Only")
@export var once_flag: String = ""
@export_multiline var repeat_message: String = ""
@export_file("*.txt") var repeat_message_file_path: String = ""
@export var effects: Array[StatEffect] = []
@export var reward_items: Array[ItemData] = []
@export_group("Player Interaction Pose")
@export var move_player_to_interaction_point: bool = false
@export_node_path("Node2D") var player_interaction_point_path: NodePath
@export var player_position_offset: Vector2 = Vector2.ZERO
@export var player_pose_animation: String = ""
@export_enum("none", "up", "down", "left", "right") var player_pose_facing: String = "none"

var _dialog_lines: Array[DialogLine] = []
var _repeat_dialog_lines: Array[DialogLine] = []


func _ready() -> void:
	_reload_dialog_lines()


func get_interaction_dialog_lines() -> Array[DialogLine]:
	if _uses_repeat_dialog():
		return _repeat_dialog_lines
	return _dialog_lines


func interact(interactor: Node) -> String:
	if not can_interact(interactor):
		return ""
	_apply_player_pose(interactor)
	var is_repeat := _uses_repeat_dialog()
	if not is_repeat and not once_flag.is_empty() and GameState != null:
		GameState.set_flag(once_flag)
	if not is_repeat:
		_apply_effects()
		_apply_rewards()
	return ""


func _uses_repeat_dialog() -> bool:
	if once_flag.is_empty() or GameState == null:
		return false
	return GameState.has_flag(once_flag)


func _reload_dialog_lines() -> void:
	_dialog_lines = _load_dialog_lines(message, message_file_path)
	_mark_reward_obtain_lines(_dialog_lines)
	_repeat_dialog_lines = _load_dialog_lines(repeat_message, repeat_message_file_path)


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


func _apply_effects() -> void:
	if GameState == null or effects.is_empty():
		return
	GameState.apply_effects(effects)


func _apply_rewards() -> void:
	if GameState == null or reward_items.is_empty():
		return
	for item in reward_items:
		if item == null:
			continue
		if not item.id.is_empty() and GameState.find_inventory_index_by_id(item.id) >= 0:
			continue
		GameState.add_inventory_item(item, false)


func _mark_reward_obtain_lines(lines: Array[DialogLine]) -> void:
	if reward_items.is_empty():
		return
	var obtain_messages := _get_reward_obtain_messages()
	for line in lines:
		if line.text in obtain_messages:
			line.play_item_obtained_sfx = true


func _get_reward_obtain_messages() -> PackedStringArray:
	var messages := PackedStringArray()
	for item in reward_items:
		if item == null:
			continue
		messages.append("获得%s。" % item.get_display_name())
	return messages


func _apply_player_pose(interactor: Node) -> void:
	var player := interactor as Node2D
	if player == null:
		return

	var target_position := _resolve_player_interaction_point() + player_position_offset
	var can_transition_to_pose := move_player_to_interaction_point \
		and not player_pose_animation.is_empty() \
		and player.has_method("transition_to_pose")

	if can_transition_to_pose:
		if player_pose_facing != "none" and player.has_method("set_facing_direction"):
			player.call("set_facing_direction", player_pose_facing)
		player.call("transition_to_pose", player_pose_animation, target_position)
		return

	if move_player_to_interaction_point:
		player.global_position = target_position

	if player_pose_facing != "none" and player.has_method("set_facing_direction"):
		player.call("set_facing_direction", player_pose_facing)

	if not player_pose_animation.is_empty() and player.has_method("play_pose_animation"):
		player.call("play_pose_animation", player_pose_animation)


func _resolve_player_interaction_point() -> Vector2:
	if not player_interaction_point_path.is_empty():
		var point_node := get_node_or_null(player_interaction_point_path) as Node2D
		if point_node != null:
			return point_node.global_position
		push_warning("%s: 坐下点节点未找到 %s" % [name, player_interaction_point_path])

	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_position

	return global_position

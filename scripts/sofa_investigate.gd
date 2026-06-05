extends InvestigateItem
class_name SofaInvestigateItem

@export var allow_select_when_facing_mismatch: bool = true
@export var interaction_priority_override: int = 0


func can_interact(interactor: Node) -> bool:
	if interactor == null:
		return false
	if allow_select_when_facing_mismatch:
		# 允许在任意朝向被选中；是否能“坐下”在 interact() 内再判断，
		# 这样朝向不对时也能显示描述文字。
		return true
	return super.can_interact(interactor)


func get_interaction_dialog_lines() -> Array[DialogLine]:
	return []


func get_interaction_priority() -> int:
	return interaction_priority_override


func interact(_interactor: Node) -> String:
	return _get_blocked_direction_text()


func try_toggle_sit(interactor: Node) -> bool:
	if _try_stand_up_if_sitting(interactor):
		return true
	if not super.can_interact(interactor):
		return false
	_store_pre_sit_position(interactor)
	super.interact(interactor)
	return true


func _try_stand_up_if_sitting(interactor: Node) -> bool:
	var player := interactor as Node2D
	if player == null:
		return false
	if player_pose_animation.is_empty():
		return false
	if not player.has_method("get_pose_animation_name") or not player.has_method("clear_pose_animation"):
		return false

	var current_pose := String(player.call("get_pose_animation_name"))
	if current_pose != player_pose_animation:
		return false

	var key := _position_meta_key()
	if not player.has_meta(key):
		# 兼容旧状态：没有记录位置时，仍允许起身，避免卡住。
		player.call("clear_pose_animation")
		return true

	player.call("clear_pose_animation")
	_restore_pre_sit_position(player)
	return true


func _store_pre_sit_position(interactor: Node) -> void:
	var player := interactor as Node2D
	if player == null:
		return
	player.set_meta(_position_meta_key(), player.global_position)
	if player.has_method("set_pose_restore_position"):
		player.call("set_pose_restore_position", player.global_position)


func _restore_pre_sit_position(player: Node2D) -> void:
	var key := _position_meta_key()
	if not player.has_meta(key):
		return
	var saved_position = player.get_meta(key)
	if saved_position is Vector2:
		player.global_position = saved_position
	player.remove_meta(key)


func _position_meta_key() -> StringName:
	return StringName("_sofa_pre_sit_pos_%s" % str(get_instance_id()))


func _get_blocked_direction_text() -> String:
	if not message.is_empty():
		if LanguageSwitch != null:
			return LanguageSwitch.localize_text(message)
		return message
	if LanguageSwitch != null:
		return LanguageSwitch.translate_text("common.sofa.default")
	return TranslationServer.translate("common.sofa.default")

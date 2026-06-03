extends SofaInvestigateItem
class_name BedInvestigateItem

@export var pose_when_facing_left: String = "sitright"
@export var pose_when_facing_up: String = "sit"
@export var default_pose: String = "sitright"
@export_node_path("Node2D") var sit_point_for_left_path: NodePath = NodePath("SitPoint")
@export_node_path("Node2D") var sit_point_for_up_path: NodePath = NodePath("SitPointUp")


func try_toggle_sit(interactor: Node) -> bool:
	var facing_name := _resolve_facing_name(interactor)
	if not _can_sit_with_facing(facing_name):
		return false
	player_pose_animation = _resolve_pose_by_facing_name(facing_name)
	player_interaction_point_path = _resolve_sit_point_path_by_facing_name(facing_name)
	return super.try_toggle_sit(interactor)


func _resolve_facing_name(interactor: Node) -> String:
	if interactor == null or not interactor.has_method("get_facing_name"):
		return ""
	return String(interactor.call("get_facing_name"))


func _resolve_pose_by_facing_name(facing_name: String) -> String:
	match facing_name:
		"left":
			return pose_when_facing_left
		"up":
			return pose_when_facing_up
		_:
			return default_pose


func _resolve_sit_point_path_by_facing_name(facing_name: String) -> NodePath:
	match facing_name:
		"up":
			return sit_point_for_up_path
		_:
			return sit_point_for_left_path


func _can_sit_with_facing(facing_name: String) -> bool:
	return facing_name == "up" or facing_name == "left"

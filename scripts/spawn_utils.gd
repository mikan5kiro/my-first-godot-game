extends RefCounted
class_name SpawnUtils

## 场景内 Marker2D 查找与定位工具。


static func find_marker(scene_root: Node, marker_name: String) -> Marker2D:
	if scene_root == null or marker_name.is_empty():
		return null

	var marker := scene_root.get_node_or_null(marker_name) as Marker2D
	if marker == null:
		marker = scene_root.find_child(marker_name, true, false) as Marker2D
	return marker


static func snap_node_to_marker(node: Node2D, scene_root: Node, marker_name: String) -> bool:
	if node == null or marker_name.is_empty():
		return false

	var marker := find_marker(scene_root, marker_name)
	if marker == null:
		return false

	node.global_position = marker.global_position
	if node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO
	return true

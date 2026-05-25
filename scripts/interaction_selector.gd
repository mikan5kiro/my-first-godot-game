extends RefCounted
class_name InteractionSelector

## 从重叠 Area2D 中选出最合适的 Interactable 目标。


static func find_best(
	detector: Area2D,
	overlapping_areas: Array[Area2D],
	interactor: Node2D,
) -> Interactable:
	var best_target: Interactable = null
	var best_priority: int = -1
	var best_overlap_area: float = -1.0
	var best_distance: float = INF

	for area in overlapping_areas:
		if area is not Interactable:
			continue
		var target := area as Interactable
		if not target.can_interact(interactor):
			continue

		var overlap_area: float = _get_overlap_area_with(detector, area)
		var distance: float = interactor.global_position.distance_to(area.global_position)
		var priority: int = target.get_interaction_priority()

		if priority > best_priority:
			best_priority = priority
			best_overlap_area = overlap_area
			best_distance = distance
			best_target = target
		elif priority == best_priority:
			if overlap_area > best_overlap_area:
				best_overlap_area = overlap_area
				best_distance = distance
				best_target = target
			elif absf(overlap_area - best_overlap_area) <= 0.001 and distance < best_distance:
				best_distance = distance
				best_target = target

	return best_target


static func _get_overlap_area_with(detector: Area2D, other_area: Area2D) -> float:
	var self_rect: Rect2 = _get_area_aabb_world(detector)
	var other_rect: Rect2 = _get_area_aabb_world(other_area)
	var overlap_rect: Rect2 = self_rect.intersection(other_rect)
	if overlap_rect.size.x <= 0.0 or overlap_rect.size.y <= 0.0:
		return 0.0
	return overlap_rect.size.x * overlap_rect.size.y


static func _get_area_aabb_world(area: Area2D) -> Rect2:
	var has_rect: bool = false
	var min_x: float = 0.0
	var min_y: float = 0.0
	var max_x: float = 0.0
	var max_y: float = 0.0

	for child in area.get_children():
		if child is not CollisionShape2D:
			continue
		var collision := child as CollisionShape2D
		if collision.disabled or collision.shape == null:
			continue
		var shape_rect: Rect2 = collision.shape.get_rect()
		var shape_transform: Transform2D = area.global_transform * collision.transform
		var corners := [
			shape_transform * shape_rect.position,
			shape_transform * Vector2(shape_rect.end.x, shape_rect.position.y),
			shape_transform * shape_rect.end,
			shape_transform * Vector2(shape_rect.position.x, shape_rect.end.y),
		]

		for point in corners:
			if not has_rect:
				min_x = point.x
				max_x = point.x
				min_y = point.y
				max_y = point.y
				has_rect = true
			else:
				min_x = minf(min_x, point.x)
				max_x = maxf(max_x, point.x)
				min_y = minf(min_y, point.y)
				max_y = maxf(max_y, point.y)

	if not has_rect:
		return Rect2(area.global_position, Vector2.ZERO)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

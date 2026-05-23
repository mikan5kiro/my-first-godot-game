extends Node2D

@export var padding: int = 0


func _ready() -> void:
	call_deferred("apply_camera_limits")


func apply_camera_limits() -> void:
	var camera := _get_player_camera()
	if camera == null:
		return

	var bounds := _get_tilemap_world_bounds()
	if not bounds.has_area():
		return

	camera.limit_left = int(bounds.position.x + padding)
	camera.limit_top = int(bounds.position.y + padding)
	camera.limit_right = int(bounds.end.x - padding)
	camera.limit_bottom = int(bounds.end.y - padding)
	camera.enabled = true
	camera.position_smoothing_enabled = false


func _get_player_camera() -> Camera2D:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _get_tilemap_world_bounds() -> Rect2:
	var bounds := Rect2()
	var found := false

	for node in find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		var layer_bounds := _layer_world_rect(layer)
		if not layer_bounds.has_area():
			continue
		if not found:
			bounds = layer_bounds
			found = true
		else:
			bounds = bounds.merge(layer_bounds)

	return bounds


func _layer_world_rect(layer: TileMapLayer) -> Rect2:
	var cells := layer.get_used_cells()
	if cells.is_empty():
		return Rect2()

	var tile_size := Vector2(layer.tile_set.tile_size)
	var bounds := Rect2()

	for cell in cells:
		var top_left := layer.to_global(Vector2(cell) * tile_size)
		var bottom_right := layer.to_global(Vector2(cell + Vector2i.ONE) * tile_size)
		var cell_rect := Rect2(top_left, bottom_right - top_left).abs()
		if not bounds.has_area():
			bounds = cell_rect
		else:
			bounds = bounds.merge(cell_rect)

	return bounds

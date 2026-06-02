class_name EndingDepartureEffect
extends RefCounted

const PULL_DURATION := 2
const HOLD_DURATION := 1
const RETURN_DURATION := 1.7
const FACE_BEFORE_CAMERA_HOLD_DURATION := 0.4


static func run(player: CharacterBody2D) -> void:
	if player == null:
		return

	var scene_root := player.get_parent()
	if scene_root != null and scene_root.has_method("apply_camera_limits"):
		scene_root.call("apply_camera_limits")

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	player.set_facing_direction("down")
	await player.get_tree().process_frame
	if FACE_BEFORE_CAMERA_HOLD_DURATION > 0.0:
		await player.get_tree().create_timer(FACE_BEFORE_CAMERA_HOLD_DURATION).timeout

	if camera == null:
		await player.get_tree().create_timer(PULL_DURATION + HOLD_DURATION + RETURN_DURATION).timeout
		player.set_facing_direction("up")
		return

	var original_offset := camera.offset
	var target_offset := _compute_pan_to_bottom_offset(player, camera)

	var tween_out := player.create_tween()
	tween_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(camera, "offset", target_offset, PULL_DURATION)
	await tween_out.finished

	if HOLD_DURATION > 0.0:
		await player.get_tree().create_timer(HOLD_DURATION).timeout

	var tween_in := player.create_tween()
	tween_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_in.tween_property(camera, "offset", original_offset, RETURN_DURATION)
	await tween_in.finished

	player.set_facing_direction("up")


static func _compute_pan_to_bottom_offset(player: CharacterBody2D, camera: Camera2D) -> Vector2:
	var viewport_size := player.get_viewport().get_visible_rect().size
	var half_height := viewport_size.y / (2.0 * camera.zoom.y)
	var bottom := float(camera.limit_bottom)

	if bottom <= float(camera.limit_top):
		return Vector2(camera.offset.x, camera.offset.y + 120.0)

	var target_center_y := bottom - half_height
	var offset_y := target_center_y - player.global_position.y
	return Vector2(camera.offset.x, offset_y)

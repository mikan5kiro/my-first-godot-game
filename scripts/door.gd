extends Interactable
class_name InteractableDoor

@export_file("*.tscn") var target_scene: String = "res://scenes/客厅.tscn"
@export var spawn_marker_name: String = "Spawn_FromWorkshop"
@export var transition_delay_after_sfx: float = 0.12

var _is_activating: bool = false


func get_interaction_priority() -> int:
	return 1


func can_interact(interactor: Node) -> bool:
	if _is_activating:
		return false
	return super.can_interact(interactor)


func interact(interactor: Node) -> String:
	if _is_activating:
		return ""
	_is_activating = true

	var facing_name := ""
	if interactor != null and interactor.has_method("get_facing_name"):
		facing_name = String(interactor.call("get_facing_name"))

	SceneTransition.play_door_sfx()
	if transition_delay_after_sfx > 0.0:
		var timer := get_tree().create_timer(transition_delay_after_sfx)
		timer.timeout.connect(_on_transition_delay_finished.bind(facing_name), CONNECT_ONE_SHOT)
	else:
		SceneTransition.transition_to(target_scene, spawn_marker_name, facing_name)
	return ""


func _on_transition_delay_finished(facing_name: String) -> void:
	SceneTransition.transition_to(target_scene, spawn_marker_name, facing_name)

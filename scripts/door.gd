extends Node2D

@export var target_scene: String = "res://scenes/客厅.tscn"
@export var spawn_marker_name: String = "Spawn_FromWorkshop"
@export_enum("up", "down", "left", "right") var required_direction: String = "up"
@export var transition_delay_after_sfx: float = 0.12

@onready var area: Area2D = $Area2D

var _player: CharacterBody2D = null


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _player == null or not Input.is_action_just_pressed("interact"):
		return
	if _player.last_direction != required_direction:
		return
	SceneTransition.play_door_sfx()
	if transition_delay_after_sfx > 0.0:
		await get_tree().create_timer(transition_delay_after_sfx).timeout
	SceneTransition.transition_to(target_scene, spawn_marker_name, _player.last_direction)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player = body as CharacterBody2D


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body is CharacterBody2D

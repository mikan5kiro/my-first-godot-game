extends CharacterBody2D

@export var move_speed: float = 100.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # 使用 AnimatedSprite2D

var last_direction: String = "down"

func set_facing_direction(direction: String) -> void:
	last_direction = direction
	if animated_sprite != null:
		animated_sprite.play(direction)

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir * move_speed
	
	update_animation(input_dir)
	
	move_and_slide()

func update_animation(input_dir: Vector2) -> void:
	if animated_sprite == null:
		return
	
	if input_dir == Vector2.ZERO:
		# 静止 - 播放最后方向的静止动画
		animated_sprite.play(last_direction)
		return
	
	# 走动 - 根据输入方向播放走动动画
	if input_dir.x > 0:
		animated_sprite.play("rightwalk")
		last_direction = "right"
	elif input_dir.x < 0:
		animated_sprite.play("leftwalk")
		last_direction = "left"
	elif input_dir.y < 0:
		animated_sprite.play("upwalk")
		last_direction = "up"
	elif input_dir.y > 0:
		animated_sprite.play("downwalk")
		last_direction = "down"

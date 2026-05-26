extends CharacterBody2D

@export var move_speed: float = 100.0
@export var play_entry_cutscene: bool = false
@export var entry_cutscene: CutsceneData
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # 使用 AnimatedSprite2D
@onready var interact_area: PlayerInteractor = $Area2D
@onready var cutscene_controller: CutsceneController = $CutsceneController

var facing: Facing.Dir = Facing.Dir.DOWN
var _external_controls_locked: bool = false

func _ready() -> void:
	if not play_entry_cutscene:
		return
	if cutscene_controller == null:
		push_warning("Player: 找不到 CutsceneController，无法播放入场过场")
		return

	var cutscene := _resolve_entry_cutscene()
	if not cutscene_controller.is_pending(cutscene):
		return

	set_controls_locked(true)
	_prepare_awake_pose()
	cutscene_controller.prepare(cutscene)
	cutscene_controller.play(cutscene)


func _resolve_entry_cutscene() -> CutsceneData:
	if entry_cutscene != null:
		return entry_cutscene
	return CutscenePresets.bedroom_intro()


func _prepare_awake_pose() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation("awake"):
		return
	animated_sprite.sprite_frames.set_animation_loop("awake", false)
	animated_sprite.frame = 0
	animated_sprite.play("awake")

func set_facing_direction(direction: String) -> void:
	facing = Facing.from_name(direction)
	if animated_sprite != null:
		animated_sprite.play(Facing.to_idle_anim(facing))

func get_facing() -> Facing.Dir:
	return facing

func get_facing_name() -> String:
	return Facing.to_name(facing)

func _physics_process(delta: float) -> void:
	if _is_controls_locked():
		velocity = Vector2.ZERO
		if not _external_controls_locked:
			update_animation(Vector2.ZERO)
		# 开场锁定时不要 move_and_slide，否则碰撞会把玩家从床上挤开。
		if not _external_controls_locked:
			move_and_slide()
		return
	
	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir * move_speed
	
	update_animation(input_dir)
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _external_controls_locked:
		if interact_area.is_text_visible():
			interact_area.try_interact(self)
		get_viewport().set_input_as_handled()
		return
	interact_area.try_interact(self)

func update_animation(input_dir: Vector2) -> void:
	if animated_sprite == null:
		return
	
	if input_dir == Vector2.ZERO:
		# 静止 - 播放最后方向的静止动画
		animated_sprite.play(Facing.to_idle_anim(facing))
		return
	
	# 走动 - 根据输入方向播放走动动画
	if input_dir.x > 0:
		facing = Facing.Dir.RIGHT
	elif input_dir.x < 0:
		facing = Facing.Dir.LEFT
	elif input_dir.y < 0:
		facing = Facing.Dir.UP
	elif input_dir.y > 0:
		facing = Facing.Dir.DOWN
	
	animated_sprite.play(Facing.to_walk_anim(facing))

func is_controls_locked() -> bool:
	return _is_controls_locked()


func _is_controls_locked() -> bool:
	if _external_controls_locked:
		return true
	return interact_area.is_text_visible()

func set_controls_locked(locked: bool) -> void:
	_external_controls_locked = locked

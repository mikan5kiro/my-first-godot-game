extends CharacterBody2D

@export var move_speed: float = 100.0
@export var play_entry_cutscene: bool = false
@export var entry_cutscene: CutsceneData
@export_range(0.05, 0.6, 0.01) var pose_transition_duration: float = 0.18
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # 使用 AnimatedSprite2D
@onready var interact_area: PlayerInteractor = $Area2D
@onready var cutscene_controller: CutsceneController = $CutsceneController

var facing: Facing.Dir = Facing.Dir.DOWN
var _external_controls_locked: bool = false
var _pose_animation: String = ""
var _pose_restore_position: Vector2 = Vector2.ZERO
var _has_pose_restore_position: bool = false
var _pose_transitioning: bool = false
var _pose_transition_prev_lock: bool = false

func _ready() -> void:
	if not play_entry_cutscene:
		return
	# 从其他场景进门时会带重生点，不应再播起床开场。
	if SceneTransition != null and SceneTransition.has_pending_spawn():
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

func _physics_process(_delta: float) -> void:
	if _is_controls_locked():
		velocity = Vector2.ZERO
		if not _external_controls_locked:
			update_animation(Vector2.ZERO)
		# 开场锁定时不要 move_and_slide，否则碰撞会把玩家从床上挤开。
		if not _external_controls_locked:
			move_and_slide()
		return
	
	var input_dir = Input.get_vector("left", "right", "up", "down")

	# 坐姿下按方向键：走起身回位流程，避免在沙发/椅子碰撞里硬挤导致卡住。
	if not _pose_animation.is_empty() and input_dir != Vector2.ZERO:
		var facing_override := _facing_name_from_input(input_dir)
		if try_restore_from_pose(facing_override):
			return
		# 兜底：没有回位点时也先起身，再允许移动。
		clear_pose_animation(facing_override)

	velocity = input_dir * move_speed
	
	update_animation(input_dir)

	# 姿态动画静止时不要执行 move_and_slide，避免贴边时抖动。
	if not _pose_animation.is_empty() and input_dir == Vector2.ZERO:
		return
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if interact_area.is_text_visible():
		if interact_area.try_cancel(event):
			get_viewport().set_input_as_handled()
			return
		if interact_area.is_choice_active() and interact_area.try_handle_choice_input(event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("sit_toggle"):
		if event.is_echo():
			return
		if _handle_sit_toggle():
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	if _external_controls_locked:
		if interact_area.is_text_visible():
			interact_area.try_interact(self, event)
		get_viewport().set_input_as_handled()
		return
	interact_area.try_interact(self, event)

func update_animation(input_dir: Vector2) -> void:
	if animated_sprite == null:
		return

	if not _pose_animation.is_empty():
		if input_dir == Vector2.ZERO:
			if animated_sprite.animation != _pose_animation:
				animated_sprite.play(_pose_animation)
			return
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
	if locked:
		velocity = Vector2.ZERO
		snap_to_idle()


func snap_to_idle() -> void:
	update_animation(Vector2.ZERO)


func play_pose_animation(animation_name: String) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if animation_name.is_empty():
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Player: 未找到姿态动画 %s" % animation_name)
		return
	_pose_animation = animation_name
	velocity = Vector2.ZERO
	animated_sprite.play(animation_name)


func get_pose_animation_name() -> String:
	return _pose_animation


func clear_pose_animation(facing_override_name: String = "") -> void:
	if _pose_animation.is_empty():
		return
	if facing_override_name.is_empty():
		_sync_facing_with_pose(_pose_animation)
	else:
		facing = Facing.from_name(facing_override_name)
	_pose_animation = ""
	velocity = Vector2.ZERO
	snap_to_idle()


func set_pose_restore_position(target_position: Vector2) -> void:
	_pose_restore_position = target_position
	_has_pose_restore_position = true


func try_restore_from_pose(facing_override_name: String = "") -> bool:
	if _pose_animation.is_empty() or _pose_transitioning:
		return false
	if not _has_pose_restore_position:
		return false
	_play_stand_transition(_pose_restore_position, facing_override_name)
	_has_pose_restore_position = false
	return true


func transition_to_pose(animation_name: String, target_position: Vector2) -> void:
	if _pose_transitioning:
		return
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		global_position = target_position
		play_pose_animation(animation_name)
		return
	if animation_name.is_empty() or not animated_sprite.sprite_frames.has_animation(animation_name):
		global_position = target_position
		return

	_begin_pose_transition()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, pose_transition_duration)
	tween.tween_callback(func() -> void:
		play_pose_animation(animation_name)
		_end_pose_transition()
	)


func _play_stand_transition(target_position: Vector2, facing_override_name: String = "") -> void:
	_begin_pose_transition()
	clear_pose_animation(facing_override_name)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, pose_transition_duration)
	tween.tween_callback(func() -> void:
		_end_pose_transition()
	)


func _begin_pose_transition() -> void:
	_pose_transition_prev_lock = _external_controls_locked
	_pose_transitioning = true
	_external_controls_locked = true
	velocity = Vector2.ZERO


func _end_pose_transition() -> void:
	_pose_transitioning = false
	_external_controls_locked = _pose_transition_prev_lock


func _sync_facing_with_pose(pose_animation: String) -> void:
	match pose_animation:
		"sitright":
			facing = Facing.Dir.RIGHT
		"sitback":
			facing = Facing.Dir.UP
		"sit":
			facing = Facing.Dir.DOWN


func _facing_name_from_input(input_dir: Vector2) -> String:
	if input_dir.x > 0:
		return "right"
	if input_dir.x < 0:
		return "left"
	if input_dir.y < 0:
		return "up"
	return "down"


func _handle_sit_toggle() -> bool:
	if try_restore_from_pose():
		return true
	if _external_controls_locked or interact_area == null or interact_area.is_text_visible():
		return false

	var overlapping_areas := interact_area.get_overlapping_areas()
	var candidates: Array[Area2D] = []
	for area in overlapping_areas:
		if area == null or not area.has_method("try_toggle_sit"):
			continue
		candidates.append(area)
	if candidates.is_empty():
		return false

	candidates.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		var pa := _get_interaction_priority(a)
		var pb := _get_interaction_priority(b)
		if pa != pb:
			return pa > pb
		var da := global_position.distance_to(a.global_position)
		var db := global_position.distance_to(b.global_position)
		return da < db
	)

	for candidate in candidates:
		if bool(candidate.call("try_toggle_sit", self)):
			return true
	return false


func _get_interaction_priority(target: Area2D) -> int:
	if target == null or not target.has_method("get_interaction_priority"):
		return 0
	return int(target.call("get_interaction_priority"))

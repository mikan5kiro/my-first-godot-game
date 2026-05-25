extends Area2D

# 玩家交互检测器：
# - 挂在玩家的 Area2D 上（这个 Area2D 就是“交互检测范围”）
# - 按下 interact 时由 player.gd 调用 try_interact(player)
# - 从重叠的可交互 Area2D 中选一个“最合适的目标”，并在底部显示文本
# - 内置：二段式按键（打字中按一次补全/全文按一次关闭）+ 打字机效果

@export var typewriter_chars_per_sec: float = 36.0
@export var type_sfx_enabled: bool = true
@export var type_sfx_bus: StringName = &"Master"
@export_range(0.0, 1.0, 0.01) var type_sfx_char_chance: float = 0.75

# 交互文本 UI（运行时动态创建）。
var _interaction_panel: PanelContainer
var _interaction_label: Label

# 状态：对话框显示/打字机状态（player.gd 会用 is_text_visible() 来锁移动）。
var _is_text_visible: bool = false
var _is_typing: bool = false
var _full_text: String = ""
var _typed_char_count: int = 0
var _type_timer: Timer
var _type_sfx_player: AudioStreamPlayer
var _type_sfx_playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _monologue_lines: PackedStringArray = PackedStringArray()
var _monologue_index: int = -1
var _monologue_active: bool = false
var _monologue_advance_requested: bool = false

func _ready() -> void:
	# 构建底部对话框与打字机 Timer。
	_rng.randomize()
	_create_interaction_ui()
	_setup_type_sfx()

func try_interact(interactor: Node2D) -> void:
	# 对话框已打开时：二段式按键逻辑
	# 1) 打字中：补全全文
	# 2) 已全文：关闭对话框（独白模式下改为切下一句）
	if _is_text_visible:
		if _is_typing:
			_finish_typing_immediately()
		elif _monologue_active:
			_monologue_advance_requested = true
		else:
			hide_text_immediately()
		return
	
	# 读取当前与玩家交互检测范围重叠的 Area2D（这些通常是物品/NPC 的交互区域）。
	var overlapping_areas: Array[Area2D] = get_overlapping_areas()

	# 选择目标策略：
	# - 必须实现 interact(interactor) 方法
	# - 如果实现 can_interact(interactor)，则必须返回 true（例如朝向限制）
	# - 候选中按“碰撞 AABB 交集面积”排序，交集越大越优先
	# - 交集面积相近时，用距离作为兜底
	var best_area: Area2D = null
	var best_overlap_area: float = -1.0
	var best_distance: float = INF
	
	for area in overlapping_areas:
		if not area.has_method("interact"):
			continue
		if not _can_interact_area(area, interactor):
			continue
		
		var overlap_area: float = _get_overlap_area_with(area)
		var distance: float = interactor.global_position.distance_to(area.global_position)
		
		if overlap_area > best_overlap_area:
			best_overlap_area = overlap_area
			best_distance = distance
			best_area = area
		elif absf(overlap_area - best_overlap_area) <= 0.001 and distance < best_distance:
			best_distance = distance
			best_area = area
	
	if best_area == null:
		return
	
	# 调用目标物体的 interact(interactor)，期望返回 String 文本；空字符串表示“不触发显示”。
	var result: Variant = best_area.call("interact", interactor)
	if result is String and not (result as String).is_empty():
		_show_interaction_text(result as String)

func is_text_visible() -> bool:
	return _is_text_visible

func play_monologue_lines(lines: PackedStringArray) -> void:
	# 剧情独白：首句自动显示；全文后按交互键切下一句（不关框），最后一句再关。
	if lines.is_empty():
		return
	_monologue_lines = lines
	_monologue_index = 0
	_monologue_active = true
	_monologue_advance_requested = false
	_show_interaction_text(lines[0])
	while _monologue_active:
		if _monologue_advance_requested:
			_monologue_advance_requested = false
			_advance_monologue_line()
		await get_tree().process_frame

func hide_text_immediately() -> void:
	_end_monologue()
	_hide_interaction_text()

func _advance_monologue_line() -> void:
	if _monologue_index < _monologue_lines.size() - 1:
		_monologue_index += 1
		_show_interaction_text(_monologue_lines[_monologue_index])
	else:
		_end_monologue()
		_hide_interaction_text()

func _end_monologue() -> void:
	_monologue_active = false
	_monologue_advance_requested = false
	_monologue_lines = PackedStringArray()
	_monologue_index = -1

func _can_interact_area(area: Area2D, interactor: Node2D) -> bool:
	# 允许物体提供 can_interact(interactor) 进行额外条件过滤（如 required_facing）。
	if area.has_method("can_interact"):
		return bool(area.call("can_interact", interactor))
	return true

func _get_overlap_area_with(other_area: Area2D) -> float:
	# 计算“交互检测范围”和“物体交互范围”的 AABB 交集面积。
	# 这是近似值（不是精确形状交集），但对矩形/圆形碰撞在 RPG 交互里通常足够稳定。
	var self_rect: Rect2 = _get_area_aabb_world(self)
	var other_rect: Rect2 = _get_area_aabb_world(other_area)
	var overlap_rect: Rect2 = self_rect.intersection(other_rect)
	if overlap_rect.size.x <= 0.0 or overlap_rect.size.y <= 0.0:
		return 0.0
	return overlap_rect.size.x * overlap_rect.size.y

func _get_area_aabb_world(area: Area2D) -> Rect2:
	# 把一个 Area2D 下的所有 CollisionShape2D 合并成一个世界坐标 AABB。
	# 用于“交集面积优先”的目标选择。
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

func _create_interaction_ui() -> void:
	# 运行时创建一个简单的底部对话框（CanvasLayer + PanelContainer + Label）。
	# 如果你之后想美术化对话框，建议改成单独的 UI 场景（.tscn）实例化。
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 100
	ui_layer.name = "InteractionUI"
	add_child(ui_layer)
	
	_interaction_panel = PanelContainer.new()
	_interaction_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_interaction_panel.offset_left = 20.0
	_interaction_panel.offset_top = -96.0
	_interaction_panel.offset_right = -20.0
	_interaction_panel.offset_bottom = -20.0
	_interaction_panel.visible = false
	ui_layer.add_child(_interaction_panel)
	
	_interaction_label = Label.new()
	_interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_interaction_panel.add_child(_interaction_label)
	
	_type_timer = Timer.new()
	_type_timer.one_shot = false
	_type_timer.timeout.connect(_on_typewriter_tick)
	add_child(_type_timer)
	
func _show_interaction_text(text: String) -> void:
	if _interaction_panel == null or _interaction_label == null:
		return
	
	# 打字机初始化：清空 label，从 0 字开始逐步显示。
	_full_text = text
	_typed_char_count = 0
	_is_typing = true
	
	_interaction_label.text = ""
	_interaction_panel.show()
	_is_text_visible = true
	
	var cps: float = maxf(typewriter_chars_per_sec, 1.0)
	_type_timer.wait_time = 1.0 / cps
	_type_timer.start()

func _on_typewriter_tick() -> void:
	# 每次 tick 多显示一个字符；到末尾后自动补全并停止。
	if not _is_typing:
		return
	
	_typed_char_count += 1
	var current_char := _full_text.substr(_typed_char_count - 1, 1)
	_interaction_label.text = _full_text.substr(0, _typed_char_count)
	_play_type_sfx_for_char(current_char)
	if _typed_char_count >= _full_text.length():
		_finish_typing_immediately()

func _finish_typing_immediately() -> void:
	# 立即显示全文（用于“打字中再按一次交互键”或自动结束）。
	_type_timer.stop()
	_is_typing = false
	_interaction_label.text = _full_text

func _hide_interaction_text() -> void:
	# 关闭对话框并清理状态。
	if _type_timer != null:
		_type_timer.stop()
	if _interaction_panel != null:
		_interaction_panel.hide()
	_is_typing = false
	_full_text = ""
	_typed_char_count = 0
	_is_text_visible = false


func _setup_type_sfx() -> void:
	if not type_sfx_enabled:
		return
	_type_sfx_player = AudioStreamPlayer.new()
	_type_sfx_player.bus = type_sfx_bus
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.08
	_type_sfx_player.stream = generator
	add_child(_type_sfx_player)
	_type_sfx_player.play()
	_type_sfx_playback = _type_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _play_type_sfx_for_char(ch: String) -> void:
	if not type_sfx_enabled:
		return
	if _type_sfx_playback == null:
		return
	if ch.is_empty() or ch.strip_edges().is_empty():
		return
	var is_punctuation := "，。！？；：,.!?;:…".contains(ch)
	if not is_punctuation and _rng.randf() > type_sfx_char_chance:
		return

	var mix_rate := 44100.0
	if _type_sfx_player != null and _type_sfx_player.stream is AudioStreamGenerator:
		mix_rate = (_type_sfx_player.stream as AudioStreamGenerator).mix_rate

	var first_duration := _rng.randf_range(0.004, 0.007)
	var first_freq := _rng.randf_range(700.0, 1100.0)
	var first_gain := _rng.randf_range(0.11, 0.18)
	if is_punctuation:
		first_freq = _rng.randf_range(520.0, 820.0)
		first_gain = _rng.randf_range(0.09, 0.14)
	_play_click_pulse(mix_rate, first_duration, first_freq, first_gain, 0.92)

	if is_punctuation:
		return

	var second_duration := _rng.randf_range(0.003, 0.006)
	var second_freq := _rng.randf_range(900.0, 1450.0)
	var second_gain := _rng.randf_range(0.05, 0.1)
	_play_click_pulse(mix_rate, second_duration, second_freq, second_gain, 0.86)


func _play_click_pulse(mix_rate: float, duration: float, freq: float, gain: float, noise_weight: float) -> void:
	var frame_count := int(mix_rate * duration)
	if frame_count <= 0:
		return
	var available_frames := _type_sfx_playback.get_frames_available()
	if available_frames <= 0:
		return
	frame_count = mini(frame_count, available_frames)
	if frame_count <= 0:
		return

	for i in frame_count:
		var t := float(i) / mix_rate
		var progress := float(i) / float(frame_count)
		var env := exp(-7.0 * progress)
		var noise := (_rng.randf() * 2.0 - 1.0) * noise_weight
		var tone := sin(TAU * freq * t) * (1.0 - noise_weight)
		var s := (noise + tone) * gain * env
		_type_sfx_playback.push_frame(Vector2(s, s))

extends RefCounted
class_name BorderBreathAnimator

## 循环播放 StyleBoxFlat 边框颜色的呼吸高亮。

var _tween: Tween
var _style: StyleBoxFlat


func start(host: Node, template: StyleBoxFlat, half_cycle: float) -> StyleBoxFlat:
	stop()
	_style = template.duplicate()
	_style.border_color = RpgUiStyle.BREATH_BORDER_MIN

	_tween = host.create_tween().set_loops()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_style, "border_color", RpgUiStyle.BREATH_BORDER_MAX, half_cycle)
	_tween.tween_property(_style, "border_color", RpgUiStyle.BREATH_BORDER_MIN, half_cycle)
	return _style


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_style = null


func get_style() -> StyleBoxFlat:
	return _style

extends RefCounted
class_name IntroDialogue

const _INTRO_AWAKE_LINE_KEYS: PackedStringArray = [
	"intro.awake.01",
	"intro.awake.02",
]

const _INTRO_CONTROLS_LINE_KEYS: PackedStringArray = [
	"intro.controls.01",
]


static var INTRO_AWAKE_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_INTRO_AWAKE_LINE_KEYS)


static var INTRO_CONTROLS_LINES: PackedStringArray:
	get:
		return _lines_from_keys(_INTRO_CONTROLS_LINE_KEYS)


static func _lines_from_keys(keys: PackedStringArray) -> PackedStringArray:
	var lines := PackedStringArray()
	for key in keys:
		lines.append(TranslationServer.translate(key))
	return lines

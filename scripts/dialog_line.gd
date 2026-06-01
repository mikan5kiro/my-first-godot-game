extends RefCounted
class_name DialogLine

enum Type {
	NARRATION,
	CHARACTER,
}

var dialog_type: Type = Type.NARRATION
var text: String = ""
var play_item_obtained_sfx: bool = false


static func narration(line_text: String) -> DialogLine:
	var line := DialogLine.new()
	line.dialog_type = Type.NARRATION
	line.text = line_text
	return line


static func character(line_text: String) -> DialogLine:
	var line := DialogLine.new()
	line.dialog_type = Type.CHARACTER
	line.text = line_text
	return line

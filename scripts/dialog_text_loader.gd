extends RefCounted
class_name DialogTextLoader

const CHARACTER_LINE_PREFIX := "@"
const PAUSE_COMMAND := "pause"
const DEFAULT_PAUSE_SECONDS := 1.0
const PAUSE_SENTINEL_PREFIX := "__pause__:"


static func parse_line(raw: String) -> DialogLine:
	var line := raw.strip_edges()
	var pause_seconds := _parse_pause_seconds(line)
	if pause_seconds >= 0.0:
		return DialogLine.narration("%s%s" % [PAUSE_SENTINEL_PREFIX, str(pause_seconds)])
	if line.begins_with(CHARACTER_LINE_PREFIX):
		return DialogLine.character(line.substr(CHARACTER_LINE_PREFIX.length()).strip_edges())
	return DialogLine.narration(line)


static func lines_from_strings(lines: Array) -> Array[DialogLine]:
	return lines_from_strings_packed(PackedStringArray(lines))


static func lines_from_strings_packed(lines: PackedStringArray) -> Array[DialogLine]:
	var result: Array[DialogLine] = []
	for raw in lines:
		var stripped: String = raw.strip_edges()
		if stripped.is_empty():
			continue
		if stripped.begins_with("#"):
			continue
		result.append(parse_line(stripped))
	return result


static func _parse_pause_seconds(line: String) -> float:
	if not line.begins_with("[") or not line.ends_with("]"):
		return -1.0

	var command_text := line.substr(1, line.length() - 2).strip_edges()
	if command_text.is_empty():
		return -1.0

	var parts := command_text.split(" ", false)
	if parts.is_empty():
		return -1.0
	if parts[0].to_lower() != PAUSE_COMMAND:
		return -1.0
	if parts.size() < 2:
		return DEFAULT_PAUSE_SECONDS
	return maxf(parts[1].to_float(), 0.0)

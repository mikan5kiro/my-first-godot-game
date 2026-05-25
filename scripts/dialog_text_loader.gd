extends RefCounted
class_name DialogTextLoader


static func load_lines(file_path: String, fallback: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	if file_path.is_empty():
		return fallback

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("DialogTextLoader: 无法读取文本文件 '%s'" % file_path)
		return fallback

	var lines := PackedStringArray()
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			continue
		lines.append(line)

	if lines.is_empty():
		return fallback
	return lines


static func load_text(file_path: String, fallback: String = "") -> String:
	var lines := load_lines(file_path)
	if lines.is_empty():
		return fallback
	return "\n".join(lines)

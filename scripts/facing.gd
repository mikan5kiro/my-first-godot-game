extends RefCounted
class_name Facing

enum Dir {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

const IDLE_ANIM := {
	Dir.UP: "up",
	Dir.DOWN: "down",
	Dir.LEFT: "left",
	Dir.RIGHT: "right",
}

const WALK_ANIM := {
	Dir.UP: "upwalk",
	Dir.DOWN: "downwalk",
	Dir.LEFT: "leftwalk",
	Dir.RIGHT: "rightwalk",
}

static func to_idle_anim(direction: Dir) -> String:
	return IDLE_ANIM.get(direction, "down")


static func to_walk_anim(direction: Dir) -> String:
	return WALK_ANIM.get(direction, "downwalk")


static func to_name(direction: Dir) -> String:
	return to_idle_anim(direction)


static func from_name(direction_name: String) -> Dir:
	match direction_name:
		"up":
			return Dir.UP
		"down":
			return Dir.DOWN
		"left":
			return Dir.LEFT
		"right":
			return Dir.RIGHT
		_:
			return Dir.DOWN

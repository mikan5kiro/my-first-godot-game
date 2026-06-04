extends Resource
class_name CutsceneStep

enum StepType {
	HOLD_MARKER,
	RELEASE_HOLD,
	SNAP_MARKER,
	SET_FACING,
	PLAY_ANIM,
	MONOLOGUE,
	FADE,
	WAIT,
	PLAY_SFX,
	PLAY_IDLE,
}

@export var type: StepType = StepType.WAIT
@export var marker_name: String = ""
@export_enum("up", "down", "left", "right") var facing: String = "down"
@export var anim_name: String = ""
@export var dialog_lines: PackedStringArray = PackedStringArray()
@export_range(0.0, 1.0, 0.01) var fade_alpha: float = 1.0
@export var duration: float = 0.6
@export var sfx: AudioStream
@export var wait_if_no_sfx: float = 0.0

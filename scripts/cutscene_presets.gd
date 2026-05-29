extends RefCounted
class_name CutscenePresets

const BEDROOM_INTRO_TEXT := "res://dialogues/intro_awake.txt"
const INTRO_CONTROLS_TEXT := "res://dialogues/intro_controls.txt"
const BEDROOM_STAND_UP_SFX := preload("res://audios/衣擦れ.mp3")


static func bedroom_intro() -> CutsceneData:
	var data := CutsceneData.new()
	data.completion_flag = GameState.FLAG_BEDROOM_INTRO
	data.prepare_marker = "Spawn_OnBed"
	data.steps = [
		_make_step(CutsceneStep.StepType.HOLD_MARKER, {"marker_name": "Spawn_OnBed"}),
		_make_step(CutsceneStep.StepType.PLAY_ANIM, {"anim_name": "awake"}),
		_make_step(
			CutsceneStep.StepType.MONOLOGUE,
			{
				"text_file": BEDROOM_INTRO_TEXT,
				"fallback_lines": PackedStringArray(
					["@又是这个梦……", "@今天，得去把那件事做个了断。"]
				),
			}
		),
		_make_step(CutsceneStep.StepType.FADE, {"fade_alpha": 1.0, "duration": 0.6}),
		_make_step(
			CutsceneStep.StepType.PLAY_SFX,
			{"sfx": BEDROOM_STAND_UP_SFX, "wait_if_no_sfx": 0.4}
		),
		_make_step(CutsceneStep.StepType.RELEASE_HOLD),
		_make_step(CutsceneStep.StepType.SNAP_MARKER, {"marker_name": "Spawn_BesideBed"}),
		_make_step(CutsceneStep.StepType.SET_FACING, {"facing": "down"}),
		_make_step(CutsceneStep.StepType.FADE, {"fade_alpha": 0.0, "duration": 0.6}),
		_make_step(CutsceneStep.StepType.PLAY_IDLE),
		_make_step(
			CutsceneStep.StepType.MONOLOGUE,
			{
				"text_file": INTRO_CONTROLS_TEXT,
				"fallback_lines": PackedStringArray(
					["WASD 移动，E 调查，ESC 菜单/取消。"]
				),
			}
		),
	]
	return data


static func _make_step(step_type: CutsceneStep.StepType, fields: Dictionary = {}) -> CutsceneStep:
	var step := CutsceneStep.new()
	step.type = step_type
	for key in fields:
		step.set(key, fields[key])
	return step

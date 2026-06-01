class_name EndingSequence
extends RefCounted

const TITLE_SCENE_PATH := "res://scenes/title_screen.tscn"


static func run(door_sfx: AudioStream = null) -> void:
	if not is_instance_valid(SceneTransition):
		return
	await SceneTransition.play_ending(door_sfx, GameText.ENDING_DISPLAY_TEXT, TITLE_SCENE_PATH)

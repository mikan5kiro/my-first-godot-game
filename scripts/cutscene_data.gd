extends Resource
class_name CutsceneData

## 一段过场的步骤列表；播完后可写入 completion_flag。

@export var completion_flag: String = ""
@export var prepare_marker: String = ""
@export var steps: Array[CutsceneStep] = []

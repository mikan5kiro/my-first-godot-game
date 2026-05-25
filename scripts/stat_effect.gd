extends Resource
class_name StatEffect

## 互动事件对 GameState 的修改项；可在编辑器里配在调查物、NPC 等节点上。

@export var hunger_delta: int = 0
@export var sanity_delta: int = 0
@export var money_delta: int = 0
@export var advance_time: bool = false
@export var set_flags: PackedStringArray = PackedStringArray()
@export var clear_flags: PackedStringArray = PackedStringArray()

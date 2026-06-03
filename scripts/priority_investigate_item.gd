extends InvestigateItem
class_name PriorityInvestigateItem

@export var interaction_priority_override: int = 0


func get_interaction_priority() -> int:
	return interaction_priority_override

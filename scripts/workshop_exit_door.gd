extends InteractableDoor


func interact(interactor: Node) -> String:
	if GameState != null and GameState.should_trigger_workshop_hunger_on_exit():
		GameState.set_flag(GameState.FLAG_WORKSHOP_HUNGER_PENDING)
	return super.interact(interactor)

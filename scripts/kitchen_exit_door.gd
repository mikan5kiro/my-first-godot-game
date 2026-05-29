extends InteractableDoor


func interact(interactor: Node) -> String:
	if GameState != null and GameState.should_trigger_kitchen_afternoon_on_exit():
		GameState.set_flag(GameState.FLAG_KITCHEN_AFTERNOON_PENDING)
	return super.interact(interactor)

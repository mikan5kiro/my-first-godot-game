class_name FridgeUse
extends RefCounted


static func is_fridge_available(player_interactor: PlayerInteractor, interactor: Node2D) -> bool:
	if player_interactor == null:
		return false
	for area in player_interactor.get_overlapping_areas():
		if area is FridgeInteractable:
			var fridge := area as FridgeInteractable
			if fridge.can_interact(interactor):
				return true
	return false


static func run_store(player_interactor: PlayerInteractor, item: ItemData) -> void:
	if player_interactor == null or item == null or GameState == null:
		return
	if not GameState.store_inventory_item_in_fridge(item):
		return
	player_interactor.show_text("把%s放进了冰箱。" % item.get_display_name())

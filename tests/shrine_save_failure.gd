extends Main
## A SCRIPT FILE cannot be a directory. Exercises the real writer's failure
## branch without ever targeting the player's save or relying on permissions.
func save_game(_path: String = SAVE_PATH) -> bool:
	return super.save_game("res://tests/shrine_test.gd/cannot_write.json")

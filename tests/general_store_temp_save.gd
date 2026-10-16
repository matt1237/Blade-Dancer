class_name GeneralStoreTempSave extends Main
## Exercises Main's actual transaction and atomic writer without a player save.
var temporary_file: FileAccess
var temporary_path: String = ""

func save_game(_path: String = SAVE_PATH) -> bool:
	if temporary_path.is_empty():
		temporary_file = FileAccess.create_temp(FileAccess.WRITE, "kaji_purchase_test", "json")
		temporary_path = temporary_file.get_path_absolute()
		temporary_file.close()
	return super.save_game(temporary_path)

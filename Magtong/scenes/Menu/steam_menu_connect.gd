extends VBoxContainer




func _on_create_lobby_btn_pressed():
	globSteamHandler.create_debug_lobby()

func _on_list_btn_pressed():
	globSteamHandler.get_lobby_list()


func _on_join_btn_pressed():
	pass


func _on_list_members_pressed():
	globSteamHandler.print_lobby_members()


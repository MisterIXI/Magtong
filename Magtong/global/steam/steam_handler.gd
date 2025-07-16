class_name SteamHandler
extends Node


func _ready():
	initilize_steam()
	create_debug_lobby()
	pass


func _process(delta):
	pass


func initilize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx(3044580)
	if initialize_response["status"] == 0:
		print("Steam initialized successfully!")
		print("App Owner: ", Steam.getAppOwner())
		print("Owns game: ", Steam.isSubscribed())
		print("Friend Count: ", Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE))
	else:
		print("Did Steam initialize?: %s " % initialize_response)
	

func inv_sazzles() -> void:
	var count: int = Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)
	var friends: Dictionary = Dictionary()
	for i in range(count):
		pass


func create_debug_lobby() -> void:
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	print("Lobby list request sent!")

func _on_lobby_match_list(these_lobbies: Array) -> void:
	print("Lobbies: ", these_lobbies)
class_name SteamHandler
extends Node

var lobby_id: int = 0
var lobbies: Array = []

func _ready():
	initilize_steam()
	connect_steam_lobby_funcs()


func _process(delta):
	Steam.run_callbacks()


func connect_steam_lobby_funcs() -> void:
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_data_update.connect(_on_lobby_data_update)
	Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_message.connect(_on_lobby_message)
	Steam.persona_state_change.connect(_on_persona_state_change)

func initilize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx(3044580)
	if initialize_response["status"] == 0:
		print("Steam initialized successfully!")
		print("App Owner: ", Steam.getAppOwner())
		print("Owns game: ", Steam.isSubscribed())
		print("Friend Count: ", Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE))
	else:
		print("Did Steam initialize?: %s " % initialize_response)
	
func get_lobby_list() -> void:
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	print("Lobby list request sent!")

func create_debug_lobby() -> void:
	print("Creating debug lobby...")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)

func print_lobby_members() -> void:
	Steam.sendLobbyChatMsg(lobbies[0], "Hello from the lobby!")

func join_first_lobby() -> void:
	if lobbies.is_empty():
		print("No lobbies available to join.")
		return
	Steam.joinLobby(lobbies[0])

func _on_join_requested(lobby_id: int, steam_id: int) -> void:
	print("Join requested for lobby ID: ", lobby_id, " by Steam ID: ", steam_id)

func _on_lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int) -> void:
	print("Lobby chat updated for lobby ID: ", lobby_id, " with changed ID: ", changed_id, " by making change ID: ", making_change_id, " with chat state: ", chat_state)

func _on_lobby_created(connect: int, lobby_id: int) -> void:
	if connect == 1:
		print("Lobby created successfully with ID: ", lobby_id)
	else:
		print("Failed to create lobby, error code: ", connect)

func _on_lobby_data_update(success: int, lobby_id: int, member_id: int) -> void:
	if success == 1:
		print("Lobby data updated successfully for lobby ID: ", lobby_id, " by member ID: ", member_id)
	else:
		print("Failed to update lobby data for lobby ID: ", lobby_id)
		print("Error code: ", success)

func _on_lobby_invite(inviter: int, lobby: int, game: int) -> void:
	print("Lobby invite received from Steam ID: ", inviter, " for lobby ID: ", lobby, " with game ID: ", game)

func _on_lobby_joined(lobby: int, permissions: int, locked: bool, response: int) -> void:
	if response == 1:
		print("Successfully joined lobby ID: ", lobby)
		lobby_id = lobby
	else:
		print("Failed to join lobby ID: ", lobby, " with response code: ", response)

func _on_lobby_match_list(lobbies: Array) -> void:
	print("Lobby match list received with ", lobbies.size(), " lobbies.")
	print("Lobbies: ", lobbies)

func _on_lobby_message(lobby_id: int, user: int, message: String, chat_type: int) -> void:
	print("Lobby message received in lobby ID: ", lobby_id, " from user ID: ", user, " with message: ", message, " of type: ", chat_type)

func _on_persona_state_change(steam_id: int, flags: int) -> void:
	print("Persona state changed for Steam ID: ", steam_id, " with flags: ", flags)
class_name SteamHandler
extends Node

const MAGTONG_STEAMID = 3044580
const MAGTONG_PLAYTEST_STEAMID = 4273979

var lobby_id: int = 0
var peer: SteamMultiplayerPeer
var is_host: bool = false
var lobbies: Array = []
var curr_lobby_members: Array[Dictionary] = []

var steam_id: int = -1
var steam_name: String = ""

func _ready():
	initilize_steam()
	connect_steam_lobby_funcs()
	

func _process(delta):
	Steam.run_callbacks()


func initilize_steam() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# var initialize_response: Dictionary = Steam.steamInitEx(MAGTONG_STEAMID)
	var initialize_response: Dictionary = Steam.steamInitEx(MAGTONG_STEAMID)
	if initialize_response["status"] == 0:
		print("Steam initialized successfully!")
		print("App Owner: ", Steam.getAppOwner())
		print("Owns game: ", Steam.isSubscribed())
		print("Friend Count: ", Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE))
		steam_id = Steam.getSteamID()
		steam_name = Steam.getPersonaName()
		Steam.initRelayNetworkAccess()
	else:
		print("Did Steam initialize?: %s " % initialize_response)
	
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
	Steam.p2p_session_request.connect(_on_p2p_session_request)

func get_lobby_list() -> void:
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	print("Lobby list request sent!")

func create_debug_lobby() -> void:
	var set_relay: bool = Steam.allowP2PPacketRelay(false)
	print("Allowing Steam to be relay backup: %s" % set_relay)
	print("Creating debug lobby...")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)

func send_lobby_chat() -> void:
	if lobby_id == 0:
		print("No lobbies available to send chat message.")
		return
	Steam.sendLobbyChatMsg(lobby_id, "Hello from the lobby!")

func join_first_lobby() -> void:
	get_lobby_list()
	await get_tree().create_timer(0.5).timeout
	if lobby_id == 0:
		print("No lobbies available to join.")
		return
	Steam.joinLobby(lobby_id)

func _on_join_requested(lobby_id: int, steam_id: int) -> void:
	print("Join requested for lobby ID: ", lobby_id, " by: ",Steam.getFriendPersonaName(steam_id), " (", steam_id, ")")
	Steam.joinLobby(lobby_id)

func _on_lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int) -> void:
	print("Lobby chat updated for lobby ID: ", lobby_id, " with changed ID: ", changed_id, " by making change ID: ", making_change_id, " with chat state: ", chat_state)

func _on_lobby_created(connect_code: int, lobby_id: int) -> void:
	if connect_code == 1:

		print("Lobby created successfully with ID: ", lobby_id)
		var peer : MultiplayerPeer = SteamMultiplayerPeer.new()
		peer.server_relay = false
		peer.host_with_lobby(lobby_id)
		multiplayer.multiplayer_peer = peer
		is_host = true
		globGameManager._change_state(globGameManager.State.LOBBY)
		globGameManager._on_peer_connected(1)
		peer.peer_connected.connect(globGameManager._on_peer_connected)
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

func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == 1:
		print("Successfully joined lobby ID: ", lobby)
		lobby_id = lobby
		_get_lobby_members()
		var is_lobby_owner = Steam.getLobbyOwner(lobby_id)
		var own_id = Steam.getSteamID()
		if is_lobby_owner != own_id:
			var peer : MultiplayerPeer = SteamMultiplayerPeer.new()
			peer.server_relay = false
			var retval = peer.create_client(lobby_id, 0)
			print("Return value of create_client: ", retval)
			multiplayer.multiplayer_peer = peer
			globGameManager._change_state(globGameManager.State.LOBBY)
			globGameManager._on_peer_connected(own_id)
	else:
		print("Failed to join lobby ID: ", lobby, " with response code: ", response)

func _get_lobby_members() -> void:
	curr_lobby_members.clear()
	var member_count: int = Steam.getNumLobbyMembers(lobby_id)
	for member_id in range(0, member_count):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, member_id)
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		curr_lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name})


func _on_lobby_match_list(lobbies: Array) -> void:
	print("Lobby match list received with ", lobbies.size(), " lobbies.")
	print("Lobbies (count: ", lobbies.size(), "): ", lobbies)
	lobby_id = lobbies[0] if lobbies.size() > 0 else 0

func _on_lobby_message(lobby_id: int, user: int, message: String, chat_type: int) -> void:
	print("Lobby message received in lobby ID: ", lobby_id, " from user ID: ", user, " with message: ", message, " of type: ", chat_type)

func _on_persona_state_change(steam_id: int, flags: int) -> void:
	print("Persona state changed for Steam ID: ", steam_id, " with flags: ", flags)


func _on_p2p_session_request(remote_id: int) -> void:
	print("Accepted p2p session with ")
	Steam.acceptP2PSessionWithUser(remote_id)

func get_steam_name(steam_id: int) -> String:
	return Steam.getFriendPersonaName(steam_id) + "(" + str(steam_id) + ")"

func make_p2p_handshake():
	pass
	
	pass
class_name SteamHandler
extends Node

const MAGTONG_STEAMID = 3044580
const MAGTONG_PLAYTEST_STEAMID = 4273979
const MAX_LOBBY_MEMBERS = 4

var steam_id: int = -1
var steam_name: String = ""
var is_initialized: bool = false
var lobby_id: int = 0

func _ready():
	initilize_steam()
	if is_initialized:
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.join_requested.connect(_on_join_requested)
		_check_command_line()

func _process(_delta):
	Steam.run_callbacks()


func initilize_steam() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var initialize_response: Dictionary = Steam.steamInitEx(MAGTONG_STEAMID)
	if initialize_response["status"] == 0:
		print("Steam initialized successfully!")
		print("App Owner: ", Steam.getAppOwner())
		print("Owns game: ", Steam.isSubscribed())
		steam_id = Steam.getSteamID()
		steam_name = Steam.getPersonaName()
		is_initialized = true
	else:
		print("Did Steam initialize?: %s " % initialize_response)

func get_steam_name(steam_id: int) -> String:
	return Steam.getFriendPersonaName(steam_id) + "(" + str(steam_id) + ")"

## Creates a friends only lobby. Once it exists we host on it and open the invite dialog.
func create_lobby() -> void:
	if not is_initialized:
		push_warning("Steam is not initialized")
		return
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_LOBBY_MEMBERS)

func join_lobby(new_lobby_id: int) -> void:
	if not is_initialized:
		push_warning("Steam is not initialized")
		return
	Steam.joinLobby(new_lobby_id)

func open_invite_dialog() -> void:
	if lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)

func leave_lobby() -> void:
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0

func _on_lobby_created(connect_result: int, new_lobby_id: int) -> void:
	if connect_result != Steam.RESULT_OK:
		globGameManager.return_to_menu("Could not create the Steam lobby (%d)" % connect_result)
		return
	lobby_id = new_lobby_id
	Steam.setLobbyJoinable(lobby_id, true)
	var peer := SteamMultiplayerPeer.new()
	var err: int = peer.host_with_lobby(lobby_id)
	if err != OK:
		globGameManager.return_to_menu("Could not host on the Steam lobby (%d)" % err)
		return
	globNet.start_with_peer(peer, true)
	globGameManager.enter_online_lobby()
	open_invite_dialog()

## A friend invited us (or we used "Join game" in the friends list).
func _on_join_requested(new_lobby_id: int, _friend_id: int) -> void:
	join_lobby(new_lobby_id)

func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		globGameManager.return_to_menu("Could not join the Steam lobby (%d)" % response)
		return
	lobby_id = new_lobby_id
	if Steam.getLobbyOwner(lobby_id) == steam_id:
		return # we created it, _on_lobby_created handles the host side
	var peer := SteamMultiplayerPeer.new()
	var err: int = peer.connect_to_lobby(lobby_id)
	if err != OK:
		globGameManager.return_to_menu("Could not connect to the Steam lobby (%d)" % err)
		return
	globNet.start_with_peer(peer, false)
	globGameManager.wait_for_host()

## Steam starts the game with +connect_lobby <id> when it is launched from an invite.
func _check_command_line() -> void:
	var args := OS.get_cmdline_args()
	var index := args.find("+connect_lobby")
	if index != -1 and index + 1 < args.size():
		join_lobby.call_deferred(args[index + 1].to_int())

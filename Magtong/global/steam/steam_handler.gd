extends Node

const MAGTONG_STEAMID = 3044580
const MAGTONG_PLAYTEST_STEAMID = 4273979
const MAX_LOBBY_MEMBERS = 4
## lobby data: the Steam id of the machine that hosts the game on this lobby. Steam hands the lobby to
## another member when the owner leaves, but that member doesn't host, so joining it would wait forever.
const LOBBY_HOST_KEY = "host"

var steam_id: int = -1
var steam_name: String = ""
var is_initialized: bool = false
var lobby_id: int = 0
var _host_id: int = 0 # Steam id of the host of our lobby, 0 = none

func _ready():
	initilize_steam()
	if is_initialized:
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.join_requested.connect(_on_join_requested)
		Steam.lobby_chat_update.connect(_on_lobby_chat_update)
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
		GameManager.print_message("Steam: left lobby %d" % lobby_id)
		lobby_id = 0
	_host_id = 0

func _on_lobby_created(connect_result: int, new_lobby_id: int) -> void:
	if connect_result != Steam.RESULT_OK:
		GameManager.return_to_menu("Could not create the Steam lobby (%d)" % connect_result)
		return
	lobby_id = new_lobby_id
	_host_id = steam_id
	Steam.setLobbyData(lobby_id, LOBBY_HOST_KEY, str(steam_id))
	Steam.setLobbyJoinable(lobby_id, true)
	var peer := SteamMultiplayerPeer.new()
	var err: int = peer.host_with_lobby(lobby_id)
	if err != OK:
		GameManager.return_to_menu("Could not host on the Steam lobby (%d)" % err)
		return
	NetGame.start_with_peer(peer, true)
	GameManager.enter_online_lobby()
	open_invite_dialog()

## A friend invited us (or we used "Join game" in the friends list).
func _on_join_requested(new_lobby_id: int, _friend_id: int) -> void:
	join_lobby(new_lobby_id)

func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		GameManager.return_to_menu("Could not join the Steam lobby (%d)" % response)
		return
	lobby_id = new_lobby_id
	var owner := Steam.getLobbyOwner(lobby_id)
	if owner == steam_id:
		return # we created it, _on_lobby_created handles the host side
	var host := Steam.getLobbyData(lobby_id, LOBBY_HOST_KEY).to_int()
	GameManager.print_message("Steam: joined lobby %d, owner %d, host %d" % [lobby_id, owner, host])
	if host == 0 or owner != host:
		# the host left and Steam made someone else the owner: nobody hosts this lobby anymore
		GameManager.return_to_menu("This game has already ended")
		return
	_host_id = host
	var peer := SteamMultiplayerPeer.new()
	var err: int = peer.connect_to_lobby(lobby_id)
	if err != OK:
		GameManager.return_to_menu("Could not connect to the Steam lobby (%d)" % err)
		return
	NetGame.start_with_peer(peer, false)
	GameManager.wait_for_host()

## The host left the Steam lobby: leave too, even if the netcode didn't notice yet. Also keeps us from staying
## in a lobby that nobody hosts (others could join it and wait forever).
func _on_lobby_chat_update(changed_lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	if changed_lobby_id != lobby_id or changed_id != _host_id or _host_id == steam_id:
		return
	var gone := Steam.CHAT_MEMBER_STATE_CHANGE_LEFT | Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED \
		| Steam.CHAT_MEMBER_STATE_CHANGE_KICKED | Steam.CHAT_MEMBER_STATE_CHANGE_BANNED
	if chat_state & gone:
		GameManager.print_message("Steam: the host left lobby %d" % lobby_id)
		# deferred: closing the Steam peer from inside a Steam callback is asking for trouble
		GameManager.return_to_menu.call_deferred("The host left")

## Steam starts the game with +connect_lobby <id> when it is launched from an invite.
func _check_command_line() -> void:
	var args := OS.get_cmdline_args()
	var index := args.find("+connect_lobby")
	if index != -1 and index + 1 < args.size():
		join_lobby.call_deferred(args[index + 1].to_int())

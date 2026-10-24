class_name SteamHandler
extends Node

const MAGTONG_STEAMID = 3044580
const MAGTONG_PLAYTEST_STEAMID = 4273979

var steam_id: int = -1
var steam_name: String = ""

func _ready():
	initilize_steam()

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
	else:
		print("Did Steam initialize?: %s " % initialize_response)

func get_steam_name(steam_id: int) -> String:
	return Steam.getFriendPersonaName(steam_id) + "(" + str(steam_id) + ")"

# TODO: online multiplayer is not supported, these are skeletons for a possible later reimplementation
func create_lobby() -> void:
	push_warning("Online multiplayer is not supported")

func join_lobby(_lobby_id: int) -> void:
	push_warning("Online multiplayer is not supported")

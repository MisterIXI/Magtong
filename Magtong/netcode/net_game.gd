extends Node
class_name NetGame
## Online play (autoload globNet). Owns the transport, the roster (which machine controls which player)
## and the lobby epochs, and routes packets to the rollback sessions. The host is the authority for the
## roster: joins, leaves and the lobby state everybody starts from. Offline the same bookkeeping happens
## locally, so the lobby has one code path for local and online play.

enum Mode { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT: int = 24680
const MAX_CLIENTS: int = 3
const OFFLINE_PEER: int = 1
const TIMEOUT_MS: int = 5000
const KEEPALIVE_MS: int = 250

## client connected to the host, enter the lobby
signal connected_to_host()
## the online session is over (connection lost, host left, could not connect)
signal connection_ended(reason: String)
## everybody rebuilds the lobby from this roster and state
signal lobby_reset(epoch: int, roster: Array, state_bytes: PackedByteArray)
## authority only: a machine wants to add a local player
signal player_join_requested(peer: int, device: int)
## authority only: a client entered its lobby and needs the current lobby state
signal peer_hello(peer: int)
## authority only: a machine left or timed out
signal peer_left(peer: int)
## the host ended the match, everybody goes back to the lobby
signal return_to_lobby_requested()

var mode: Mode = Mode.OFFLINE
var transport: NetTransport
## [{"peer": int, "device": int, "skin": int}], the order is the player order of the simulation
var roster: Array = []
var epoch: int = 0
## ticks of input delay online (NetDebug.input_delay, --input-delay=n)
var input_delay: int:
	get:
		return NetDebug.input_delay
## set when a match starts: {"session": String, "seed": int, "players": [{"peer", "device", "team", "skin"}]}
var match_setup: Dictionary = {}

var _sessions: Dictionary = {} # session id -> Callable(packet: Dictionary, now_ms: int)
var _last_heard: Dictionary = {} # peer id -> msec
var _last_keepalive: int = 0
var _was_connected: bool = false
var _outgoing: Array = [] # [send_at_ms, to, bytes, reliable], only used with NetDebug.net_lag_ms

func _ready():
	# poll before the maps step their sessions, so arrived inputs are used in the same tick
	process_physics_priority = -100

func is_online() -> bool:
	return mode != Mode.OFFLINE

## The host (or the local game) decides about the roster.
func is_authority() -> bool:
	return mode != Mode.CLIENT

func get_local_peer() -> int:
	return transport.get_unique_id() if transport != null else OFFLINE_PEER

func get_input_delay() -> int:
	return input_delay if is_online() else 0

func get_connected_peers() -> Array:
	return _last_heard.keys()

#region connect
func host_direct(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	start_with_peer(peer, true)
	return OK

func join_direct(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	start_with_peer(peer, false)
	return OK

## Also used by the Steam lobbies with a SteamMultiplayerPeer.
func start_with_peer(peer: MultiplayerPeer, as_host: bool) -> void:
	leave()
	transport = NetTransport.new(peer)
	transport.peer_connected.connect(_on_peer_connected)
	transport.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.HOST if as_host else Mode.CLIENT
	_was_connected = as_host

func leave() -> void:
	if transport != null:
		_send(0, {"type": "bye"}, true)
		transport.peer.poll() # flush the bye
		transport.close()
	transport = null
	_outgoing.clear()
	mode = Mode.OFFLINE
	roster = []
	epoch = 0
	match_setup = {}
	_sessions = {}
	_last_heard = {}

func _end(reason: String) -> void:
	leave()
	connection_ended.emit(reason)
#endregion

#region polling
func _physics_process(_delta):
	if transport == null:
		return
	var now := Time.get_ticks_msec()
	for packet in transport.poll():
		var msg = bytes_to_var(packet[1])
		if typeof(msg) == TYPE_DICTIONARY and msg.has("type"):
			_handle(packet[0], msg, now)
		if transport == null:
			return # the message ended the session
	_flush_outgoing(now)
	if mode == Mode.CLIENT and not _was_connected and not transport.is_connecting() and not transport.is_connected_to_host():
		_end("Could not connect to the host")
		return
	if now - _last_keepalive > KEEPALIVE_MS:
		_last_keepalive = now
		_send(0, {"type": "keepalive"}, false)
	for peer_id in _last_heard.keys():
		if now - _last_heard[peer_id] > TIMEOUT_MS:
			_on_peer_disconnected(peer_id)

func _handle(from: int, msg: Dictionary, now: int) -> void:
	_last_heard[from] = now
	match msg["type"]:
		"session":
			if mode == Mode.HOST:
				# clients only talk to the host, so the host passes the inputs on to the other clients
				for peer_id in _last_heard:
					if peer_id != from:
						_send(peer_id, msg, false)
			var handler: Callable = _sessions.get(msg["id"], Callable())
			if handler.is_valid():
				handler.call(msg["data"], now)
		"hello":
			if mode == Mode.HOST:
				peer_hello.emit(from)
		"add_player":
			if mode == Mode.HOST:
				player_join_requested.emit(from, msg["device"])
		"lobby_reset":
			if mode == Mode.CLIENT:
				epoch = msg["epoch"]
				roster = msg["roster"]
				lobby_reset.emit(epoch, roster, msg["state"])
		"return_to_lobby":
			if mode == Mode.CLIENT:
				return_to_lobby_requested.emit()
		"bye":
			_on_peer_disconnected(from)

func _on_peer_connected(peer_id: int) -> void:
	_last_heard[peer_id] = Time.get_ticks_msec()
	if mode == Mode.CLIENT and peer_id == NetTransport.HOST_ID:
		_was_connected = true
		connected_to_host.emit()

func _on_peer_disconnected(peer_id: int) -> void:
	if not _last_heard.has(peer_id):
		return
	_last_heard.erase(peer_id)
	if mode == Mode.CLIENT:
		if peer_id == NetTransport.HOST_ID:
			_end("Lost the connection to the host")
	else:
		peer_left.emit(peer_id)

func _send(to: int, msg: Dictionary, reliable: bool) -> void:
	if transport == null:
		return
	if not reliable and NetDebug.net_loss > 0.0 and randf() < NetDebug.net_loss:
		return
	if NetDebug.net_lag_ms > 0:
		_outgoing.append([Time.get_ticks_msec() + NetDebug.net_lag_ms, to, var_to_bytes(msg), reliable])
	else:
		transport.send(to, var_to_bytes(msg), reliable)

func _flush_outgoing(now: int) -> void:
	while not _outgoing.is_empty() and _outgoing[0][0] <= now:
		var entry: Array = _outgoing.pop_front()
		transport.send(entry[1], entry[2], entry[3])
#endregion

#region lobby
## Client: the lobby scene is ready, ask the host for the current lobby.
func send_hello() -> void:
	_send(NetTransport.HOST_ID, {"type": "hello"}, true)

## A local device wants to play. The authority decides and answers with a lobby reset.
func request_add_player(device: int) -> void:
	if is_authority():
		player_join_requested.emit(get_local_peer(), device)
	else:
		_send(NetTransport.HOST_ID, {"type": "add_player", "device": device}, true)

## Authority: everybody (including us) rebuilds the lobby from this roster and state.
func reset_lobby(new_roster: Array, state_bytes: PackedByteArray) -> void:
	epoch += 1
	roster = new_roster
	if mode == Mode.HOST:
		_send(0, {"type": "lobby_reset", "epoch": epoch, "roster": roster, "state": state_bytes}, true)
	lobby_reset.emit(epoch, roster, state_bytes)

## Host: end the match for everybody and go back to the lobby.
func request_return_to_lobby() -> void:
	if mode == Mode.HOST:
		_send(0, {"type": "return_to_lobby"}, true)
	return_to_lobby_requested.emit()
#endregion

#region sessions
func register_session(id: String, handler: Callable) -> void:
	_sessions[id] = handler

func unregister_session(id: String) -> void:
	_sessions.erase(id)

func send_session_packet(id: String, packet: Dictionary) -> void:
	_send(0, {"type": "session", "id": id, "data": packet}, false)
#endregion

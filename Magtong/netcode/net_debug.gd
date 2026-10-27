class_name NetDebug
## Settings of the local rollback test mode. When enabled, a match runs as two "machines" in one
## process: team 1 is this machine, team 2 a fake remote peer, connected through a FakeNetwork.
## Set with the debug keys of NetDebugOverlay or command line user args, e.g.
## godot --path . -- --rollback-test --fake-ping=120 --fake-jitter=20 --fake-loss=0.05 --input-delay=2
## For real online sessions --net-lag=60 --net-loss=0.05 add lag and loss to everything this machine sends
## (two local game processes with --net-lag=60 each play like a 120 ms connection).
## All of this only works in debug builds, release exports ignore the keys and arguments.

const PING_STEPS: Array[int] = [0, 50, 100, 150, 250]
const LOSS_STEPS: Array[float] = [0.0, 0.05, 0.2]
const MAX_INPUT_DELAY: int = 4

static var enabled: bool = false
static var ping_ms: int = 100
static var jitter_ms: int = 10
static var loss: float = 0.0
static var input_delay: int = 2
static var show_overlay: bool = false
## real online sessions: delay every outgoing packet / drop outgoing unreliable packets (testing only)
static var net_lag_ms: int = 0
static var net_loss: float = 0.0

## Debug keys, test command line arguments and the direct connect menu entries.
static func dev_tools_enabled() -> bool:
	return OS.is_debug_build()

static func parse_args() -> void:
	if not dev_tools_enabled():
		return
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		match parts[0]:
			"--rollback-test":
				enabled = true
				show_overlay = true
			"--fake-ping":
				ping_ms = parts[1].to_int()
			"--fake-jitter":
				jitter_ms = parts[1].to_int()
			"--fake-loss":
				loss = parts[1].to_float()
			"--input-delay":
				input_delay = clampi(parts[1].to_int(), 0, MAX_INPUT_DELAY)
			"--net-lag":
				net_lag_ms = parts[1].to_int()
			"--net-loss":
				net_loss = parts[1].to_float()

static func apply_network(network: FakeNetwork) -> void:
	network.ping_ms = ping_ms
	network.jitter_ms = jitter_ms
	network.loss = loss

static func next_ping() -> void:
	ping_ms = PING_STEPS[(PING_STEPS.find(ping_ms) + 1) % PING_STEPS.size()]

static func next_loss() -> void:
	loss = LOSS_STEPS[(LOSS_STEPS.find(loss) + 1) % LOSS_STEPS.size()]

static func next_input_delay() -> void:
	input_delay = (input_delay + 1) % (MAX_INPUT_DELAY + 1)

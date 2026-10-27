extends CanvasLayer
class_name NetDebugOverlay
## Rollback stats and the debug keys of the rollback test mode (see NetDebug).
## F4 overlay, F5 test mode on/off (next match), F6 ping, F7 loss, F8 input delay (next match),
## F9 force a desync on the fake remote peer.

var map: MapScript
var _label: Label
var _rollback_window: Array[int] = [] # rollback count per frame of the last second

func _init(map: MapScript) -> void:
	self.map = map
	layer = 100
	_label = Label.new()
	_label.position = Vector2(10, 60)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if not NetDebug.dev_tools_enabled() or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_F4:
			NetDebug.show_overlay = not NetDebug.show_overlay
		KEY_F5:
			NetDebug.enabled = not NetDebug.enabled
		KEY_F6:
			NetDebug.next_ping()
			if map.harness:
				NetDebug.apply_network(map.harness.network)
		KEY_F7:
			NetDebug.next_loss()
			if map.harness:
				NetDebug.apply_network(map.harness.network)
		KEY_F8:
			NetDebug.next_input_delay()
		KEY_F9:
			if map.harness:
				# move the puck a bit on the fake remote peer only, so the checksums stop matching
				map.harness.sessions[1].state.pos[0] += Vector2(5, 0)

func _process(_delta):
	visible = NetDebug.show_overlay
	if not visible:
		return
	var lines: Array[String] = []
	lines.append("ROLLBACK TEST %s  [F5, applies next match]" % ("ON" if NetDebug.enabled else "OFF"))
	lines.append("fake ping %d ms (+0-%d ms jitter) [F6]   loss %d%% [F7]   input delay %d ticks [F8, next match]" % [
		NetDebug.ping_ms, NetDebug.jitter_ms, roundi(NetDebug.loss * 100), NetDebug.input_delay])
	var session := map.session
	if session == null:
		lines.append("no rollback session")
	elif NetGame.is_online():
		lines.append("ONLINE as %s (peer %d), session %s" % [NetGame.Mode.keys()[NetGame.mode], NetGame.get_local_peer(), map.session_id])
		lines.append("tick %d, confirmed %d (%d ahead), input delay %d, frame advantage %.1f" % [
			session.current_tick, session.get_confirmed_tick(), session.current_tick - session.get_confirmed_tick(),
			session.input_delay, session.get_frame_advantage(Time.get_ticks_msec())])
		lines.append("rollbacks %d (%d/s), max depth %d, stalls %d, time sync waits %d" % [
			session.rollbacks, _rollbacks_per_second(session), session.max_rollback_depth, session.stalls, session.time_sync_waits])
		lines.append("desyncs %d (last at tick %d), snapshots sent %d / applied %d" % [
			session.desyncs, session.last_desync_tick, session.snapshots_sent, session.snapshots_applied])
		for peer in session.get_remote_peers():
			lines.append("ping to peer %d: %d ms" % [peer, session.get_ping(peer)])
	elif map.harness == null:
		lines.append("local session: tick %d, input delay %d, no remote players" % [session.current_tick, session.input_delay])
	else:
		var per_second := _rollbacks_per_second(session)
		lines.append("tick %d, confirmed %d (%d ahead), input delay %d" % [
			session.current_tick, session.get_confirmed_tick(), session.current_tick - session.get_confirmed_tick(), session.input_delay])
		lines.append("rollbacks %d (%d/s), max depth %d, resimulated ticks %d" % [
			session.rollbacks, per_second, session.max_rollback_depth, session.resimulated_ticks])
		lines.append("stalls %d, desyncs %d (last at tick %d), snapshots sent %d / applied on remote %d" % [
			session.stalls, session.desyncs, session.last_desync_tick, session.snapshots_sent, map.harness.sessions[1].snapshots_applied])
		lines.append("measured ping %d ms, packets lost %d / %d   [F9: force desync]" % [
			session.get_ping(1), map.harness.network.packets_lost, map.harness.network.packets_sent])
	lines.append("[F4: hide]")
	_label.text = "\n".join(lines)

func _rollbacks_per_second(session: RollbackSession) -> int:
	_rollback_window.append(session.rollbacks)
	if _rollback_window.size() > Simulation.TICK_RATE:
		_rollback_window.pop_front()
	return _rollback_window[-1] - _rollback_window[0]

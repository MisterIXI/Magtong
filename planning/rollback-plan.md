# Magtong: Rollback Netcode Plan

## 1. Which base: local-only (`ai-refactor`) or the old online branch?

**Build on the current local-only version.**

- Rollback needs **one simulation that every machine runs with the same inputs**. Networking only delivers
  inputs. The old branch was built the other way around: the host simulated, and RPCs plus
  MultiplayerSynchronizers copied the results to clients. Almost none of that carries over (`@rpc` everywhere,
  `is_server()` branches, the sync hacks).
- The local-only version is exactly "one sim, many inputs". Online then means some inputs come from the network.
  The new input system already gives one entry point per device.
- The only reusable bits of the old code are the Steam lobby create/join calls and the `SteamMultiplayerPeer`
  setup in `steam_handler.gd`. They're in git history (`main` / `f7dd434`), so we copy them back when we get to transport.
- Big upside of this order: phases A–C below are **fully playable and testable locally**, with no network at all.

## 2. Custom physics: what the rink needs

Godot physics can't be rolled back (no save/restore of state, no way to re-step 10 frames on demand, not
deterministic). So the gameplay sim gets its own small physics in plain GDScript. The world is tiny
(2–4 player circles, 1–3 puck circles, static walls), so this is a contained job.

### What exists today (`map_default.tscn`)
- Rink of about 1200 × 600: top/bottom walls at y = ±300, goal back walls at x = ±586.
- 4 corner pieces: the same hand-drawn `CollisionPolygon2D`, rotated. This gives the concave rounded corners.
- Goals inset into the short sides: a back wall plus top/bottom goal-mouth pieces (`RightWallTop/Bottom`, etc.).
  Goal *detection* is an `Area2D` inside the pocket.
- Center line: layer 2. Players (layers 1+2) collide with it; pucks (layer 1 only) pass through.
- Bodies: player r ≈ 22, mass 5, `linear_velocity.move_toward(target_vel, accel)`. Puck r = 16, mass 1, CCD on.
  Default physics material (friction 1, bounce 0), default linear damp.

### Proposed representation: everything static is line segments
- **One closed outline polyline** for the rink, including the goal pockets. The corners become arcs made of
  ~12–16 segments each. Plus a separate **center-line segment** that only collides with players.
- **Circle vs segment** is the only static collision test: find the closest point on the segment; if it's
  closer than r, push out along the normal and remove the inward part of the velocity (with bounce/friction).
  - **Concave corners** (rink corners): fine with enough segments, because each segment just pushes inward.
  - **Convex corners** (goal posts, where the wall turns into the pocket): handled automatically. The closest
    point lands on the segment *endpoint*, so the post acts like a point and pucks deflect off it naturally.
- **Circle vs circle** for player–puck, puck–puck and player–player. Treat it as an impulse collision with
  masses (5 vs 1) and a restitution value.
- **Tunneling** (fast pucks after a pulse or impulse): use **substeps** (e.g. 4 per tick) instead of CCD.
  It's cheap with this few bodies.
- **Goal detection**: a simple test of whether the puck center crossed the goal line inside the pocket.
  No Area2D.
- **Authoring stays in the editor**: draw the outline as a `Polygon2D` / `Line2D` / `CollisionPolygon2D`
  in the map scene, and convert it to a segment list when the map loads. Static geometry is never part of
  the rollback state.
- **Rotation**: skip angular physics in the sim. If pucks or players should spin visually, derive it in the
  visuals from velocity.

### Determinism (good enough, not perfect)
- Run a fixed tick (60 Hz) with integer tick counters. No `delta` from the engine inside the sim.
- Use only plain arithmetic and `sqrt` in the sim (avoid `sin`/`cos`/`atan2`). Keep iteration orders fixed.
  `Curve.sample()` for the magnet falloff is arithmetic-only. Even so, swap it for a baked lookup table or a
  polynomial so it can't change underneath us.
- `Vector2` is 32-bit float. That's fine as long as all players run the same build on x86_64.
- **Safety net**: send a checksum of the state every N ticks. On mismatch, the host sends a full snapshot
  and the client snaps to it. This makes small float differences (Windows vs Linux, etc.) harmless.

## 3. Todo list

### Phase A: tick-based simulation (local play only)
- [x] Define the sim state as plain data: bodies (pos, vel, radius, inv_mass, polarity, cooldown ticks),
      pucks (polarity), match (tick, scores, countdown ticks, overtime, game phase), ability state.
      Add `save() -> state copy`, `load(state)` and `checksum()`.
- [x] Define per-tick input as plain state: `{move: Vector2, plus: float, minus: float, primary_pressed, secondary_down, menu_pressed, aux…}`.
      `InputManager` samples the current state of each device once per tick. Edge-triggered buttons (pulse,
      menu) become "pressed this tick" flags. `PlayerMapping` keeps the mapping and returns state instead of events.
- [x] Build a `Simulation.step(state, inputs)`: one pure function and the single place gameplay happens.
      It owns movement, magnet forces, pulse, the abilities, goals, the countdown and the match timer.
- [x] Replace Godot `Timer`s / tweens used in gameplay with tick counters: `Pulse_CD`, `Impulse_CD`,
      `Orbit_CD`, `OrbitLimiter`, `GameTimer`, the countdown tween in `match_manager.gd`, and input lock.
- [x] Turn `PlayerBody` / `Puck` into **visual-only** nodes (`Node2D`, no RigidBody) that read the sim
      state each frame and interpolate between the last two ticks.
- [x] Make visual events (particles, flashes, the score overlay) come from **state changes**, not from calls
      inside the sim. Rollback re-runs ticks, so effects must not fire twice or fire for things that got undone.
- [x] Keep the lobby on the sim as well (team areas become rectangle checks in the sim), or keep the lobby on
      Godot physics for now. **Decision needed**; see the questions below.

### Phase B: custom physics
- [x] Segment builder: map outline node → list of segments (plus a "players only" flag for the center line).
- [x] Circle–segment collision with push-out plus velocity response (bounce, wall friction).
- [x] Circle–circle collision with masses and restitution.
- [x] Substeps, plus a max-speed clamp as a safety net.
- [x] ~~Orbit lock: replace `PinJoint2D` with a distance constraint~~ scrapped for now (experimental ability, removed together with the ability system; it's in git history).
- [x] Linear damping per body type.
- [x] Goal-line crossing check.
- [ ] Debug draw of segments, bodies and contact normals (toggle key). *Partly done: F3 toggles the rink outline + goal lines; bodies/contacts not drawn yet.*
- [ ] **Feel-tuning pass** against the current game: speed, accel, magnet force, mass ratio, bounce.
      The custom sim will *not* match Godot's physics exactly, so plan time for this.

### Status after phases A + B (2026-10-25)
- Code: `simulation/` (`simulation.gd`, `sim_state.gd`, `sim_input.gd`, `rink_outline.gd`). `MapScript` owns and steps
  the sim; `PlayerBody` / `Puck` are visual-only; `MatchManager` only shows the sim's match state.
- Lobby, match and the main menu background all run on the same simulation (the menu as a wall-less sandbox).
- Rink: parametric `RinkOutline` node (defaults measured from the old colliders, verified against the field texture).
- Tests: `godot --headless --path Magtong -s res://tests/sim_test.gd` (determinism, save/replay, no tunneling,
  goals, center line, lobby areas, input packing).
- Frozen: `frozen/AI` and `frozen/trailer` (`.gdignore`), still on the old Godot-physics code.
- Lobby menu actions (start game, skin cycling) are still handled outside the sim via `PlayerInput.input_received`.
  For online lobbies they need to become synced events. Revisit in phase D.
- Feel tuning still open: puck rotation is gone, wall friction is 0, bounce 0 (like the old default material).

### Phase C: rollback core (still local, simulated latency)
- [x] Ring buffer of the last ~16 states and inputs per tick.
- [x] Input prediction: a remote player's missing input = repeat their last known input.
- [x] On late input: load the state from that tick, re-simulate up to now, compare.
- [x] Input delay setting (start with 2 ticks ≈ 33 ms).
- [x] **Fake-network test harness**: two sims in one process, or two local instances, with configurable delay,
      jitter and packet loss. This is where most of the bugs get found, before Steam is involved.
- [x] Desync detection: periodic checksum exchange, log the first mismatching tick, and recover from a snapshot.
- [x] Rollback stats overlay: rollback frames per second, max rollback depth, ping.

**Status after phase C (2026-10-25):**
- Code: `netcode/` (`rollback_session.gd`, `fake_network.gd`, `local_net_harness.gd`, `net_debug.gd`, `net_debug_overlay.gd`).
- Every match runs through a `RollbackSession`. Fully local: input delay 0, no remote players, never rolls back.
- In-game rollback test: `F5` (or `-- --rollback-test`) makes team 1 "this machine" and team 2 a fake remote
  peer with its own simulation, connected through `FakeNetwork`. `F4` overlay, `F6` ping, `F7` loss,
  `F8` input delay, `F9` force a desync. Command line: `--fake-ping=120 --fake-jitter=20 --fake-loss=0.05 --input-delay=2`.
- Tests: `godot --headless --path Magtong -s res://tests/rollback_test.gd`. Peers on a bad network (2v2, 140 ms,
  30 ms jitter, 15% loss; and 3 peers) end bit-identical to a reference simulation; stall + recovery; desync recovery.
  A deliberately broken rollback makes 5 of these fail.
- Not done yet / moved on: rollback corrections snap (smoothing is phase E); time sync between real machines
  (both fake peers share one clock, phase D); the lobby still runs without a session.

### Phase D: transport and session
- [x] Packet format: tick plus the last N inputs (redundant), sent **unreliable** every tick, plus acks.
      No reliable channel for inputs, so one lost packet doesn't stall everything behind it.
- [x] Transport layer with two backends: ENet direct connect (testing, LAN) and Steam
      (`SteamMultiplayerPeer` or Steam Networking Messages). Restore the lobby code from git history.
- [ ] Check whether Steam traffic goes through Steam's relay servers (the 30 → 70 ms jump) and whether a
      direct P2P connection is possible. *Needs two Steam accounts: test with a friend.*
- [x] Session flow: lobby → agree on settings and seed → synchronized start tick → match → rematch.
- [x] Mixed local and online: several local players per machine, so each machine sends multiple input slots.
- [x] Disconnects and timeouts. Stall when too far ahead of the remote ("frame advantage" throttling).

**Status after phase D (2026-10-25):**
- Code: `netcode/net_transport.gd` (raw packets over any `MultiplayerPeer`, ENet or Steam), `netcode/net_game.gd`
  (autoload `globNet`: connection, roster, lobby epochs, packet routing, host relay, keepalive and 5 s timeout),
  `global/steam/steam_handler.gd` (friends-only Steam lobby + invite dialog, join via invite / `+connect_lobby`).
- Lobby online: the host owns the roster. Joins and leaves send the host's lobby state to everyone, and every
  machine rebuilds its lobby session from it. Starting the match (MENU) and skins (AUX) are simulation
  inputs now, so the start is decided inside the simulation; every machine starts the same match (same teams, skins,
  seed and session id) from the same *confirmed* lobby tick. No extra messages needed.
- Time sync: each machine estimates how far it runs ahead (`RollbackSession.get_frame_advantage`) and skips a tick
  now and then while ahead.
- A machine leaving: the lobby removes its players; during a match the host sends everybody back to the lobby;
  if the host leaves, clients go back to the menu with a message.
- Menu: Play Local, Host Online (Steam), Host Direct (IP), address field + Join Direct.
  Command line: `--host[=port]`, `--join=ip[:port]`, `--input-delay=n`, and for testing two local processes like a
  real connection `--net-lag=ms --net-loss=0..1` (applies to everything that machine sends).
- Verified: two separate game processes over ENet (localhost) run lobby → join → teams → start → match and end on
  the same checksum at tick 400, also with `--net-lag=100 --net-loss=0.1` each (rollbacks happen, no desyncs);
  the client leaving mid-match sends the host back to the lobby. Time sync is covered in `tests/rollback_test.gd`.
- Not tested yet: Steam (needs a second account), 3+ machines over ENet (host relay; only covered by the
  3-peer harness test), real internet connections (NAT: direct connect needs port forwarding on the host).
- Known limits: the lobby hitches briefly on every join/leave (rebuild); returning to the lobby only happens on a
  disconnect (no "back to lobby" button after a match yet); clients relay through the host (adds latency with 3+ machines).

### Phase E: polish
- [ ] Hide rollback corrections visually (smooth the remote players' render position after a correction).
- [ ] Sound and effect timing under rollback.
- [ ] Optional: a replay system. It comes almost for free (seed plus input log).

## 4. Open questions to go over
1. **Lobby physics**: should the lobby run on the new sim too (consistent feel, needed for online lobbies) or stay on Godot physics?
-> Yes, the lobbies should also run on the same logic as the games, as it just does the same right now. And it also serves as a playground for the players to get a feel for the puck play. If it would be way easier to have it seperate it would be okay, but best the same logic as in game.
2. **Feel**: is "close to current, then tuned" fine, or must it match today's feel exactly?
-> close to current, then tuned is fine. As it isn't fully locked in anyways.
3. **Player count online**: 1v1 only at first, or 2v2 with local + online players mixed?
-> The final goal would be a max 2v2 or even 3v3 with mixed local and online players. That was the initial thing. Actual "serious" gaming would be the 1v1 mode only basically. But 2v2 can also be fun potentially. 3v3 is way to chaotic, so I would be fine scrapping that if necessary. The same with the mix with local/online player mix.
4. **Platforms**: Windows + Linux only (both x86_64)? If macOS ARM matters, the checksum/snapshot recovery becomes essential.
-> Windows + Linux only is enough. No macos support necessary.
5. **AI / RL agents** (`scenes/AI`): they depend on Godot physics. Port them to the new sim, or freeze them for now?
-> I wanted to train RL agents as NPC enemies eventually, but they are not the goal for now. So freeze them for now.

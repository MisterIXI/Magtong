# Magtong: Remove Online Multiplayer → Local-Only

## Context
Online multiplayer (ENet + Steam lobbies/SteamMultiplayerPeer) never worked reliably, and it makes the
whole codebase server/client-shaped: every gameplay change goes through `@rpc`, `multiplayer.is_server()`
guards, MultiplayerSpawner/Synchronizer nodes, and an input pipeline that sends every keypress to
"the server" (peer 1) via RPC, even in local play. Goal: rip all of that out and keep a plain
local-multiplayer game (1 keyboard + N gamepads, or N gamepads). Steam stays initialized (overlay /
future achievements) but its lobby code is reduced to a skeleton.

Note: `planning/refactor-plan.md` from the earlier attempt doesn't exist anywhere (not in the repo,
other branches or the backups), so this plan starts from scratch. **Step 0 writes this checklist to
`/home/yannik/Repos/Magtong/planning/refactor-plan.md`** so it lives in the repo.

**Why the refactor is safe to do step by step:** with no peer set, Godot uses `OfflineMultiplayerPeer`:
`is_server()` is true, `get_unique_id()`/`get_remote_sender_id()` return 1 and `foo.rpc()` with
`call_local` just runs locally. So the game should still run after every step below. We remove
indirection and change no behavior.

General pattern applied everywhere (described once):
- `@rpc(...)` annotation → delete; `foo.rpc(args)` / `foo.rpc_id(id, args)` → `foo(args)`.
- `if multiplayer.is_server(): X` → `X`; `if not multiplayer.is_server(): return` → delete;
  `assert(multiplayer.is_server())` → delete.
- `@rpc("authority", "call_remote")` functions (client-only mirrors) → delete entirely.

---

## Checklist

### 0. Setup
- [x] Write this plan to `planning/refactor-plan.md` (repo root, next to `Magtong/`).
- [x] Work on branch `ai-refactor` (current).

### 1. Delete dead / pure-online code
- [x] Delete old, unreferenced lobby: `scenes/Lobby/lobby.gd`, `lobby_scene.tscn`, `player_container.gd`,
      `player_container.tscn`, `Player.gd`, `input_class.gd`, `PlayerInputInstance.gd`
      (+ their `.uid` files). `game_lobby.tscn` is the lobby actually in use (via `game_manager.tscn`).
      Before deleting, check whether `player_team_selector.tscn`, `selection_box.gd`, `selection_tweener.gd`
      are only used by the old lobby and delete them too if so.
- [x] Delete `scenes/game_scene.tscn` (old unreferenced scene with its own MultiplayerSpawner). Verify nothing references it first.
- [x] Delete `global/Multiplayer/MP_Manager.gd` (unused ENet prototype, not autoloaded) and the folder.
- [x] Delete `global/ping_tester.gd`; in `global/game_manager.tscn` remove the `PingTester` node, its `Timer`,
      the `CanvasLayer/PingLabel` node, the ext_resource and the `timeout → on_timeout` connection.
- [x] Delete `scenes/Maps/MPs_map_adder.gd` (only fed map scenes into a MultiplayerSpawner).

### 2. Input system (the main simplification)
Current flow: `InputManager._input` → `send_input.rpc_id(1, device, dict)` → server looks up
`player_inputs[peer_id][device_id]` → `PlayerInput.execute_input`. Registration goes
`request_player_registration.rpc_id(1)` → server creates `PlayerInput` → `register_player.rpc_id(peer)`
→ client creates `PlayerMapping` in a *separate* dict. New flow is direct:
`_input` → find `PlayerInput` by device → `mapping.check_input(event)` → `execute_input(info)`.

`global/Input/input_manager.gd`
- [x] Replace the three dicts (`player_mappings`, `player_inputs[peer][device]`, `player_cust_id`) and
      `own_id`/`cust_id_helper` with one: `var player_inputs: Dictionary = {}  # device_id -> PlayerInput`,
      plus `const KEYBOARD_DEVICE_ID := -1` and `var next_player_id: int = 1`.
- [x] Rewrite `_input(event)`:
      device = `KEYBOARD_DEVICE_ID` for `InputEventKey`, `event.device` for joypad button/motion, else return.
      If registered: `var info = player_inputs[device].mapping.check_input(event)`; if `info`: `execute_input(info)`.
      Else if state is `LOBBY` and the event is a key/button *press* (not motion): `register_player(device)`.
- [x] Replace `send_input` / `request_player_registration` / `register_player` RPCs with one local
      `register_player(device_id) -> PlayerInput`: creates `PlayerInput.new(device_id, next_player_id)`,
      `add_child`, stores it, increments id, emits `player_input_registered`.
- [x] `get_all_player_inputs()` → `return player_inputs.values()`. Delete `total_player_count()` (only old lobby used it).
- [x] Keep `input_locked`, `set_input_locked()`, `input_unlocked`, `player_input_registered` unchanged.

`global/Input/player_input.gd`
- [x] Remove `peer_id`, `is_host`, `to_dict()`, `from_dict()` (RPC serialization only).
- [x] `_init(device_id, player_id)`; add `var mapping: PlayerMapping` created in `_init`
      (`PlayerMapping.new(device_id == InputManager.KEYBOARD_DEVICE_ID)`), and `func is_keyboard() -> bool`.

`global/Input/player_mapping.gd`
- [x] `extends Node` → `extends RefCounted` (it is never added to the tree).
- [x] Remove the `player_id` field/param (it was set to the network peer id); `_init(is_keyboard: bool)`.
- [x] Delete `set_keyboard_mapping2()` (no 2nd keyboard player planned).

`global/Input/input_info.gd`
- [x] No change. The dict constructor is still used by `mm_background.gd` / `trailer_scene.gd`; `to_dict` can stay.

### 3. GameManager, menu, scene root
`global/game_manager.gd`
- [x] Delete `host_game`, `join_game`, `_on_peer_connected`, `_on_connected`, `_on_disconnected`,
      `player_ids`, `p_id_helper`, `lobby_finished`, and the unused duplicate `input_locked`.
- [x] Add `func start_local_game(): _change_state(State.LOBBY)`.
- [x] `_change_state`: remove `@rpc` and the `multiplayer.is_server()` guards around `scene_root.change_scene`.
- [x] Merge `send_message` (rpc) into `print_message`; update callers (`match_manager.gd`).
- [x] Delete the lobby countdown (`start_countdown`, `cancel_countdown`, `countdown_step`, `countdown`, `timer` export).
      Only the deleted old lobby used it. Also remove the `Countdown_Timer` node + connection in `game_manager.tscn`.

`scenes/Menu/main_menu.gd` + `main_menu.tscn`
- [x] `_on_start_local_pressed` → `globGameManager.start_local_game()`.
- [x] Delete `_on_host_online_pressed`, `_on_join_online_pressed`, `_on_join_local_pressed`, `ip_edit_field` export.
- [x] In the tscn: remove `Host_online`, `Join_online`, `IP_Edit_Field`, `Join_local` nodes and their connections;
      fix focus neighbors so `Start_local ↔ Settings ↔ Quit`.

`scenes/main/scene_root.gd` / `main_scene.tscn`
- [x] Remove both `assert(multiplayer.is_server())`.
- [x] Remove the `SceneSpawner` MultiplayerSpawner node.

### 4. Lobby (`scenes/Lobby/game_lobby.gd` + `.tscn`)
- [x] `_ready`: drop the `is_server` guard and the `peer_connected` connection.
- [x] Delete `on_peer_connected`, `catchup_on_join` (late-join sync only).
- [x] `_update_lobby_labels`, `emit_ready`: remove `@rpc`, call directly.
- [x] tscn: remove the `MultiplayerSpawner` node and its `MPMapAdder` child. `HostSettings` (hidden, empty) can go too.

### 5. Match (`scenes/match_manager.gd`, `scenes/Maps/map_script.gd`)
`match_manager.gd`
- [x] Remove the peer-ready handshake (`peer_ready_state`, `_ready_to_play`, `all_ready`). `_ready()` now just calls
      `setup(match_time)` then `restart_match()`.
- [x] Remove `@rpc` from `setup`, `restart_match`, `score_for_team`, `resume_game`, `game_over`, `request_restart`; strip `is_server` guards.
- [x] Delete `client_game_countdown` (call_remote) and its call in `start_game_countdown`, plus the stub `spawn_map`.
- [x] Replace `gm.send_message.rpc(...)` with `gm.print_message(...)`.
- [x] `request_restart`: condition becomes `if not game_running:`.
- [x] Optional: `_on_goal_south/north_body_entered` look like leftovers from `game_scene.tscn`. Delete them if `match_manager.tscn` doesn't connect them.

`map_script.gd`
- [x] Remove `spawner: MultiplayerSpawner` export (and the property in `map_default.tscn` / `ai_map_default.tscn`).
- [x] Strip `is_server` guards in `setup`, `_on_goal_collision`, `reset_balls`, `reset_players`, `_physics_process`,
      `on_player_entered/left_team_area`; remove `@rpc` from `disable_lobby_features`.
- [x] `.rpc()` → direct for `disable_lobby_features`, `reset_input_state`, `receive_pulse`.
- [x] `setup()`: replace the nested `for peer in im.player_inputs: for player in ...` with `for player_input in im.get_all_player_inputs()`.
- [x] Remove the debug `print("all player_inputs: ", ...[0].team)` in `spawn_player` (it reads index 0 blindly).
- [x] tscn (`map_default.tscn`, `ai_map_default.tscn`): delete `EntitySpawner` nodes. Keep `MultiplayerRoot`
      (optionally rename to `EntityRoot` and update the `mp_root` path and the `child_entered_tree` connection).

### 6. Entities (player, puck, abilities)
`scenes/Player/PlayerBody.gd`
- [x] Delete `_integrate_forces` sync hack and `sync_pos` / `sync_rot`.
- [x] Delete `if not is_multiplayer_authority(): freeze = true`.
- [x] `on_input(input_info)`: drop `ignore_server_check` param + assert (no caller passes it).
- [x] MENU in lobby: `if player_input.peer_id == 1` → any local player may call `gl.request_game_start()`.
- [x] Remove `@rpc` from `change_polarity`, `reset_input_state`, `pulse`, `set_skin`; `.rpc()` → direct.

`scenes/Player/player_body.tscn`, `scenes/AI/ai_player_body.tscn`
- [x] Delete both `MultiplayerSynchronizer` nodes (root + under `Abilities/OrbitLock`) and their `SceneReplicationConfig` sub_resources.
      Do this in the Godot editor so `load_steps` stays consistent.

`scenes/Puck/Puck.gd` + `puck.tscn`
- [x] Remove `@rpc` from `reset`, `receive_pulse`; `receive_pulse.rpc(true)` → `receive_pulse(true)`.
- [x] Delete the `MultiplayerSynchronizer` node + replication sub_resource.

`scenes/Player/Abilities/impulse.gd`
- [x] Remove `rpc_impulse_signal`; emit `impulse_emitted` directly.

`scenes/Player/Abilities/orbit_lock.gd`
- [x] `_setup`: always create joints (drop `multiplayer == null or multiplayer.is_server()`).
- [x] Remove `@rpc` from `activate_ability` / `deactivate_ability`, `.rpc()` → direct, strip `is_server` branches.
- [ ] Optional cleanup: switch `map.spawned_pucks` → `map.pucks`, then delete `spawned_pucks`, `spawned_players`
      and `on_node_spawned` in `map_script.gd` plus the `child_entered_tree` connections. Only do it after the
      timing check: pucks must be in `map.pucks` before abilities run `_setup`.

### 7. Steam → skeleton (`global/steam/steam_handler.gd`)
- [x] Keep: constants, `steam_id`, `steam_name`, `_ready` → `initilize_steam()`, `_process` → `Steam.run_callbacks()`, `get_steam_name()`.
      Drop `Steam.initRelayNetworkAccess()`.
- [x] Remove: `connect_steam_lobby_funcs` and all `_on_lobby_*` / `_on_p2p_*` / `_on_join_requested` /
      `_on_persona_state_change` callbacks, `peer`, `is_host`, `lobbies`, `curr_lobby_members`, `lobby_id`,
      `_get_lobby_members`, `make_p2p_handshake`, the `_input` SPACE debug handler.
- [x] Leave skeleton stubs `create_lobby()` / `join_lobby(id)` with `# TODO: online not supported` + `push_warning`. No calls to `globGameManager`.
- [x] `project.godot`: keep the `globSteamHandler` autoload and the GodotSteam addon.

### 8. Remaining stragglers
- [x] `scenes/Menu/mm_background.gd:174` and `scenes/trailer/trailer_scene.gd:160`: delete `if not multiplayer.is_server(): return`.
- [x] Check `scenes/AI/ai_map_script.gd` / `ai_root.gd` for `spawner` / `is_server` usage left over from `MapScript`.
- [x] Final sweep must only hit the Steam skeleton:
      `grep -rnE "rpc|multiplayer|peer_id|is_server|MultiplayerSpawner|MultiplayerSynchronizer|Steam\." --include=*.gd --include=*.tscn Magtong | grep -v addons/ | grep -v .godot/`

### Status (2026-10-24)
Done except the optional `spawned_pucks` cleanup. `MultiplayerRoot` was not renamed. The `[steam] multiplayer_peer/max_channels`
setting in `project.godot` was left in place because it belongs to the GodotSteam addon, which stays.
Verified with a headless Godot 4.6.3 run of a scripted smoke test (menu → lobby join → match → countdown → input →
score → game over → restart: all checks passed, no script errors). A manual playtest with a real gamepad is still pending.

### Out of scope (note for later)
- Removing a player / gamepad disconnect in the lobby, clearing `player_inputs` on return to menu
  (no return-to-menu flow exists yet).
- A second keyboard player. Not planned.

---

## Critical files
`global/Input/input_manager.gd`, `player_input.gd`, `player_mapping.gd`, `global/game_manager.gd(.tscn)`,
`global/steam/steam_handler.gd`, `scenes/Lobby/game_lobby.gd(.tscn)`, `scenes/match_manager.gd`,
`scenes/Maps/map_script.gd` + `map_default.tscn`, `scenes/Player/PlayerBody.gd` + `player_body.tscn`,
`scenes/Puck/Puck.gd` + `puck.tscn`, `scenes/Player/Abilities/{impulse,orbit_lock}.gd`,
`scenes/Menu/main_menu.gd(.tscn)`, `scenes/main/{scene_root.gd,main_scene.tscn}`.

## Verification
1. Script/scene errors: open the project in the Godot 4.6 editor (or `godot --headless --path Magtong --editor --quit`)
   and confirm there are no parse errors and no missing NodePath / broken scene warnings.
2. Run the final grep from step 8.
3. Manual playtest (`godot --path Magtong`):
   - Menu shows only Play Local / Settings / Quit; the background animation still plays.
   - Lobby: keyboard press joins one player, each gamepad button press joins one more; moving into the team areas
     updates the counters; the ready banner appears; MENU (Esc/Start) from any player starts the match.
   - Match: countdown locks input, then magnets pull/push the puck, pulse (Space/A) flips its polarity,
     the ability (L/B) works (impulse / orbit lock), goals score and reset the field, timer runs out, overtime
     works on a tie, game over shows, and MENU restarts.
   - Physics feels the same as before (no jitter from the removed `_integrate_forces`).

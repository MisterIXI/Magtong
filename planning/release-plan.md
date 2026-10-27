# Magtong: Release Plan (Steam 1.0)

## Context
The Steam release date (app 3044580) was probably left at 30.10.2026, which is 3 days from now (27.10), and Steam
now wants a support ticket to move it. Steam never launches by itself: the build has to pass review and the
release button has to be pressed by hand. So we move the date instead of crunching to it.
**Target: release in about 6 weeks, around Tue 08.12.2026.**

Agreed scope for 1.0: local multiplayer, **online 1v1** over Steam (2v2 online best effort, not a blocker),
audio from licensed/CC0 packs, the existing rink and skins. **AI opponents become the first post-launch update.**
Store page is already live as "Coming soon".

State today (from the repo): the rollback netcode works (phases A–D done, tested with a friend over Steam at
about 50 ms). Missing: any sound effects (the only music track is the trailer track), the Settings sliders
(`scenes/Menu/main_menu.tscn` Master/SFX/Music) aren't wired and no settings are saved, there's no controls/how-to-play
screen, there's only one map (`resources/maps/standard_maps/2t_hockey_outward.tres`), the debug keys F4–F9
(`netcode/net_debug_overlay.gd`) and the direct-IP menu buttons are active in every build, rollback corrections
snap, and the feel tuning is open.

Step 0: commit the current WIP (connection icon, lobby return), then copy this plan to `planning/release-plan.md`.

---

## Week 0 (now): unblock
- [ ] **Open the Steam support ticket**: move the release date to the target. Also check in Steamworks which
      release checklist items are still open (build review, pricing, content survey, depots).
- [ ] Decide the price and the launch discount. Optionally enable Remote Play Together (a cheap extra for
      casual sessions; real online play is the native 1v1 mode).
- [ ] Fill in the AI disclosure in the Steamworks content survey to match the actual AI use (read the current wording).
- [ ] Update the store description: "multiplayer only at launch, AI opponents coming in an update".

## Week 1: conventions refactor, settings, audio foundation, release hygiene
- [x] **Godot naming refactor (first, before any new code; timebox 1 day; one commit with renames only, no behavior changes).**
      Follow the GDScript style guide: snake_case for files and folders, PascalCase for node names and `class_name`,
      snake_case for vars/funcs, CONSTANT_CASE for constants.
      - Files: `PlayerBody.gd`, `PlayerVisuals.gd`, `PulseEmitter.gd`, `Puck.gd`, `StartMenu.gd`, `Level_Scene.tscn`,
        `resources/Default_Box.tres`, `Default_button_theme.tres`, `Player_/Puck_physics_mat.tres` (the physics mats are
        probably unused since the custom physics; delete them if so).
      - Folders: `global/Input`, `scenes/{Lobby,Maps,Menu,Player,Puck}`, `scenes/Menu/Needles`, `assets/{Icons,Models,Textures}`
        and the folders under them → lowercase.
      - Autoloads: drop the `glob` prefix (`globGameManager` → `GameManager`, etc.). Where a script already has a
        `class_name` with the same name (e.g. `InputManager`), remove the `class_name` or pick a different name, since an
        autoload and a `class_name` can't share one name.
      - Identifiers: `j_plusB`/`j_minusB` in `player_mapping.gd`; node names like `T1_Score_Label`/`Timer_HBOX` in
        `scenes/Maps/match_manager.tscn` → PascalCase (and update the `$`/`%` paths that use them).
      - Skip `frozen/` and `addons/`.
      - How: `git mv`, then rewrite the `res://` paths in `.gd`/`.tscn`/`.tres`/`project.godot` (the `.uid` files
        keep most references working anyway). Move the `.import` files with their assets, then open the editor once so it
        reimports and reports broken dependencies. Optional: run `gdlint` (gdtoolkit) and fix what it finds.
      - Check: both test scripts pass, the editor shows no missing dependencies, and a local match and a two-process ENet
        match still work.
- [x] `Settings` autoload: a `ConfigFile` at `user://settings.cfg` with Master/Music/SFX volume, window
      mode (fullscreen/windowed/borderless), vsync. Applied at startup.
- [x] Audio buses (Master, Music, SFX) in `default_bus_layout.tres`; wire the existing sliders in the main
      menu's Settings panel to them.
- [x] Add window mode + vsync controls to the Settings panel. Make the whole menu work with gamepad focus.
- [x] Release build flag: in non-debug builds (`OS.is_debug_build()` false), disable `NetDebugOverlay` keys
      F4–F9, the `--fake-*` / `--net-lag` command-line flags, and hide Host Direct / Join Direct (or keep them
      behind a setting, for LAN).
      *Done: `NetDebug.dev_tools_enabled()` (= `OS.is_debug_build()`) gates the keys, all test arguments incl.
      `--host`/`--join`, the F12 message log and the direct connect menu entries.*
- [x] Remove or fix the leftover `print`/`gm.print_message` spam in `scenes/match_manager.gd` and other places.
- [x] Export presets: check Windows and Linux both export cleanly, with the icon and version
      (`config/version` → `1.0.0`). Check that `addons/godot_rl_agents` isn't included in the export.
      *Done: export excludes `addons/godot_rl_agents`, `tests`, `scenes/test`, `scenes/tools`, `script_templates`;
      Windows icon `assets/icons/magtong.ico` (still needs a 256×256 size, the exporter warns).
      The prints left are a few Steam init lines and the match log, kept.*

## Week 2: audio + game feel
- [ ] Gather a CC0/royalty-free SFX pack plus 2–3 music tracks (menu, lobby, match). Keep the licenses in
      `assets/sounds/LICENSES.md` and credit them.
- [ ] Rollback-safe sound: trigger SFX from **state changes seen by the visuals**, the same pattern the
      particle/score effects already use (phase A), never from inside `Simulation.step`. Dedupe per
      (event, tick) so a rollback re-sim doesn't play a sound twice.
      Sounds: puck hit (player/wall, by impact speed), magnet on/off loop, pulse, goal, countdown beeps,
      game over, menu navigate/confirm, player join/ready in the lobby.
- [ ] **Feel-tuning pass** (rollback-plan phase B open item): speed, accel, magnet force, mass ratio,
      wall bounce/friction. Playtest locally. Keep `tests/sim_test.gd` green after every tuning change.

## Week 3: online 1v1 polish
- [ ] Smooth rollback corrections (phase E): blend the remote player's render offset back to zero over
      ~100 ms after a correction, in `PlayerBody`/`Puck` visuals.
- [ ] Clear online UX states: connecting, host left, peer timed out (the connection icon from the current WIP),
      "invite friend" button in the online lobby, `+connect_lobby` / join via the Steam overlay tested from a cold start.
- [ ] Real-internet tests with at least 2–3 different people/networks; 2v2 online (2 machines × 2 local players) once.
      Write down every bug, fix the blockers, put the rest in a post-launch list.
- [ ] Desync logging to `user://` so players can send logs.
- [ ] Own the netcode: walk through `rollback_session.gd`, `net_game.gd` and `net_transport.gd` with Claude until
      you can explain the design (prediction, re-sim, time sync, desync recovery) and fix one of the found bugs yourself.

## Week 4: onboarding + presentation
- [ ] Controls / how-to-play screen (keyboard + gamepad glyphs, the existing `assets/Icons`), reachable
      from the main menu and the lobby. Short hint text in the lobby: join, pick a team, ready up.
- [ ] Pause menu in local matches (resume / back to lobby / main menu); online: leave match.
- [ ] Credits screen (assets, music licenses, Godot, GodotSteam).
- [ ] Store: update screenshots/trailer if the game looks noticeably different now.

## Week 5: release candidate
- [ ] Feature freeze. Bug fixing only.
- [ ] Test matrix: Windows, Linux, **Steam Deck** (controller-only navigation, text readable at 1280×800),
      keyboard + 1–3 gamepads, hot-plugging a gamepad, alt-tab/fullscreen, window close during an online match.
- [ ] Steamworks: depots for Windows + Linux, upload with SteamPipe (`steamcmd` + an app build VDF script
      in the repo), set the build live on a `beta` branch, test-install it from Steam on a clean machine.
- [ ] **Submit the build for review by ~Mon 30.11** (review can take several business days).

## Week 6: launch
- [ ] Set the build live on default, press Release on the target date.
- [ ] Watch reviews/discussions for the first days; ship a hotfix build if needed.

## Cut from 1.0 (post-launch backlog)
AI/RL opponents (first update), more rinks, more skins, 3v3, replays, public matchmaking, guaranteed 2v2 online,
own music/SFX replacing the packs.

## Risk notes
- If week 3 testing finds big online problems: ship 1.0 with online labeled "Beta" or push the date
  once more. Don't ship broken netcode as the main feature.
- Each week ends with a playable build exported and tested, so the cut line stays visible.

## Verification (every week)
- `~/Applications/Godot/godot --headless --path Magtong -s res://tests/sim_test.gd` and `.../rollback_test.gd` pass.
- Two-process ENet test (`--host`, `--join=127.0.0.1 --net-lag=100 --net-loss=0.1`) still ends on the same checksum.
- Exported release build launches, F4–F9 do nothing, settings persist after a restart.

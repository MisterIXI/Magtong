# Magtong: Release Plan (Steam 1.0)

## Context
The Steam release date (app 3044580) was probably left at 30.10.2026, and Steam wants a support ticket to move
it. Steam never launches by itself: the build has to pass review and the release button has to be pressed by hand.
So we move the date instead of crunching to it.
**Target: release around Tue 08.12.2026.**

**Scope change 01.11: 1.0 is local multiplayer only.** The first Steam playtest (31.10) never got through a round:
both peers stalled forever after a short one-way packet loss (fixed in `c79a55d`, regression test
`test_one_way_loss`). The fix was quick, but the real bottleneck is testing online with real people over Steam, and
that would eat the time needed to finish the game itself. Online comes after launch (see "Online after 1.0").

Agreed scope for 1.0: local multiplayer (keyboard + gamepads), **Steam Remote Play Together** as the way to play
with friends over the internet, audio from licensed/CC0 packs, the existing rink and skins, a tutorial.
**Simple bots only if they fit before the release candidate**, otherwise they're the first post-launch update.
Store page is already live as "Coming soon".

Order of work: **finish the game → polish → tutorial → bots.** Each step ends with a playable exported build.

---

## Week 0 (27.10): unblock
- [X] **Open the Steam support ticket**: move the release date to the target. Also check in Steamworks which
      release checklist items are still open (build review, pricing, content survey, depots).
      *Opened 27.10. Valve answered 08.11: release date moved to 08.12.2026, and it can now be changed by hand
      in Steamworks if needed. Aim to keep 08.12.*
- [x] Decide the price.
      *$6.99, auto pricing for the other currencies. Status "New prices reviewed, publish when ready":
      publish before release.*
  - [ ] Decide the launch discount.
- [x] Fill in the AI disclosure in the Steamworks content survey to match the actual AI use (read the current wording).
      *Set to "no": the survey excludes coding assistance, and all player-facing assets (visuals, texts,
      translations) are made without genAI. Re-check if that ever changes.*
- [x] **Enable Remote Play Together** in Steamworks (now the online answer for 1.0, no longer optional).
- [ ] Update the store description and tags: local multiplayer, Remote Play Together. Don't mention online play
      or bots until they ship (only promise what's in the build).

## Week 1 (27.10–01.11): conventions refactor, settings, audio foundation, release hygiene ✔
- [x] Godot naming refactor (one commit, renames only).
- [x] `Settings` autoload (`user://settings.cfg`): volumes, window mode, vsync, applied at startup.
- [x] Audio buses (Master, Music, SFX), wired to the Settings panel. Whole menu works with gamepad focus.
- [x] Release build flag: `NetDebug.dev_tools_enabled()` (= `OS.is_debug_build()`) gates the debug keys, test
      arguments, the F12 log and the direct connect menu entries.
- [x] Leftover print spam removed (a few Steam init lines and the match log kept).
- [x] Export presets for Windows and Linux, version 1.0.0, dev folders excluded.
      *Windows icon still needs a 256×256 size, the exporter warns.*

## Week 2 (02.–08.11): finish the game
Goal: the game works start to finish and could ship as is, even if it isn't pretty yet.
- [x] **Hide online in release builds**: Host Steam in the main menu behind `NetDebug.dev_tools_enabled()` like the
      direct connect entries, and make sure Steam invites / `+connect_lobby` don't open an online lobby in release
      builds. Keep all online code (see "Online after 1.0").
      *`NetDebug.online_enabled()`: debug builds, or an export with the custom feature tag `online` (for a later
      online beta branch). Gates the Host Steam button and the Steam lobby/invite callbacks; Steam itself stays on.*
- [x] Debug-only "Short Test Match (15 s)" menu entry (`GameManager.test_match_time`), for quick loop tests.
- [x] Automated full loop with virtual pads (01.11): menu → lobby → countdown → match → tie → overtime →
      goal → game over → rematch → game over → lobby works. Found and fixed: game over text far too big
      (the countdown label's font size), unreadable.
      Open from that run:
  - [x] Game over says "Player 1 Wins!" but it's a team: now "Team Red Wins!" / "Team Blue Wins!".
  - [x] Debug builds: the main menu runs off the bottom (Quit is cut off). Cause: the background's Camera2D also
    shrank the menu and pushed it to the lower right (in release builds too); the background now scales itself.
- [x] Pucks spin: contacts with walls, players and pucks turn sliding into spin (cosmetic, in the simulation so
  rollback stays in sync; tune with `puck_spin_grip` / `puck_spin_damp` in PlayerSettings).
- [ ] **Play the full loop locally and list what's broken or missing**: main menu → lobby (join, team pick, ready)
      → countdown → match → goal → overtime → game over → back to lobby / main menu, with 2, 3 and 4 players and
      mixed keyboard/gamepads. Put the list here and fix the blockers.
- [x] Pause menu in local matches: resume / back to lobby / main menu.
      *`scenes/pause_menu.gd`: any player opens/closes it with Start / Esc during countdown and play (not after
      the game over, where Start is rematch), any pad navigates. Buttons are released on resume, so the
      confirm press doesn't pulse.*
- [x] Gamepads in menus: A confirms and B goes back on every pad (`ui_accept`/`ui_cancel` had only keys,
      so the game couldn't be started with a pad alone).
- [x] Keyboard/mouse parts that show up as joypads (e.g. a Keychron's media keys) can't join as players.
- [ ] **Feel-tuning pass** (rollback-plan phase B open item): speed, accel, magnet force, mass ratio,
      wall bounce/friction. Playtest locally. Keep `tests/sim_test.gd` green after every tuning change.
      *08.11: `wall_bounce` and `body_bounce` 0 → 0.3, feels better (test `test_puck_bounce`). They also apply to
      players, but the fast steering (`accell` 6000) hides it. Split into puck-only values if that changes.*
- [x] Gamepad hot-plugging and disconnects during a match don't break the game.
      *A disconnected pad lets go of everything (no drifting, no stuck magnet); replugged, it gets its device
      id back and continues as the same player. Tested with virtual pads, also while paused.*
- [x] **Automated input testing**: `tools/virtual_pads.py` (virtual Xbox pads via uinput, scripted or live) and
      `tools/run_headless.sh` (game in headless gamescope, no window on the desktop).

## Week 3 (09.–15.11): polish
Sound list, sources and music direction: `planning/audio-plan.md`.
- [x] Rollback-safe gameplay sound: `MapSounds` reacts to state changes seen by the views, never from inside
      `Simulation.step` (`7260eec`: puck hits, magnet hum, countdown, match end, lobby join/ready).
- [x] Menu sounds (`UiSounds` autoload), licenses in `assets/sounds/LICENSES.md`.
- [ ] The remaining sounds from the audio plan (goal, pulse, polarity switch, magnet on/off, team pick, everyone
      ready, last 10 seconds), then tick off the audio plan.
- [ ] Music: menu/lobby theme and a match loop, licenses + credits.
- [ ] Visual juice where it's cheap: goal and hit effects, screen shake, score/timer animations.
- [ ] Credits screen (assets, music licenses, Godot, GodotSteam).
- [ ] Windows icon with a 256×256 size.

## Week 4 (16.–22.11): tutorial + presentation
- [ ] Controls / how-to-play screen (keyboard + gamepad glyphs, the existing `assets/icons`), reachable from the
      main menu and the lobby. Short hint text in the lobby: join, pick a team, ready up.
- [ ] Tutorial: what magnets, polarity and the pulse do, ideally playable (a short guided practice on the rink)
      rather than only text. Timebox it; the how-to-play screen is the fallback.
- [ ] Store: update screenshots/trailer if the game looks noticeably different now.

## Week 4–5: bots (stretch, cut line)
- [ ] **Decide on Mon 23.11**: if weeks 2–4 are done, timebox simple bots to 3 days, otherwise move them to the
      first post-launch update.
- [ ] Simple scripted bots: chase the puck, pick the polarity that pulls it toward the opponent's goal, pulse when
      close. They read `SimState` and produce `SimInput` like a player, so they also fill empty slots online later.
- [ ] Bots selectable in the lobby (add bot / remove bot), so a single player can try the game.

## Week 5 (23.–29.11): release candidate
- [ ] Feature freeze. Bug fixing only.
- [ ] Test matrix: Windows, Linux, **Steam Deck** (controller-only navigation, text readable at 1280×800),
      keyboard + 1–3 gamepads, hot-plugging a gamepad, alt-tab/fullscreen.
- [ ] **Remote Play Together test** with at least one friend: guests can join the lobby with gamepad and with
      keyboard (guest keyboards may merge into the host's keyboard, check the keyboard split still works).
      *First test 08.11 with the `dev_beta` build (first SteamPipe upload with `tools/steam_upload.sh`): latency
      and feel surprisingly good on good internet, hosting and being the guest felt about the same.
      Two guests at once worked; one guest with bad internet had problems, as expected.
      Still open: guest on keyboard.*
- [ ] Steamworks: depots for Windows + Linux, upload with SteamPipe, set the build live on `dev_beta`,
      test-install it from Steam on a clean machine.
      *Upload script `tools/steam_upload.sh` and notes in `planning/steam-upload.md` (08.11).*
- [ ] **Submit the build for review by ~Mon 30.11** (review can take several business days).

## Week 6 (30.11–08.12): launch
- [ ] Set the build live on default, press Release on the target date.
- [ ] Watch reviews/discussions for the first days; ship a hotfix build if needed.

## Online after 1.0
The code stays in the repo and should keep working, but it gets no focus until after launch.
- **Design for it, don't work on it**: gameplay stays in `Simulation.step` with all changing data in `SimState`
  (no `randf()`, use `state.rng`; nothing from views, the engine or the clock inside the step). Views and sounds
  only react to state changes. Then online stays cheap to bring back.
- `tests/rollback_test.gd` stays in the weekly verification as a determinism check. A failure there isn't a release
  blocker, but note it here, because every unnoticed break makes online more expensive later.
- After launch: an opt-in Steam beta branch with online 1v1 via Steam invites (friends only, no public
  matchmaking), so interested players do the real-network testing. Then: smooth rollback corrections (phase E),
  online UX states (connecting, host left, timed out), desync logs to `user://`, 2v2 online.
- Own the netcode: walk through `rollback_session.gd`, `net_game.gd` and `net_transport.gd` with Claude until
  you can explain the design (prediction, re-sim, time sync, desync recovery).

## Cut from 1.0 (post-launch backlog)
Online play (see above), bots if they miss the cut line (first update), more rinks, more skins, 3v3, replays,
own music/SFX replacing the packs.

## Risk notes
- If "finish the game" (week 2) uncovers more than a week of work, cut polish and the playable tutorial first
  (keep the how-to-play screen), then push the date once more. Don't ship a broken core loop.
- Remote Play Together quality depends on the host's upload; it's a bonus, not a promise of real online play.
- Each week ends with a playable build exported and tested, so the cut line stays visible.

## Verification (every week)
- `~/Applications/Godot/godot --headless --path Magtong -s res://tests/sim_test.gd` passes.
- `.../rollback_test.gd` passes (determinism check, see "Online after 1.0").
- Exported release build launches, F4–F9 do nothing, no online entries in the menu, settings persist after a restart.

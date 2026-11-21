# Magtong: Release Plan (Steam 1.0)

## Context
The Steam release date (app 3044580) was probably left at 30.10.2026, and Steam wants a support ticket to move
it. Steam never launches by itself: the build has to pass review and the release button has to be pressed by hand.
So we move the date instead of crunching to it.
**Target: release Thu 10.12.2026** (moved from 08.12 by hand in Steamworks, 21.11).

**Scope change 01.11: 1.0 is local multiplayer only.** The first Steam playtest (31.10) never got through a round:
both peers stalled forever after a short one-way packet loss (fixed in `c79a55d`, regression test
`test_one_way_loss`). The fix was quick, but the real bottleneck is testing online with real people over Steam, and
that would eat the time needed to finish the game itself. Online comes after launch (see "Online after 1.0").

**Scope change 09.11: online is back in 1.0.** An online test build over Steam with a friend (08./09.11) worked
and felt clearly better than Remote Play Together, where the guest side was noticeably worse after swapping hosts.
So every build now has Host Steam (lobbies, invites) and Host/Join Direct (`NetDebug.online_enabled()` and the
"(online)" presets are gone). Online stays "with friends": Steam invites or direct IP, no public matchmaking.
The open online items are in "Online for 1.0" below.

Agreed scope for 1.0 (01.11, online added 09.11): local multiplayer (keyboard + gamepads), **Steam Remote Play Together** as the way to play
with friends over the internet, audio from licensed/CC0 packs, the existing rink and skins, a tutorial.
**Simple bots only if they fit before the release candidate**, otherwise they're the first post-launch update.
Store page is already live as "Coming soon".

Order of work: **finish the game → polish → tutorial → bots.**

**Names (14.11):** the two abilities are **Flip** (A / Space: flips the polarity of nearby pucks) and **Surge**
(B / L: a short burst of magnet strength, only with a magnet held). Used everywhere: code, UI, tutorial, store.
"Pulse" is gone, it fit both. Each step ends with a playable exported build.

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
- [x] Update the store description and tags: local multiplayer, Remote Play Together. Don't mention online play
      or bots until they ship (only promise what's in the build).
      *08.11: description, tags and system requirements (Windows + Linux) are in. The Linux launch option
      points to `Magtong.x86_64` (checked).*

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
- [x] **Play the full loop locally and list what's broken or missing**: main menu → lobby (join, team pick, ready)
      → countdown → match → goal → overtime → game over → back to lobby / main menu, with 2, 3 and 4 players and
      mixed keyboard/gamepads. Put the list here and fix the blockers.
      *08.11, local and over Remote Play Together: the only finding was that the lobby had no pause menu and no
      way to leave or remove a player. Fixed (`43bd180`): Start/Esc opens a lobby pause menu (Resume, Remove
      Player, Main Menu), and the match now starts when every team player holds both magnets until their red and
      blue bars meet.*
- [x] Pause menu in local matches: resume / back to lobby / main menu.
      *`scenes/pause_menu.gd`: any player opens/closes it with Start / Esc during countdown and play (not after
      the game over, where Start is rematch), any pad navigates. Buttons are released on resume, so the
      confirm press doesn't pulse.*
- [x] Gamepads in menus: A confirms and B goes back on every pad (`ui_accept`/`ui_cancel` had only keys,
      so the game couldn't be started with a pad alone).
- [x] Keyboard/mouse parts that show up as joypads (e.g. a Keychron's media keys) can't join as players.
- [x] **Feel-tuning pass** (rollback-plan phase B open item): speed, accel, magnet force, mass ratio,
      wall bounce/friction. Playtest locally. Keep `tests/sim_test.gd` green after every tuning change.
      *08.11: `wall_bounce` and `body_bounce` 0 → 0.3, feels better (test `test_puck_bounce`). They also apply to
      players, but the fast steering (`accell` 6000) hides it. Split into puck-only values if that changes.
      Good enough for now, revisit after more playtests.*
- [x] Gamepad hot-plugging and disconnects during a match don't break the game.
      *A disconnected pad lets go of everything (no drifting, no stuck magnet); replugged, it gets its device
      id back and continues as the same player. Tested with virtual pads, also while paused.*
- [x] **Automated input testing**: `tools/virtual_pads.py` (virtual Xbox pads via uinput, scripted or live) and
      `tools/run_headless.sh` (game in headless gamescope, no window on the desktop).

## Known bugs
- [x] **Main menu backgrounds stack** (found 09.11): every return to the main menu spawns more background players
      on top of each other. Cause: `MainMenu.switch_to_menu(start_menu)` (`scenes/menu/main_menu.gd`)
      called `spawn_mm_background()` without freeing the old background, and twice when there was none
      (once for `curr_mm_bg == null`, once for `start_menu`); Settings → Back stacked one too.
      *14.11: `spawn_mm_background()` only spawns when no background is running, `hide_all()` frees it and
      clears the reference. Checked in the running game: one background after Settings and back and after two
      trips through the lobby.*
- [x] **Popup doesn't trap focus** (online playtest 15.11): the disconnect popup in the menu is still open while
      focus can move to the menu buttons behind it.
- [x] **No focus after closing a popup** (online playtest 15.11): after the popup closes, no menu control has
      focus and a controller can't navigate anymore. Give focus back to the button that was focused before.
      *15.11: the menu message is modal now (full-screen click blocker, focus stays on its button, focus goes
      back to the button from before when it closes). "Connecting..." / "Creating Steam lobby..." got a Cancel
      button that leaves; a Steam answer arriving after Cancel is dropped. Tested headless with keys and mouse.*
- [x] **Head-on hits on the goal post bounce oddly** (15.11): a puck hitting the corner of the goal post nearly
      head-on bounced in an unexpected direction. The post corners are the only end points that still count as
      contacts (see the corner fix below), so check their normal there (maybe a hit on the post resolves
      against the end point and a wall segment in the same substep). Reproduce in `sim_test.gd` like the
      corner bounce.
      *16.11: a fast puck sank deep into the post corner within one substep (8 px of its 16 px radius at
      2000 px/s), and the normal from there pointed too far sideways: up to 35 degrees off at 2000 px/s, 71 at
      3000. Flat walls don't care, their normal is the same everywhere. Corner contacts now rewind the body
      along its velocity to the first touch and take the normal there (`_end_point_rewind`).
      `test_goal_post_bounce` in `sim_test.gd` (old code: 71.4 degrees off, new: 0.0).*
- [x] **Field zooms out at the first goal and stays there** (17.11): the match camera (zoom 0.75) never applied
      itself, the screen kept the lobby camera's 0.875 until the goal shake moved the camera. The match camera
      is 0.875 now (what every match so far looked like) and forces its update when the match starts.
      Then zoomed out a bit further in the lobby and the match (match 0.8), so the score bar has room.
- [x] **Start-of-round corner bounces look wrong** (online playtest 15.11): a puck coming in at a downward angle
      toward the goal sometimes bounces away from the goal instead. Check the corner segments/normals in the
      custom physics (maybe a corner hit resolved against the wrong segment); reproduce in `sim_test.gd`.
      *15.11: found with a clip: the rounded corners are 16 short segments, and the end points between them
      counted as contacts. Inside the bowl of a corner such an end point gives an almost sideways normal, which
      ate the speed along the wall: a fast puck reversed instead of sliding on toward the goal. End points of
      corners the rink bends around are skipped now (goal posts keep theirs). `test_corner_bounce` in
      `sim_test.gd` (old code: -1.02, new: 0.91 of the speed along the wall kept).*

## Week 3 (09.–15.11): polish
Sound list, sources and music direction: `planning/audio-plan.md`.
- [x] Rollback-safe gameplay sound: `MapSounds` reacts to state changes seen by the views, never from inside
      `Simulation.step` (`7260eec`: puck hits, magnet hum, countdown, match end, lobby join/ready).
- [x] Menu sounds (`UiSounds` autoload), licenses in `assets/sounds/LICENSES.md`.
- [ ] The remaining sounds from the audio plan, then tick off the audio plan.
      *14.11: goal (air horn), flip (hum sweep + clack), strength burst (hum spike), team pick are in; magnet on/off
      clicks dropped (the hum is enough). Open: last 10 seconds,
      start bars, an own wall hit sound, a real match end buzzer.*
  - [ ] **Replace the match end sound** (21.11: "horrible"). High priority of the open sounds.
  - [ ] Replace the third countdown tick (lower priority).
- [x] Music: menu/lobby theme and a match loop, licenses + credits. Then duck it for a moment on a goal (the
      last open part of the goal celebration).
      *21.11: `Music` autoload (`global/music.gd`). Menu and lobby: Kenney's "Cheerful Annoyance" (CC0), it keeps
      playing into the lobby at -5 dB, comes back up when everyone is in a team and swells +4 dB with the start
      bars; entering a match fades it out over 1.5 s, the countdown is quiet, and the DnB match loop (AlesiaDavina,
      Pixabay, 1:00–3:00 of the track, 128 BPM) kicks in hard on "go": the "lock in" moment. Goals duck the music
      -12 dB for ~2 s. Levels from measured LUFS per file (`FILE_LUFS`/`TARGET_LUFS`). Source mp3 in
      `assets/sounds/music/source/` (`.gdignore`, not exported). Music analysis tool: `~/Applications/essentia/analyze`.*
  - [ ] Game over screen: match music quieter (back up on rematch).
  - [ ] Content ID check for the match track before streamers/the trailer use it.
  - [x] Credits screen entry: "Music by AlesiaDavina from Pixabay", Kenney.
- [x] **Goal celebration** (like Rocket League, the climax of every round, worth more than "cheap juice"):
      today a goal resets the field and starts the countdown in the same tick, so there's no moment at all.
  - [x] A `GOAL` phase in the simulation (~2 s) between the goal and the reset. The scoring puck leaves play,
        everything else keeps moving. An overtime goal gets the same celebration, then game over.
  - [x] **Goal explosion that pushes the players**: a shockwave from the scoring puck that knocks nearby players
        (and pucks) away, falling off with distance. In the simulation, so it's the same on every machine.
  - ~~**Slow motion**~~ (dropped 15.11: players have no control during the celebration anyway, and the slowed
        knockback looked wrong, like bodies speeding up in the corners) for the first ~0.8 s of the `GOAL` phase, easing back to normal speed: the simulation
        steps with a smaller time step (e.g. 25%), stored in `SimState`. **Never `Engine.time_scale`**: that
        changes the tick rate on one machine and breaks the online time sync. Ticks stay at 60/s.
  - [x] Views only: explosion effect in the scoring team's color, screen shake, short flash, "GOAL!" text,
        score number pop, the air horn, music ducking for a moment.
        *15.11: all in except music ducking (no music yet). `GoalEffects` (explosion ring in the team color,
        sparks, flash, shake, guarded against rollback replays like the sounds), "GOAL!" in the countdown label
        (driven by the phase ticks), score pop, the scoring puck is hidden. Players drift without control during
        the celebration so the knockback stays visible. Tune the numbers after playing it.*
  - [x] Tests: the `GOAL` phase and slow motion in `sim_test.gd`, `rollback_test.gd` stays green.
- [ ] Other visual juice where it's cheap: hit effects, score/timer animations.
  - [ ] **Player outer ring glows in the magnet color** (21.11): the black outer ring of the player lights up red/blue
        for the magnet force in use, another readable indicator of what a player is doing. Views only.
- [x] **Clearer Flip and Surge visuals** (playtest 15.11): both are hard to see, especially for someone watching
      a stream. Needs a more direct, obvious effect (e.g. a ring/shockwave for Flip on the flipped pucks, a
      strong glow/size pulse on the player for Surge). Views only.
      *15.11: flipped pucks pop with a white ring (liked); the player's polarity color switches in 0.05 s
      instead of fading 0.2 s. Big code-drawn rings for Flip/Surge were tried and dropped (too big and
      intrusive, moving with the player), and so was a strong distortion for both (unreadable fast, and the
      two looked the same). Now distinct: Flip zaps lightning lines to the flipped pucks (`flip_zap.gd`),
      Surge keeps a moderate distortion ripple plus a +10 % sprite punch (`player_visuals.gd` constants).*
      *Flip zap: good for now. Surge maybe still too much in a real match: check at the next playtest
      (`SURGE_RIPPLE_FORCE`, `SURGE_PUNCH`).*
  - [x] **Surge and Flip look, next pass** (18.11): first inspired by the skill animation of Diana in League of
        Legends (https://www.youtube.com/watch?v=QHoX53V4T2s).
        *18.11: the ripple stays where the Surge happened (own top level copy of the shader sprite), the ring is
        tinted red/blue (`SURGE_TINT`, `SURGE_PLUS_COLOR`/`SURGE_MINUS_COLOR`, blended, not added: added red on
        the green rink turns yellow) and wobbles slightly (`SURGE_WIGGLE`). Tried and dropped: round white arcs
        on the ring, a full-screen and a local color invert (hard flash and faded).*
        *20.11, new direction: Surge is global, so it stays a soft, fuzzy ripple; Flip has a hard range, so it
        gets a crisp edge. Surge: longer (`SURGE_RIPPLE_TIME` 0.45) and dissolves (the ring widens and its tint
        smears while force and tint ease out: `RIPPLE_END_THICKNESS`, `RIPPLE_END_BAND`). Dropped: burst lines
        and swirling crescents (`sickle.png` kept in `assets/textures/effects/`, unused). Flip: an electric
        ring at the exact flip range (`flip_ring.gd`): two see-through jagged loops in the plus/minus zap colors
        over thin white cores, re-jagged every few frames (crackle), expands visibly (`EXPAND_TIME`), holds, fades in place;
        shown on every Flip, also when no puck was in range. A crisp white shader ring with fill and glow was
        tried first: too much halo, and the snap-out was too fast to see. Flip also punches the player sprite
        (`FLIP_PUNCH`, a bit stronger than `SURGE_PUNCH`). The plus/minus burst particles were removed (they
        cluttered the ring). Values tuned by hand in-game; done for now, recheck at the next playtest.*
- [x] **Team colors that aren't red and blue**: red/blue is also the magnet polarity (plus/minus), and playtesters
      mixed them up. Pick two team colors that can't be confused with the magnet colors (also check color
      blindness). Open decision: fixed team colors or adjustable (per team in the lobby, or a settings option);
      decide later. Touches the lobby team areas, skins/outlines, HUD score, "Team Red/Blue Wins!" text.
      *16.11: fixed colors, **orange** (team 1, left, #FF8A00) and **cyan** (team 2, right, #00C8DC), chosen from
      mockups with color blindness simulation. Colors and names in `global/teams.gd` (goal explosion, GOAL!
      text, "Team Orange/Cyan Wins!"); goals and lobby areas in `map_default.tscn`, score bar in
      `match_clock.svg`. The background fog keeps its own blue/red gradient. Caveat from the simulation:
      for red-green color blindness orange is close to the red plus magnet, watch for that in playtests.*
- [x] **Magnet controls swapped** (16.11): plus on the right (RT / RB, keyboard K), minus on the left (LT / LB,
      keyboard J), more intuitive. The lobby start bars follow: minus fills from the left, plus from the right.
      Update the how-to-play screen and store texts to match.
- [x] Credits screen (assets, music licenses, Godot, GodotSteam).
      *21.11: `Credits` window (`scenes/menu/credits.gd`, main menu above Quit): developer, music, sound effects,
      icons (game-icons.net is CC BY 3.0, so Delapouite is named), Godot and GodotSteam, then the license texts
      (Godot's text and third-party list from `Engine`, GodotSteam's MIT). Up / down scroll.*
- [x] **Settings from the pause menu** (15.11): change sound volumes (and ideally all settings) during a match or
      in the lobby, not only from the main menu. Probably reuse the whole settings menu. Online the pause menu
      doesn't pause, so the settings must work while the match keeps running.
      *16.11: the settings panel is its own scene (`scenes/menu/settings_menu.tscn`), used by the main menu and
      the pause menu (Settings under Resume, lobby and match). B / Esc / Start or its X go back to the menu.
      Tested headless in the lobby and the main menu; not yet in an online match.*
- [x] Windows icon with a 256×256 size.
      *16.11: `assets/icons/magtong.ico` rebuilt from `magtong_256.png` (256/128/64/48/32/16), the exe embeds all six.*

## Week 4 (16.–22.11): tutorial + presentation
- [x] Controls / how-to-play screen (keyboard + gamepad glyphs, the existing `assets/icons`), reachable from the
      main menu and the lobby. Short hint text in the lobby: join, pick a team, ready up, hold both magnets to
      start, Start/Esc for the menu.
      *21.11: `HowToPlay` panel (`scenes/menu/how_to_play.gd`, built in code, looks like the settings): three rule
      lines (goal, + / − poles attract/repel, Flip and Surge) and a controls table with the gamepad and keyboard
      icons. "How to Play" button above Settings in the main menu and under Settings in the pause menu (lobby and
      match); Back / B / Esc close it. Lobby hint at the top (`GameLobby._update_hint`): join → pick a team →
      hold both magnets, plus "Start / Esc: menu and How to Play". Button names are text, no glyph images yet.*
- [ ] Tutorial: what magnets, polarity, Flip and Surge do, ideally playable (a short guided practice on the rink)
      rather than only text. Timebox it; the how-to-play screen is the fallback.
- [ ] Store: update screenshots/trailer if the game looks noticeably different now.

## Week 4–5: bots (stretch, cut line)
- [ ] **Decide on Mon 23.11**: if weeks 2–4 are done, timebox simple bots to 3 days, otherwise move them to the
      first post-launch update.
- [ ] Simple scripted bots: chase the puck, pick the polarity that pulls it toward the opponent's goal, flip when
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
- [ ] **Re-check the Steamworks AI disclosure before submitting** (currently answered "no"). The question
      ("Content Survey" → Generative AI): *"Does this game use generative artificial intelligence to generate
      content for the game, either pre-rendered or live-generated? This includes the game itself, the store
      page, and any Steam community assets or marketing materials."* Valve says AI tools for efficiency aren't
      the focus, it's about content that ships and players consume (artwork, sound, narrative, localization).
      What Claude made that ships: game code, including effects drawn in code (goal explosion, sparks, ring:
      shapes from code, no generated images), and player-facing text (menu/error messages, "GOAL!", hints).
      Not AI: sprites/art, sound effects (Kenney, Pixabay), music. Gray area is the code-drawn effects and the
      UI text; read Valve's current guidance (the expanded section of the survey) and decide. If unsure, "yes"
      with an exact description ("code and some UI text written with an AI coding assistant; all art, sound
      and music are made by people") is the safe answer, a wrong "no" is the risk.
- [ ] **Submit the build for review by ~Mon 30.11** (review can take several business days).

## Week 6 (30.11–10.12): launch
- [ ] Set the build live on default, press Release on the target date.
- [ ] Watch reviews/discussions for the first days; ship a hotfix build if needed.

## Online for 1.0
- [x] **Online menu**: the pause menu is local only (pausing can't work online), so online there's no way to
      leave a lobby or match from inside the game. Needs a non-pausing menu: Resume, Leave (client), Back to
      Lobby / Main Menu (host).
      *09.11: the pause menu now also works online, titled "Menu", without pausing; this machine's players send
      empty input while it's open. Host: Remove Player (lobby) / Back to Lobby (match) + Main Menu; client:
      Leave. A host who leaves on purpose now shows "The host left" instead of "Lost the connection". Tested
      with two local instances over direct connect (client leaves lobby and match).*
- [ ] Online UX states: connecting, host left, timed out, can't connect (direct connect without port forwarding).
- [ ] **Can't rejoin a lobby you left** (Steam playtest 15.11): P1 hosts, P2 joins, P1 leaves (P2 now hosts?),
      P1 joins P2 through Steam → P1 stays on "Connecting..." forever, also after restarting the game.
      Probably stale lobby/peer state on one side; needs a timeout with an error message either way.
      *15.11: cause not confirmed (every leave path calls `leaveLobby`). Made robust instead: the host writes
      its Steam id into the lobby data (`host`), a joiner whose lobby owner isn't that host gets "This game has
      already ended"; everyone leaves when the host leaves the Steam lobby (`lobby_chat_update`); clients give
      up after 10 s ("Could not connect to the host (timed out)", tested with direct connect). Steam lobby events
      and menu messages now go to the F12 log. Retest with two Steam accounts.*
- [ ] **Crash while connecting** (Steam playtest 15.11): while P1 is stuck on "Connecting...", P2 closes the game
      → P1's game crashes without any message. Must fall back to the menu with "Lost the connection"/"Can't
      connect".
      *15.11: probably a crash inside GodotSteam's `SteamMultiplayerPeer` when the lobby owner leaves while it
      connects. Can't fix that code, but the fixes above keep us out of that state (no joining an unhosted
      lobby, 10 s connect timeout). Retest.*
- [ ] More online tests: 2v2 (two machines with two local players each), a weaker connection, host on Windows and
      on Linux.
- [ ] Store page: mention online play with friends (Steam invites), add the online multiplayer features/tags.
- *First real online playtest over Steam (15.11, both of us hosted a few matches): very stable, no
  disconnects, barely any rollbacks or visible lag. Bugs found are listed above and under Known bugs.*
- `tests/rollback_test.gd` is now a release blocker, not just a determinism check.

Still true from the "online after launch" days:
- **Design for it, don't work on it**: gameplay stays in `Simulation.step` with all changing data in `SimState`
  (no `randf()`, use `state.rng`; nothing from views, the engine or the clock inside the step). Views and sounds
  only react to state changes. Then online stays cheap to bring back.
- After launch: smooth rollback corrections (phase E), desync logs to `user://`, maybe public matchmaking.
- Own the netcode: walk through `rollback_session.gd`, `net_game.gd` and `net_transport.gd` with Claude until
  you can explain the design (prediction, re-sim, time sync, desync recovery).

## Cut from 1.0 (post-launch backlog)
Public matchmaking, bots if they miss the cut line (first update), more rinks, more skins, 3v3, replays,
own music/SFX replacing the packs.

## Risk notes
- If "finish the game" (week 2) uncovers more than a week of work, cut polish and the playable tutorial first
  (keep the how-to-play screen), then push the date once more. Don't ship a broken core loop.
- Remote Play Together quality depends on the host's upload; it's a bonus, not a promise of real online play.
- Each week ends with a playable build exported and tested, so the cut line stays visible.

## Verification (every week)
- `~/Applications/Godot/godot --headless --path Magtong -s res://tests/sim_test.gd` passes.
- `.../rollback_test.gd` passes (determinism check, see "Online after 1.0").
- Exported release build launches, F4–F9 do nothing, Host Steam and direct connect work, settings persist after a restart.

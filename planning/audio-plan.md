# Magtong: Audio Plan (Week 2)

Shopping list for the 1.0 sounds and music. Tick items off when a file is picked and in `Magtong/assets/sounds/`.
Every file gets a line in `assets/sounds/LICENSES.md` (source, author, license).

General rules for SFX:
- Short, punchy, dry (no reverb tail), so many sounds at once stay clear.
- Pick 3–5 variants for anything frequent, or one good file plus `AudioStreamRandomizer` (small random
  pitch/volume) so it doesn't sound repetitive.
- Gameplay sounds go on the SFX bus, music on the Music bus.

Kenney packs: `~/Applications/kenney-asset-launcher/Audio/` (all CC0, no credit required, but credit Kenney anyway).

## Gameplay
- [ ] **Puck hits player**: a short plastic "thock" like air hockey. 3–4 variants, louder and brighter at
      higher impact speed (pick a soft and a hard set, choose by speed).
- [ ] **Puck hits wall**: sharper, harder "clack" with a bit of rattle than the player hit.
- [ ] **Magnet on**: short electric charge-up "zzhm".
- [ ] **Magnet loop**: quiet, low hum while the magnet is held. Plus and minus at slightly different pitches.
      Must loop seamlessly.
- [ ] **Magnet off**: quick power-down "zip".
- [ ] **Polarity switch** (`polarity_changed`): a click plus a small zap, like a relay switching.
- [ ] **Pulse** (`pulse_emitted`): bassy "whoomp" shockwave with some electric crackle on top.
- [ ] **Goal**: big synth stinger or horn, the loudest sound in the game.
- [ ] **Countdown**: three short beeps, then a higher, longer "go".
- [ ] **Last 10 seconds**: soft tick each second (or reuse the countdown beep, quieter).
- [ ] **Match end**: arena-style buzzer.

## Lobby
- [ ] **Player joins**: a soft "pop".
- [ ] **Team pick**: a swoosh or slide.
- [ ] **Ready**: a rising chime. **Unready**: the same chime falling (or pitched down).
- [ ] **Everyone ready**: a short fanfare / confirmation jingle.

## Menu
- [ ] **Move focus**: a soft tick.
- [ ] **Confirm**: a click with a bit more weight.
- [ ] **Back**: a lower, softer click.
- [ ] **Slider tick**: plays at the new volume while dragging the SFX slider (doubles as a volume preview).
- [ ] **Error / not allowed** (e.g. can't start yet): a short buzz.

## Online
- [ ] **Connection lost**: a warning blip (pairs with the connection icon).
- [ ] **Connection back**: the same blip rising.

## Kenney candidates
UI (`Interface Sounds/Audio`, `UI Audio/Audio`):
- Move focus: `Interface Sounds` `tick_*`, `select_*` or `UI Audio` `rollover*`
- Confirm: `Interface Sounds` `confirmation_*` or `click_*`
- Back: `Interface Sounds` `back_*`, `close_*`
- Slider tick: `Interface Sounds` `scroll_*`, `tick_*` or `UI Audio` `switch*`
- Error: `Interface Sounds` `error_*`
- Lobby join: `Interface Sounds` `pluck_*`, `drop_*`, `open_*`; ready/unready: `maximize_*` / `minimize_*`
- Connection lost/back: `Interface Sounds` `glitch_*`; `Digital Audio` `lowDown` / `highUp`

Worth a listen for gameplay too (or as placeholders until your own sounds exist):
- Countdown: `Digital Audio` `tone*`, `twoTone*`, `threeTone*`
- Magnet on/off: `Digital Audio` `phaserUp*` / `phaserDown*`; polarity switch: `Digital Audio` `zap*`
- Magnet loop: `Sci-Fi Sounds` `forceField_*`, `engineCircular_*`
- Pulse: `Sci-Fi Sounds` `lowFrequency_explosion_*`, `forceField_*`
- Puck hits: `Impact Sounds` `impactPlate_light_*`, `impactGeneric_light_*`, `impactPlank_medium_*`
- Goal / win stingers: `Music Jingles/Audio (Hit)`; announcer lines ("ready", "go", "winner", "tie"):
  `Synth Voice 1`, `Voiceover Pack Fighter`

## Other sources
- freesound.org with the license filter set to CC0 (CC-BY is fine too, but needs a credit).
- Sonniss GDC bundles: free, royalty-free, high quality; good for impacts and electric sounds.
- jsfxr / Bfxr / ChipTone: make your own retro sounds with sliders (counts as your own assets).
- Your own recordings: plastic objects on a table for the puck hits (phone recording + a bit of EQ).

## Music
Direction: electro swing as the brand sound (matches the trailer), with matches kept tighter and adaptive so
the same track doesn't wear out.
- [ ] **Menu/lobby theme**: electro swing, the main "this is Magtong" track. Loops cleanly.
- [ ] **Match loop as stems** (drums, bass, melody, high-energy layer) in the same style. Play them with
      `AudioStreamSynchronized` and fade layers in by game state: base at kickoff, full in the last 30 s or on a
      tied score. Only driven by score/clock from the visuals, so rollback can't affect it.
- [ ] **Stingers**: kickoff, goal, win, loss/draw (short, 1–3 s).
- [ ] Optional: a second match loop, shuffled between matches.
- [ ] **Content ID check**: make sure no track (including the trailer track) is registered with YouTube
      Content ID, so streamers don't get claims.

Ways to get it: make it yourself (Bosca Ceoil, BeepBox, LMMS), buy an indie pack with stems (itch.io), or
commission a menu theme plus a layered match loop (r/gameDevClassifieds, itch.io composers).

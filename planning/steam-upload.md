# Steam: builds, branches and uploads

Notes for getting back into Steam uploads (written 08.11.2026, setup from Dec 2025).

## What exists in Steamworks
- **App 3044580 "Magtong"**: the game. SteamPipe settings: Steamworks → the app → *Edit Steamworks Settings*
  → tab **SteamPipe** → *Depots* / *Builds*. (The dashboard doesn't link there directly, that's why it's easy to miss.)
  - Depot **3044581** = Windows, depot **3044582** = Linux. Each depot has its OS set, so a Linux install only
    downloads 3044582.
  - The store package (own package ID, not the app ID) contains both depots.
- **Branches** of app 3044580:
  - `default`: what buyers get. Before release only you (and key holders) see it. A build from 08.02.2026
    (build 21271200) is live there. Set live on default **only by hand** in the web UI, on release day.
  - **`dev_beta`** (password protected): for testing installed builds. Had build 21277410 (Dec 2025).
    In the Steam client: Magtong → Properties → *Betas* → enter the password / pick `dev_beta`.
- **App 4273980 "Magtong Playtest"**: a Steam Playtest (separate free app, players click "Request Access" on the
  store page). Its own depot 4273981. Tried once on 20.12.2025, the commit failed. **Not needed for 1.0**,
  leave it alone. Online beta later goes to a beta branch of the main app instead.

## Local SteamPipe setup
- `~/Applications/SteamSDK/tools/ContentBuilder`: steamcmd is `builder_linux/steamcmd.sh`, logs go to `output/`.
- The old hand-written scripts are still in `ContentBuilder/scripts/` (`magtong_3044580.vdf`, `magtong_playtest_*`)
  with the content folders as symlinks into `Magtong/build/`. They set live on "AlphaTest", which doesn't exist,
  which is why the Dec 2025 commits failed ("ERROR! Failed to commit build ... : Failure", the depots themselves
  uploaded fine). **Don't use them any more**, use `tools/steam_upload.sh`.
- `tools/steam_upload.sh` writes the app build script itself (`output/magtong_upload_3044580.vdf`), with the
  version, commit and export time as the build description, and maps `Magtong/build/windows` and `build/linux`
  straight to the two depots. It refuses to upload when a file is missing or a debug export is in `build/`.

## How to test (don't upload for every test)
| What | How |
|---|---|
| Gameplay, menus, bugs (daily) | Editor, or a local export. With the Steam client running, a local build already has Steam (overlay, invites), because it initializes with the app ID. |
| Real release build | Local **release** export (see below), start `Magtong/build/linux/Magtong.x86_64` directly. |
| Installed from Steam (weekly, RC, Steam Deck, Remote Play Together) | Upload to `dev_beta`, switch to it in the client, test. |
| Steam Deck without uploading | Valve's *SteamOS Devkit Client* sends a local build over the network. |

## Upload, step by step
1. **Release export** of both presets. Clear the folders first, so no files of an old export stay behind:
   in the editor: Project → Export → preset → *Export Project* → **"Export With Debug" off**. Or headless
   (no Godot MCP session running, otherwise the bridge autoload gets baked in):
   ```
   cd Magtong && rm -rf build/windows build/linux && mkdir -p build/windows build/linux
   ~/Applications/Godot/godot --headless --path . --export-release "Linux" build/linux/Magtong.x86_64
   ~/Applications/Godot/godot --headless --path . --export-release "Windows Desktop" build/windows/Magtong.exe
   ```
   A release export has `*template_release*` GodotSteam libs and no `Magtong.sh` / `Magtong.console.exe`.
2. **Dry run** in a normal terminal (steamcmd asks for the password and Steam Guard, that needs a real terminal):
   `tools/steam_upload.sh YOUR_STEAM_USERNAME --preview`
   Check `output/depot_build_3044581.log` and `..._3044582.log`: 4 files each, release libs.
3. **Upload**: `tools/steam_upload.sh YOUR_STEAM_USERNAME` (sets it live on `dev_beta`).
   The log should end with a success line instead of "Failed to commit build".
4. **Check in Steamworks** → SteamPipe → Builds: the new build with its description is live on `dev_beta`.
5. **Install and test**: Steam client → Magtong → Properties → Betas → `dev_beta`, let it update, start it.
   In a release build F4–F9 do nothing and there are no online entries in the menu.

## Online play
Since 09.11 online play is in every build: Host Steam (Steam lobbies, invites, `+connect_lobby`) and Host Direct /
Join Direct (ENet; LAN, or over the internet with UDP port 24680 forwarded on the host's router). One export
preset per platform, nothing to switch. (A short-lived pair of "(online)" presets with a feature tag was removed
again.) `tools/steam_upload.sh --note TEXT` adds a note to the build description.

## Pitfalls
- **Launch options** (Steamworks → *Installation* → *General Installation*): the old Linux debug build had a
  `Magtong.sh` wrapper, the release build doesn't. The Linux launch option must point to `Magtong.x86_64`, the
  Windows one to `Magtong.exe`. Check this before the first release-build upload.
- After changing settings in Steamworks (launch options, depots, branches) they only apply after
  *Publish* on the Publish tab.
- Setting live on `default` can't be done from a script; it's a deliberate step in the web UI.
- `Magtong/build/` is ignored by git; `build/old_windows_debug_2026-11-01/` is the previous debug export, can go.

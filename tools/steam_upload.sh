#!/usr/bin/env bash
# Upload the exported release builds in Magtong/build/{windows,linux} to Steam (app 3044580) with SteamPipe.
# Notes and the whole workflow: planning/steam-upload.md
#
# Usage: tools/steam_upload.sh STEAM_USERNAME [--preview] [--branch NAME] [--note TEXT]
#   --preview      dry run: steamcmd lists what would be uploaded, nothing leaves the machine
#   --branch NAME  beta branch to set the build live on (default dev_beta). Never the default branch,
#                  Steam doesn't allow that from a script; release day is done by hand in Steamworks.
#   --note TEXT    added to the build description, e.g. --note online for an export of the "(online)" presets
# steamcmd asks for the password and Steam Guard itself; nothing secret is passed or stored here.
set -euo pipefail

APP_ID=3044580
DEPOT_WINDOWS=3044581
DEPOT_LINUX=3044582
CONTENT_BUILDER="$HOME/Applications/SteamSDK/tools/ContentBuilder"
STEAMCMD="$CONTENT_BUILDER/builder_linux/steamcmd.sh"
OUTPUT="$CONTENT_BUILDER/output"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$REPO/Magtong/build"

user=""
preview=0
branch="dev_beta"
note=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--preview) preview=1 ;;
		--branch) branch="$2"; shift ;;
		--note) note="$2"; shift ;;
		-*) echo "unknown option $1" >&2; exit 2 ;;
		*) user="$1" ;;
	esac
	shift
done
[[ -n "$user" ]] || { sed -n '2,10p' "$0"; exit 2; }
[[ "$branch" != "default" && "$branch" != "public" ]] || { echo "won't set live on the default branch, do that in Steamworks" >&2; exit 2; }

# --- checks: refuse to upload something broken or a debug build ---
fail=0
for f in windows/Magtong.exe windows/Magtong.pck windows/steam_api64.dll \
		linux/Magtong.x86_64 linux/Magtong.pck linux/libsteam_api.so; do
	[[ -f "$BUILD/$f" ]] || { echo "missing: build/$f (export first)" >&2; fail=1; }
done
if find "$BUILD/windows" "$BUILD/linux" -name '*template_debug*' 2>/dev/null | grep -q .; then
	echo "debug export in build/: re-export with 'Export With Debug' off (and clear the folder first)" >&2
	fail=1
fi
[[ $fail -eq 0 ]] || exit 1

version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$REPO/Magtong/project.godot")"
commit="$(git -C "$REPO" rev-parse --short HEAD)"
dirty=""
git -C "$REPO" diff --quiet HEAD -- Magtong || dirty="+dirty"
built="$(date -r "$BUILD/linux/Magtong.pck" '+%Y-%m-%d %H:%M')"
desc="Magtong $version ($commit$dirty, exported $built)${note:+ [$note]}"

newest_commit=$(git -C "$REPO" log -1 --format=%ct)
if [[ $(date -r "$BUILD/linux/Magtong.pck" +%s) -lt $newest_commit ]]; then
	echo "warning: the export is older than the last commit, is it the build you want?" >&2
fi

# --- app build script, generated so the description always names the commit ---
mkdir -p "$OUTPUT"
vdf="$OUTPUT/magtong_upload_$APP_ID.vdf"
cat > "$vdf" <<EOF
"AppBuild"
{
	"AppID" "$APP_ID"
	"Desc" "$desc"
	"Preview" "$preview"
	"SetLive" "$branch"
	"ContentRoot" "$BUILD/"
	"BuildOutput" "$OUTPUT/"
	"Depots"
	{
		"$DEPOT_WINDOWS"
		{
			"FileMapping" { "LocalPath" "windows/*" "DepotPath" "." "Recursive" "1" }
		}
		"$DEPOT_LINUX"
		{
			"FileMapping" { "LocalPath" "linux/*" "DepotPath" "." "Recursive" "1" }
		}
	}
}
EOF

echo "App $APP_ID, branch $branch, $([[ $preview -eq 1 ]] && echo 'PREVIEW (nothing is uploaded)' || echo 'REAL UPLOAD')"
echo "Desc: $desc"
echo "Script: $vdf"
read -r -p "Continue? [y/N] " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || exit 0

"$STEAMCMD" +login "$user" +run_app_build "$vdf" +quit
echo
echo "Logs: $OUTPUT/app_build_$APP_ID.log, depot_build_$DEPOT_WINDOWS.log, depot_build_$DEPOT_LINUX.log"

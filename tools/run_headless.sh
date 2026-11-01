#!/usr/bin/env bash
# Runs Magtong in a headless gamescope session: no window on the desktop, no focus stealing, real GPU.
# Gamepads (real or tools/virtual_pads.py) still work, keyboard and mouse from the desktop don't reach it.
#
# Usage: tools/run_headless.sh [--wait-for-mcp] [-- extra godot args]
#   --wait-for-mcp  wait until the godot-runtime MCP server injected its bridge autoload (attach_project)
#                   before starting, so the bridge is loaded at startup
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Magtong"
GODOT="${GODOT:-$HOME/Applications/Godot/godot}"

if [[ "${1:-}" == "--wait-for-mcp" ]]; then
	shift
	for _ in $(seq 1 150); do
		grep -q McpBridge "$PROJECT/project.godot" && break
		sleep 0.2
	done
fi
[[ "${1:-}" == "--" ]] && shift

exec gamescope --backend headless -W 1280 -H 720 -- "$GODOT" --path "$PROJECT" "$@"

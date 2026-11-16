#!/bin/sh
# Builds the ZIP to upload to OpenAI's plugin portal (https://platform.openai.com/plugins)
# from what is committed in HEAD:
#   - the plugin folder, with plugin.json, skills, assets, README.md and LICENSE at the top
#   - mcp.json with the remote MCP server and its sign-in settings (OAuth, dynamic client
#     registration). The repository's mcp.json has no sign-in settings because Codex
#     rejects them ("unknown field `extensions`"); the portal reads them
#   - no .claude-plugin/ or .mcp.json: those are for Claude
#
# Usage: scripts/build-openai-zip.sh [output directory]   (default: dist/)
set -eu

ROOT=$(git rev-parse --show-toplevel)
OUT=${1:-"$ROOT/dist"}
VERSION=$(git -C "$ROOT" show HEAD:plugins/numix/plugin.json | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git -C "$ROOT" archive HEAD plugins/numix LICENSE | tar -x -C "$WORK"
PLUGIN="$WORK/plugins/numix"
mv "$WORK/LICENSE" "$PLUGIN/LICENSE"
rm -rf "$PLUGIN/.claude-plugin" "$PLUGIN/.mcp.json"

cat > "$PLUGIN/mcp.json" <<'EOF'
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {
    "numix": {
      "type": "streamable-http",
      "url": "https://mcp.numix.app/mcp",
      "extensions": {
        "com.openai": {
          "auth": {
            "type": "oauth",
            "client": {
              "mode": "dcr"
            },
            "registrationUrl": "https://mcp.numix.app/register"
          }
        }
      }
    }
  }
}
EOF

mkdir -p "$OUT"
ZIP="$OUT/numix-$VERSION.zip"
rm -f "$ZIP"
(cd "$PLUGIN" && zip -qrX "$ZIP" .)
echo "$ZIP"
unzip -l "$ZIP" | tail -n +4 | sed '$d' | sed '$d' | awk '{print "  " $4}'

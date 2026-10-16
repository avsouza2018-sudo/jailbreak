#!/bin/sh
# Replicate this machine's dsh web setup on another box, talking to the same
# llama.cpp server. Run on the target machine.
#
#   AI_HOST=192.168.0.4 ./setup-dsh.sh
#
# What it writes:
#   $HOME/.dsh/.env                  -> API key env var
#   $HOME/.dsh/cordis.patch.yml      -> provider + default model + compaction
#   $HOME/.dsh/profiles/web/         -> profile root (empty list, per dsh convention)
#
# Then:  dsh --profile web
#
# Node must be >= 22.3: the profile uses `process.getBuiltinModule()` in !!js
# expressions. This box runs node v20.20.2 but dsh is launched from node24 —
# check `node --version` on the target before launching.

set -e

AI_HOST="${AI_HOST:-192.168.0.4}"
AI_PORT="${AI_PORT:-8080}"
MODEL_ID="${MODEL_ID:-qwen3.8-flash-next-iq2_xs}"
PROFILE="${PROFILE:-web}"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"

NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -z "$NODE_MAJOR" ]; then
    echo "node not found — install node >= 22.3 before launching dsh."
elif [ "$NODE_MAJOR" -lt 22 ]; then
    echo "warning: node $(node --version) is older than 22.3; !!js profile entries need process.getBuiltinModule()"
fi

mkdir -p "$DSH_HOME" "$DSH_HOME/profiles/$PROFILE"

# --- credentials env ---
cat > "$DSH_HOME/.env" <<EOF
LLAMACPP_API_KEY=sk-no-key-required
EOF

# --- provider patch ---
cat > "$DSH_HOME/cordis.patch.yml" <<EOF
# Home-level patch: route dsh to the LAN llama.cpp server ($AI_HOST:$AI_PORT).
# llama.cpp serves whatever model is loaded regardless of the id below;
# check http://$AI_HOST:$AI_PORT/v1/models if the label looks wrong.
- id: llm-pi-ai
  config:
    providers:
      llamacpp:
        displayName: llama.cpp ($AI_HOST)
        api: openai-completions
        apiKeyEnv: LLAMACPP_API_KEY
        baseURL: http://$AI_HOST:$AI_PORT/v1
        compat:
          thinkingFormat: qwen-chat-template
          maxTokensField: max_tokens
        models:
          - id: $MODEL_ID
            name: Qwen3.8 Next Flash (local)
            contextWindow: 200000
            maxTokens: 16384
            input: [text, image]
            reasoningEfforts:
              off:
              high: high

- id: agent-default-model
  config:
    provider: llamacpp
    model: $MODEL_ID

# Default headroomTokens (65536) is sized for 1M-window models. With a 200K
# window + 16K output it puts the auto-compact trigger at ~18K tokens and makes
# it thrash. 2K headroom keeps the trigger sane.
- id: compaction-basic
  config:
    headroomTokens: 2048
    thresholdRatio: 0.8
    maxTokens: 8192
    auto: false
EOF

# --- profile root ---
# An empty entry list. The tree is composed as patches: bundles from
# package.json, then cordis.patch.yml, then --patch overlays.
cat > "$DSH_HOME/profiles/$PROFILE/cordis.yml" <<'EOF'
[]
EOF

# --- profile bundles ---
# The web profile needs the client bundles; pnpm installs them on launch.
cat > "$DSH_HOME/profiles/$PROFILE/package.json" <<'EOF'
{
  "name": "dsh-profile-web",
  "private": true,
  "dsh": {
    "profile": {
      "bundles": [
        "@deepseek-ai/dsh-base",
        "@deepseek-ai/dsh-web-app",
        "@deepseek-ai/dsh-experimental-schedule-bundle",
        "@deepseek-ai/dsh-experimental-voice-input-bundle",
        "@xmanrui/dsh-im",
        "@deepseek-ai/dsh-experimental-agent-team-profile"
      ]
    }
  }
}
EOF

cat > "$DSH_HOME/profiles/$PROFILE/pnpm-workspace.yaml" <<'EOF'
packages:
  - .

nodeLinker: hoisted
autoInstallPeers: false
EOF

# --- UI defaults ---
cat > "$DSH_HOME/profiles/$PROFILE/cordis.patch.yml" <<'EOF'
- id: ui-settings-general
  name: "@deepseek-ai/dsh-client-ui-settings-general"
  config:
    welcomeNoticeVersion: 2026-09-28.1
- id: ui-theme
  name: "@deepseek-ai/dsh-client-ui-theme"
  config:
    preference: dark
EOF

echo
echo "Installed:"
echo "  $DSH_HOME/.env"
echo "  $DSH_HOME/cordis.patch.yml"
echo "  $DSH_HOME/profiles/$PROFILE/"
echo
echo "Install dsh if missing:  npm i -g @deepseek-ai/dsh"
echo "Launch:                  dsh --profile $PROFILE"
echo
echo "The pub MCP server is not replicated — it points at a path on this box."
echo "If you want the same room, copy /home/oem/personal/agent-pub and add the"
echo "mcp-pub insert entry to the patch, with PUB_LLM_URL=http://$AI_HOST:$AI_PORT/v1."

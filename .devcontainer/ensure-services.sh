#!/usr/bin/env bash

set -e

if pgrep -f '[c]loudflared tunnel --url http://localhost:20128' >/dev/null \
  && (echo >/dev/tcp/127.0.0.1/20128) >/dev/null 2>&1; then
  grep -E '^(CLOUDFLARE_TUNNEL_URL=|\[startup\])' /tmp/codespace-startup.log 2>/dev/null || true
  exit 0
fi

exec bash .devcontainer/startup.sh
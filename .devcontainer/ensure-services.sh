#!/usr/bin/env bash

set -e

if pgrep -f '[c]loudflared tunnel run --token' >/dev/null \
  && (echo >/dev/tcp/127.0.0.1/20128) >/dev/null 2>&1; then
  if grep -Eq '^sk-[A-Za-z0-9_-]+$' /tmp/codespace-startup.log 2>/dev/null; then
    grep -E '^\[startup\]|^sk-' /tmp/codespace-startup.log 2>/dev/null || true
    exit 0
  fi
fi

exec bash .devcontainer/startup.sh
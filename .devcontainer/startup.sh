#!/usr/bin/env bash

set -e
set -o pipefail

npm install -g 9router cloudflared
export INITIAL_PASSWORD="123456"
9router &
cloudflared tunnel --url http://localhost:20128 2>&1 | while IFS= read -r line; do
	printf '%s\n' "$line"
	tunnel_url=$(printf '%s\n' "$line" | grep -oE 'https://[A-Za-z0-9.-]+\.trycloudflare\.com' | head -n 1 || true)
	if [[ -n "$tunnel_url" ]]; then
		printf '\nCLOUDFLARE_TUNNEL_URL=%s\n\n' "$tunnel_url"
	fi
done
#!/usr/bin/env bash

set -e
set -o pipefail

npm install -g 9router cloudflared
export INITIAL_PASSWORD="123456"
nohup 9router --no-browser --log --skip-update >/tmp/9router.log 2>&1 &

for attempt in {1..30}; do
	if (echo >/dev/tcp/127.0.0.1/20128) >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

if ! (echo >/dev/tcp/127.0.0.1/20128) >/dev/null 2>&1; then
	printf '9router failed to start. See /tmp/9router.log\n' >&2
	cat /tmp/9router.log >&2
	exit 1
fi

stdbuf -oL -eL cloudflared tunnel --url http://localhost:20128 2>&1 | while IFS= read -r line; do
	printf '%s\n' "$line"
	tunnel_url=$(printf '%s\n' "$line" | grep -oE 'https://[A-Za-z0-9.-]+\.trycloudflare\.com' | head -n 1 || true)
	if [[ -n "$tunnel_url" ]]; then
		printf '\nCLOUDFLARE_TUNNEL_URL=%s\n\n' "$tunnel_url"
	fi
done
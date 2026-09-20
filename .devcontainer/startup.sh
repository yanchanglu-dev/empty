#!/usr/bin/env bash

set -e
set -o pipefail

startup_log=/tmp/codespace-startup.log
printf '[startup] %s\n' "$(date -Is)" >> "$startup_log"

npm install -g --allow-scripts=9router,cloudflared 9router cloudflared >>"$startup_log" 2>&1
export INITIAL_PASSWORD="123456"
if ! (echo >/dev/tcp/127.0.0.1/20128) >/dev/null 2>&1; then
	nohup setsid 9router --no-browser --log --skip-update >/tmp/9router.log 2>&1 </dev/null &
fi

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

printf '[startup] 9router is listening on http://localhost:20128\n' | tee -a "$startup_log"

if ! pgrep -f '[c]loudflared tunnel --url http://localhost:20128' >/dev/null; then
	nohup setsid bash -c '
		stdbuf -oL -eL cloudflared tunnel --url http://localhost:20128 2>&1 |
		while IFS= read -r line; do
			printf "%s\\n" "$line" >> /tmp/codespace-startup.log
			tunnel_url=$(printf "%s\\n" "$line" | grep -oE "https://[A-Za-z0-9.-]+\\.trycloudflare\\.com" | head -n 1 || true)
			if [[ -n "$tunnel_url" ]]; then
				printf "CLOUDFLARE_TUNNEL_URL=%s\\n" "$tunnel_url" >> /tmp/codespace-startup.log
			fi
		done
	' >/tmp/cloudflared.log 2>&1 </dev/null &
fi

for attempt in {1..30}; do
	if grep -q '^CLOUDFLARE_TUNNEL_URL=' "$startup_log" 2>/dev/null; then
		break
	fi
	sleep 1
done

grep '^CLOUDFLARE_TUNNEL_URL=' "$startup_log" 2>/dev/null || true
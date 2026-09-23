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

if ! pgrep -f '[c]loudflared tunnel run --token' >/dev/null; then
	nohup setsid cloudflared tunnel run --token eyJhIjoiY2M5MzRiYTYwYjc2Y2YwYmMwMDFhMmIyNzllYzlkYWYiLCJ0IjoiNjYzYTQ0MGMtMTUzNS00Y2QyLTk1OTEtYmI2MTE3ODdiODc1IiwicyI6IlpUUmtOVFF3TnprdFpUQTFOaTAwTXpZMExUaGpNRFl0WWpVNU9EbGtaVFZsWW1FeCJ9 >/tmp/cloudflared.log 2>&1 </dev/null &
    printf '[startup] fixed Cloudflare tunnel started\n' | tee -a "$startup_log"
fi
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

keys_cookie=$(mktemp)
keys_response=$(mktemp)
trap 'rm -f "$keys_cookie" "$keys_response"' EXIT
login_status=$(curl -sS -o "$keys_response" -w '%{http_code}' \
	-c "$keys_cookie" \
	-X POST http://127.0.0.1:20128/api/auth/login \
	-H 'content-type: application/json' \
	--data "{\"password\":\"${INITIAL_PASSWORD}\"}")
if [[ "$login_status" == 200 ]]; then
	keys_status=$(curl -sS -o "$keys_response" -w '%{http_code}' \
		-b "$keys_cookie" \
		http://127.0.0.1:20128/api/keys)
	if [[ "$keys_status" == 200 ]]; then
		printf '[startup] 9router keys:\n' | tee -a "$startup_log"
		keys=$(node -e '
const fs = require("fs");
const payload = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const keys = [];
const visit = (value) => {
  if (typeof value === "string" && /^sk-[A-Za-z0-9_-]+$/.test(value)) keys.push(value);
  else if (Array.isArray(value)) value.forEach(visit);
  else if (value && typeof value === "object") Object.values(value).forEach(visit);
};
visit(payload);
console.log([...new Set(keys)].join("\n"));
' "$keys_response" 2>/dev/null || true)
		if [[ -n "$keys" ]]; then
			printf '%s\n' "$keys" | tee -a "$startup_log"
		else
			printf '[startup] warning: no sk- key found in /api/keys response\n' | tee -a "$startup_log" >&2
		fi
	else
		printf '[startup] warning: /api/keys returned HTTP %s\n' "$keys_status" | tee -a "$startup_log" >&2
	fi
else
	printf '[startup] warning: login returned HTTP %s; could not query /api/keys\n' "$login_status" | tee -a "$startup_log" >&2
fi

if ! pgrep -f '[c]loudflared tunnel run --token' >/dev/null; then
	nohup setsid cloudflared tunnel run --token eyJhIjoiY2M5MzRiYTYwYjc2Y2YwYmMwMDFhMmIyNzllYzlkYWYiLCJ0IjoiNjYzYTQ0MGMtMTUzNS00Y2QyLTk1OTEtYmI2MTE3ODdiODc1IiwicyI6IlpUUmtOVFF3TnprdFpUQTFOaTAwTXpZMExUaGpNRFl0WWpVNU9EbGtaVFZsWW1FeCJ9 >/tmp/cloudflared.log 2>&1 </dev/null &
    printf '[startup] fixed Cloudflare tunnel started\n' | tee -a "$startup_log"
fi
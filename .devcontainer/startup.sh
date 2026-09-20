#!/usr/bin/env bash

set -e

npm install -g 9router cloudflared
export INITIAL_PASSWORD="123456"
9router &
exec cloudflared tunnel --url http://localhost:20128
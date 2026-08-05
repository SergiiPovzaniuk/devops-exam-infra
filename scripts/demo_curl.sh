#!/usr/bin/env bash
set -euo pipefail
URL="${1:?usage: demo_curl.sh http://HOST:30080}"
for i in $(seq 1 20); do
  curl -s "$URL/api/info" | jq -r '[.hostname, .node_name, .aws.instance_id, .aws.private_ip] | @tsv'
  sleep 0.3
done
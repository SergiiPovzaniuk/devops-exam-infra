#!/bin/bash
# Run on Jenkins host (or via ssh). Forwards GitHub→Smee→local Jenkins webhook.
set -eu
SMEE_URL="${SMEE_URL:-https://smee.io/MKMit7OMtF4nBA7k}"
TARGET="${TARGET:-http://127.0.0.1:8080/github-webhook/}"

docker rm -f jenkins-github-smee 2>/dev/null || true
docker run -d \
  --name jenkins-github-smee \
  --restart unless-stopped \
  --network host \
  node:20-alpine \
  sh -c "npm install -g smee-client@2.0.4 && smee --url ${SMEE_URL} --target ${TARGET}"

sleep 3
docker logs jenkins-github-smee 2>&1 | tail -20
echo "smee relay: ${SMEE_URL} -> ${TARGET}"

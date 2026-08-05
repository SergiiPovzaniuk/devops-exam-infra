#!/bin/bash
set -eu
PASS=admin
HOST=admin@192.168.32.80
ROOT=/mnt/c/Users/sergi/devops_diploma/devops-exam-infra/monitoring
export PATH="$HOME/.local/bin:$PATH"

sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "$ROOT/grafana/provisioning/datasources/datasources.yml" \
  "$ROOT/grafana/provisioning/dashboards/dashboards.yml" \
  "$ROOT/grafana/dashboards/devops-exam.json" \
  "$HOST:/tmp/"

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$HOST" bash <<'EOS'
set -eu
echo admin | sudo -S bash -c '
set -eu
mkdir -p /opt/monitoring/grafana/provisioning/datasources \
         /opt/monitoring/grafana/provisioning/dashboards \
         /opt/monitoring/grafana/dashboards
# remove conflicting default datasource files
rm -f /opt/monitoring/grafana/provisioning/datasources/datasource.yml \
      /opt/monitoring/grafana/provisioning/datasources/datasources.yml \
      /opt/monitoring/grafana/provisioning/dashboards/exam.yml \
      /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml
cp /tmp/datasources.yml /opt/monitoring/grafana/provisioning/datasources/datasources.yml
cp /tmp/dashboards.yml /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml
cp /tmp/devops-exam.json /opt/monitoring/grafana/dashboards/devops-exam.json
cd /opt/monitoring
docker compose up -d grafana
docker compose restart grafana
'
sleep 8
curl -s -u admin:grafana-change-me http://127.0.0.1:3000/api/health
echo
curl -s -u admin:grafana-change-me http://127.0.0.1:3000/api/datasources | python3 -c "import sys,json; print([(d[\"name\"], d[\"type\"], d.get(\"isDefault\"), d.get(\"uid\")) for d in json.load(sys.stdin)])"
curl -s -u admin:grafana-change-me "http://127.0.0.1:3000/api/search?type=dash-db" | python3 -c "import sys,json; print([(d[\"title\"], d.get(\"uid\"), d.get(\"folderTitle\")) for d in json.load(sys.stdin)])"
curl -s -u admin:grafana-change-me -H "Content-Type: application/json" \
  -d "{\"queries\":[{\"refId\":\"A\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"up{job=\\\"devops-exam-app\\\"}\",\"instant\":true}],\"from\":\"now-5m\",\"to\":\"now\"}" \
  http://127.0.0.1:3000/api/ds/query | python3 -c "import sys,json; d=json.load(sys.stdin); print(\"query_ok\", \"results\" in d)"
EOS

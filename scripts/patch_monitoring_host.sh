#!/usr/bin/env bash
set -eu
export PATH="$HOME/.local/bin:$PATH"
PASS=admin
HOST=admin@192.168.32.80
ROOT=/mnt/c/Users/sergi/devops_diploma/devops-exam-infra/monitoring
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "$ROOT/prometheus/prometheus.docker.yml" \
  "$ROOT/prometheus/rules/exam.yml" \
  "$ROOT/grafana/datasources.docker.yml" \
  "$ROOT/grafana/dashboards/devops-exam.json" \
  "$HOST:/tmp/"
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$HOST" 'echo admin | sudo -S bash -s' <<'EOS'
set -eu
cp /tmp/prometheus.docker.yml /opt/monitoring/prometheus/prometheus.yml
cp /tmp/exam.yml /opt/monitoring/prometheus/exam-alerts.yml
mkdir -p /opt/monitoring/grafana/provisioning/datasources /opt/monitoring/grafana/provisioning/dashboards /opt/monitoring/grafana/dashboards
cp /tmp/datasources.docker.yml /opt/monitoring/grafana/provisioning/datasources/datasources.yml
cp /tmp/devops-exam.json /opt/monitoring/grafana/dashboards/devops-exam.json
cat >/opt/monitoring/grafana/provisioning/dashboards/exam.yml <<'DASH'
apiVersion: 1
providers:
  - name: exam
    orgId: 1
    folder: Exam
    type: file
    options:
      path: /var/lib/grafana/dashboards
DASH
cd /opt/monitoring
docker compose restart prometheus grafana alertmanager loki
sleep 4
curl -s http://127.0.0.1:9090/api/v1/targets | python3 -c "import sys,json; d=json.load(sys.stdin); print([(t['labels'].get('instance'), t['labels'].get('job'), t['health']) for t in d['data']['activeTargets']])"
EOS

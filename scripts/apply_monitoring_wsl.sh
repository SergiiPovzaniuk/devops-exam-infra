#!/usr/bin/env bash
set -euo pipefail
PASS="${PROMETHEUS_GRAPHANA_LOKI_ALTERNATIVE_HOST_SSH_PASSWORD:-admin}"
HOST="admin@192.168.32.80"
ROOT="/mnt/c/Users/sergi/devops_diploma/devops-exam-infra/monitoring"

export PATH="$HOME/.local/bin:$PATH"
SSHPASS_BIN="$(command -v sshpass || true)"
if [[ -z "$SSHPASS_BIN" ]]; then
  echo "sshpass missing" >&2
  exit 1
fi

"$SSHPASS_BIN" -p "$PASS" ssh -o StrictHostKeyChecking=no "$HOST" 'mkdir -p /tmp/exam-monitoring/rules'
"$SSHPASS_BIN" -p "$PASS" scp -o StrictHostKeyChecking=no \
  "$ROOT/prometheus/prometheus.exam.yml" \
  "$ROOT/alertmanager/alertmanager.yml" \
  "$ROOT/grafana/datasources.yml" \
  "$ROOT/grafana/dashboards/devops-exam.json" \
  "$HOST:/tmp/exam-monitoring/"
"$SSHPASS_BIN" -p "$PASS" scp -o StrictHostKeyChecking=no \
  "$ROOT/prometheus/rules/exam.yml" \
  "$HOST:/tmp/exam-monitoring/rules/"

"$SSHPASS_BIN" -p "$PASS" ssh -o StrictHostKeyChecking=no "$HOST" bash <<'EOS'
set -e
sudo mkdir -p /etc/prometheus/rules /etc/alertmanager /etc/grafana/provisioning/datasources /var/lib/grafana/dashboards /etc/grafana/provisioning/dashboards
if [ -f /etc/prometheus/prometheus.yml ]; then sudo cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.bak.$(date +%s); fi
sudo cp /tmp/exam-monitoring/prometheus.exam.yml /etc/prometheus/prometheus.yml
sudo cp /tmp/exam-monitoring/rules/exam.yml /etc/prometheus/rules/exam.yml
sudo cp /tmp/exam-monitoring/alertmanager.yml /etc/alertmanager/alertmanager.yml
sudo cp /tmp/exam-monitoring/datasources.yml /etc/grafana/provisioning/datasources/datasources.yml
sudo cp /tmp/exam-monitoring/devops-exam.json /var/lib/grafana/dashboards/devops-exam.json
cat <<'DASH' | sudo tee /etc/grafana/provisioning/dashboards/exam.yml >/dev/null
apiVersion: 1
providers:
  - name: exam
    orgId: 1
    folder: Exam
    type: file
    options:
      path: /var/lib/grafana/dashboards
DASH
# Loki datasource already in datasources.yml
for s in prometheus alertmanager grafana-server grafana loki; do
  sudo systemctl restart "$s" 2>/dev/null || true
done
sleep 2
curl -s http://127.0.0.1:9090/-/healthy || true
curl -s 'http://127.0.0.1:9090/api/v1/targets' | head -c 500 || true
EOS
echo monitoring-applied
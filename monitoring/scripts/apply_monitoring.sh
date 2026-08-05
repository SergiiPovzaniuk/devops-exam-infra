#!/usr/bin/env bash
set -euo pipefail
CP="${1:?control plane public ip}"
W1="${2:?worker1 public ip}"
W2="${3:?worker2 public ip}"
HOST="${MONITORING_SSH:-admin@192.168.32.80}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

sed -e "s/CP_PUBLIC_IP/$CP/g" -e "s/W1_PUBLIC_IP/$W1/g" -e "s/W2_PUBLIC_IP/$W2/g" \
  "$ROOT/prometheus/prometheus.yml" > "$TMP/prometheus.yml"
cp -r "$ROOT/prometheus/rules" "$TMP/rules"
cp "$ROOT/alertmanager/alertmanager.yml" "$TMP/alertmanager.yml"
cp "$ROOT/grafana/datasources.yml" "$TMP/datasources.yml"
cp "$ROOT/grafana/dashboards/devops-exam.json" "$TMP/devops-exam.json"

scp -r "$TMP/prometheus.yml" "$TMP/rules" "$TMP/alertmanager.yml" "$TMP/datasources.yml" "$TMP/devops-exam.json" "$HOST:/tmp/exam-monitoring/"

ssh "$HOST" bash -s <<'EOS'
set -e
sudo mkdir -p /etc/prometheus/rules /etc/alertmanager /etc/grafana/provisioning/datasources /var/lib/grafana/dashboards
sudo cp /tmp/exam-monitoring/prometheus.yml /etc/prometheus/prometheus.yml
sudo cp /tmp/exam-monitoring/rules/*.yml /etc/prometheus/rules/ || true
sudo cp /tmp/exam-monitoring/alertmanager.yml /etc/alertmanager/alertmanager.yml
sudo cp /tmp/exam-monitoring/datasources.yml /etc/grafana/provisioning/datasources/datasources.yml
sudo cp /tmp/exam-monitoring/devops-exam.json /var/lib/grafana/dashboards/devops-exam.json
sudo systemctl restart prometheus alertmanager grafana-server || sudo systemctl restart prometheus alertmanager grafana || true
EOS
echo "Monitoring updated for $CP $W1 $W2"
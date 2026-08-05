#!/usr/bin/env bash
set -euo pipefail
# Usage: apply_monitoring.sh <cp_ip> <w1_ip> <w2_ip>
# Applies Prometheus/Grafana/Alertmanager configs to Docker stack on 192.168.32.80
CP="${1:?cp ip}"
W1="${2:?w1 ip}"
W2="${3:?w2 ip}"
PASS="${PROMETHEUS_GRAPHANA_LOKI_ALTERNATIVE_HOST_SSH_PASSWORD:-admin}"
HOST="${MONITORING_SSH_HOST:-admin@192.168.32.80}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

SSHPASS_BIN="$(command -v sshpass || true)"
[[ -n "$SSHPASS_BIN" ]] || { echo "sshpass required"; exit 1; }

sed -e "s/CP_PUBLIC_IP/${CP}/g" -e "s/W1_PUBLIC_IP/${W1}/g" -e "s/W2_PUBLIC_IP/${W2}/g" \
  "$ROOT/prometheus/prometheus.docker.yml" > /tmp/prometheus.docker.yml 2>/dev/null \
  || sed -e "s/63.184.114.206/${CP}/g" -e "s/18.184.182.88/${W1}/g" -e "s/18.193.83.196/${W2}/g" \
  "$ROOT/prometheus/prometheus.docker.yml" > /tmp/prometheus.docker.yml

"$SSHPASS_BIN" -p "$PASS" scp -o StrictHostKeyChecking=no \
  /tmp/prometheus.docker.yml \
  "$ROOT/prometheus/rules/exam.yml" \
  "$ROOT/grafana/provisioning/datasources/datasources.yml" \
  "$ROOT/grafana/provisioning/dashboards/dashboards.yml" \
  "$ROOT/grafana/dashboards/devops-exam.json" \
  "$HOST:/tmp/"

"$SSHPASS_BIN" -p "$PASS" ssh -o StrictHostKeyChecking=no "$HOST" bash <<EOS
set -eu
echo ${PASS} | sudo -S bash -c '
cp /tmp/prometheus.docker.yml /opt/monitoring/prometheus/prometheus.yml
cp /tmp/exam.yml /opt/monitoring/prometheus/exam-alerts.yml
rm -f /opt/monitoring/grafana/provisioning/datasources/datasource.yml
mkdir -p /opt/monitoring/grafana/provisioning/datasources /opt/monitoring/grafana/provisioning/dashboards /opt/monitoring/grafana/dashboards
cp /tmp/datasources.yml /opt/monitoring/grafana/provisioning/datasources/datasources.yml
cp /tmp/dashboards.yml /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml
cp /tmp/devops-exam.json /opt/monitoring/grafana/dashboards/devops-exam.json
cd /opt/monitoring && docker compose restart prometheus grafana alertmanager loki
'
echo monitoring-ok
EOS

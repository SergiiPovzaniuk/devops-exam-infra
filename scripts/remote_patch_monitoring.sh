#!/bin/bash
set -eu
echo admin | sudo -S cp /tmp/prometheus.docker.yml /opt/monitoring/prometheus/prometheus.yml
echo admin | sudo -S cp /tmp/exam.yml /opt/monitoring/prometheus/exam-alerts.yml
echo admin | sudo -S mkdir -p /opt/monitoring/grafana/provisioning/datasources /opt/monitoring/grafana/provisioning/dashboards /opt/monitoring/grafana/dashboards
echo admin | sudo -S cp /tmp/datasources.docker.yml /opt/monitoring/grafana/provisioning/datasources/datasources.yml
echo admin | sudo -S cp /tmp/devops-exam.json /opt/monitoring/grafana/dashboards/devops-exam.json
echo admin | sudo -S tee /opt/monitoring/grafana/provisioning/dashboards/exam.yml >/dev/null <<'DASH'
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
echo admin | sudo -S docker compose restart prometheus grafana alertmanager loki
sleep 4
curl -s http://127.0.0.1:9090/api/v1/targets | python3 -c "import sys,json; d=json.load(sys.stdin); print([(t['labels'].get('instance'), t['labels'].get('job'), t['health']) for t in d['data']['activeTargets']])"

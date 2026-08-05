#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export PROMETHEUS_GRAPHANA_LOKI_ALTERNATIVE_HOST_SSH_PASSWORD="${PROMETHEUS_GRAPHANA_LOKI_ALTERNATIVE_HOST_SSH_PASSWORD:-admin}"
sed -i 's/\r$//' /mnt/c/Users/sergi/devops_diploma/devops-exam-infra/scripts/apply_monitoring_wsl.sh
bash /mnt/c/Users/sergi/devops_diploma/devops-exam-infra/scripts/apply_monitoring_wsl.sh

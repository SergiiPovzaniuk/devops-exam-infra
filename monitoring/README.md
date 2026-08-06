# Logging (Promtail → Loki)

App pods log to stdout/stderr. Promtail DaemonSet on each node tails `/var/log/containers/*.log` and pushes to in-cluster Loki.

```text
Flask/gunicorn → container logs → Promtail DS → Loki (ns logging) → Grafana Explore
```

Apply:

```bash
export KUBECONFIG=ansible/files/kubeconfig
kubectl apply -f monitoring/k8s/loki-promtail.yaml
```

Grafana Loki datasource: `http://<control-plane-public-ip>:31000` (NodePort).

Explore query:

```logql
{job="containers"} |= "method="
```

or filter by filename containing `devops-exam-app`.

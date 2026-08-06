# devops-exam-infra

Infrastructure for the DevOps diploma: cheap AWS kubeadm cluster, Jenkins CI/CD, Prometheus/Grafana/Alertmanager, Loki logging.

Companion app repo: [devops-exam-app](https://github.com/SergiiPovzaniuk/devops-exam-app)

**Live IPs / URLs:** [docs/LIVE.md](docs/LIVE.md) · Rubric: [docs/RUBRIC.md](docs/RUBRIC.md)

## Architecture

```text
GitHub (develop push)
  → webhook → Jenkins (https://jenkins.iba-expert.uk)
  → test → docker build/push → kubectl deploy

User → AWS NLB :80 → EC2 NodePort :30080 → app pods (3 replicas)

Prometheus (LAN) scrapes node_exporter :9100 + app /metrics
  → Alertmanager UI
Promtail DaemonSet → Loki (in-cluster NodePort 31000) → Grafana Explore
```

| Layer | Tool | What it creates |
|-------|------|-----------------|
| Cloud | Terraform | VPC, 3× `t3.small`, SG, NLB, remote state (S3+DynamoDB) |
| OS / K8s | Ansible | UFW, containerd, kubeadm, Flannel, node_exporter |
| CI/CD | Jenkins | Multibranch pipeline, webhook, destroy job |
| Observability | Docker Compose (LAN) + K8s | Prometheus, Grafana, Alertmanager; Loki/Promtail in cluster |

Region: `eu-central-1`. K8s: kubeadm **1.29**, not EKS.

## Repository layout

```text
terraform/
  bootstrap/          S3 state bucket + DynamoDB lock
  modules/            vpc, ec2-node, s3-backend
  envs/exam/          exam stack (3 EC2 + NLB)
ansible/
  playbooks/site.yml  full cluster install
  roles/              common, firewall, containerd, kubernetes, control_plane, worker, node_exporter
  inventory/          hosts.ini (generated; gitignored)
  files/kubeconfig    fetched from CP (gitignored)
jenkins/
  casc/               Jenkins location URL, job groovy
  scripts/            setup_jenkins.py, setup_webhook.py
Jenkinsfile.destroy   manual AWS teardown pipeline
monitoring/
  prometheus/         scrape config + exam alert rules
  grafana/            datasources + DevOps Exam dashboard
  alertmanager/       routing (UI only; no Discord)
  k8s/loki-promtail.yaml
scripts/              bootstrap.sh, run_ansible_wsl.sh, regen_apiserver_cert.sh, demo_curl.sh
docs/                 LIVE.md, RUBRIC.md, SSL.md
```

## Prerequisites

- AWS credentials (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)
- Terraform ≥ 1.5, AWS CLI, jq
- WSL + Ansible (Windows: use `scripts/run_ansible_wsl.sh`)
- SSH key `~/.ssh/devops-exam` (created by bootstrap if missing)
- Local Jenkins + monitoring hosts (see LIVE.md)
- Secrets in parent `.env` (never commit): Jenkins, Docker Hub, GitHub token, AWS

## 1. Bootstrap AWS + Kubernetes

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-central-1
./scripts/bootstrap.sh
```

This runs:

1. `terraform apply` bootstrap → S3 + DynamoDB
2. `terraform apply` exam → VPC, 3 EC2, NLB
3. Generate Ansible inventory
4. `ansible-playbook playbooks/site.yml` → kubeadm + Flannel + node_exporter
5. Saves kubeconfig to `ansible/files/kubeconfig`

**Windows / WSL:** after Terraform, update IPs in `scripts/run_ansible_wsl.sh` (or regenerate inventory) and run that script.

If `kubectl` via public IP fails TLS (SAN), run:

```bash
./scripts/regen_apiserver_cert.sh
```

### First app deploy

```bash
export KUBECONFIG=$PWD/ansible/files/kubeconfig
kubectl get nodes
kubectl apply -f ../devops-exam-app/k8s/deployment.yaml
kubectl apply -f monitoring/k8s/loki-promtail.yaml
./scripts/demo_curl.sh "$(cd terraform/envs/exam && terraform output -raw app_url)"
```

- App: Deployment 3 replicas + Service **NodePort 30080**
- Ingress path: **NLB :80 → :30080** on all nodes

SSH:

```bash
ssh -i ~/.ssh/devops-exam ubuntu@<public-ip>
```

## 2. Jenkins CI/CD

```bash
# load JENKINS_*, DOCKER_*, GITHUB_TOKEN, kubeconfig path from .env
python jenkins/scripts/setup_jenkins.py
python jenkins/scripts/setup_webhook.py
```

| Item | Detail |
|------|--------|
| URL | https://jenkins.iba-expert.uk/ |
| Job | `devops-exam-app` / Multibranch `pipeline` |
| Webhook | `https://jenkins.iba-expert.uk/github-webhook/` |
| Creds | `github-token`, `dockerhub`, `kubeconfig-exam`, `aws-exam` |

Branch policy:

| Branch | Trigger | Deploy |
|--------|---------|--------|
| `develop` | automatic (GitHub webhook) | after green tests |
| `main` | **manual** Build only (`NoTriggerBranchProperty`) | after green tests |

Pipeline stages (in app `Jenkinsfile`): Checkout → Test (Docker) → Build → Publish (Docker Hub) → Deploy (`kubectl`).

More: [jenkins/README.md](jenkins/README.md)

## 3. Monitoring

Stack on LAN host (default `192.168.32.80`): Prometheus, Grafana, Alertmanager.

```bash
./monitoring/scripts/apply_monitoring.sh <cp_ip> <w1_ip> <w2_ip>
```

| Service | URL |
|---------|-----|
| Prometheus | http://192.168.32.80:9090 |
| Grafana | http://192.168.32.80:3000 |
| Alertmanager | http://192.168.32.80:9093 |

Grafana login: `admin` / password on monitoring host `.env` (often `grafana-change-me`).

### Scrapes

- `node` — exam CP/W1/W2 `:9100` (labels `exam-cp`, `exam-w1`, `exam-w2`, `env=exam`)
- `devops-exam-app` — `/metrics` via NodePort and/or NLB

### Alerts (`monitoring/prometheus/rules/exam.yml`)

| Alert | Condition |
|-------|-----------|
| `HighCpuUsage` | CPU > 40% on exam node |
| `CriticalCpuUsage` | CPU > 85% |
| `InstanceDown` | `up{env="exam"} == 0` |
| `HighAppRequestRate` | high `app_http_requests_total` rate |

Rules live in Prometheus; firing alerts go to Alertmanager (`group_by: alertname, instance`). Receiver is empty (UI only).

**Demo CPU alert:**

```bash
ssh -i ~/.ssh/devops-exam ubuntu@<worker-public-ip>
sudo apt-get install -y stress-ng
stress-ng --cpu 0 --timeout 300s
```

Then open Prometheus `/alerts` (must be **FIRING**, not Pending) and Alertmanager `/#/alerts`.  
Clear any Filter like `env="production"` — exam alerts use `env=exam`.

### Logs (Loki)

In-cluster Loki + Promtail DaemonSet (AWS cannot reach LAN Loki):

```bash
kubectl apply -f monitoring/k8s/loki-promtail.yaml
```

Grafana Loki datasource → `http://<control-plane-public-ip>:31000`.

```logql
{job="containers"} |= "method="
```

Details: [monitoring/README.md](monitoring/README.md)

## 4. Destroy (stop AWS cost)

**Preferred — Jenkins (manual only):**

1. Job `devops-exam-infra` / `destroy`
2. Build with Parameters → `CONFIRM_DESTROY=true`
3. Optional: `DESTROY_BOOTSTRAP=true` (deletes S3 state + lock table)

**Local:**

```bash
cd terraform/envs/exam && terraform destroy -auto-approve
# optional:
cd ../bootstrap && terraform destroy -auto-approve
```

`main` app deploys are also manual-only; do not leave unused EC2 running.

## Ansible flow (exam talking points)

`playbooks/site.yml`:

1. All nodes: `common` → `firewall` → `containerd` → `kubernetes`
2. Control-plane: `kubeadm init` + Flannel + join token + fetch kubeconfig
3. Workers: `kubeadm join` (API address comes from join command)
4. All nodes: `node_exporter`

Workers register to the control-plane API address embedded in the join command (`private_ip:6443`).

## Useful commands

```bash
export KUBECONFIG=$PWD/ansible/files/kubeconfig
kubectl get nodes -o wide
kubectl get pods -o wide
kubectl -n logging get pods
cd terraform/envs/exam && terraform output
```

## Related docs

| Doc | Content |
|-----|---------|
| [docs/LIVE.md](docs/LIVE.md) | Current IPs, NLB DNS, service URLs |
| [docs/RUBRIC.md](docs/RUBRIC.md) | Diploma checklist |
| [docs/SSL.md](docs/SSL.md) | Optional TLS (skipped by default) |
| [jenkins/README.md](jenkins/README.md) | Webhook + destroy job |
| [monitoring/README.md](monitoring/README.md) | Loki / Promtail |

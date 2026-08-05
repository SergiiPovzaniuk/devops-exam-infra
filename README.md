# devops-exam-infra

IaC for DevOps diploma: Terraform (3× t3.small + NLB), Ansible kubeadm, Jenkins, monitoring.

Live details: [docs/LIVE.md](docs/LIVE.md)

## Bootstrap

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-central-1
./scripts/bootstrap.sh
```

```bash
export KUBECONFIG=$PWD/ansible/files/kubeconfig
kubectl apply -f ../devops-exam-app/k8s/deployment.yaml
./scripts/demo_curl.sh "$(cd terraform/envs/exam && terraform output -raw app_url)"
```

## Jenkins

```bash
# load JENKINS_* DOCKER_* GITHUB_TOKEN from env
python jenkins/scripts/setup_jenkins.py
```

- Folder `devops-exam-app` / Multibranch `pipeline`
- `develop`: auto CI/CD on push
- `main`: manual Build only (`NoTriggerBranchProperty`)
- Creds: `github-token`, `dockerhub`, `kubeconfig-exam`

## Monitoring

```bash
./monitoring/scripts/apply_monitoring.sh <cp_ip> <w1_ip> <w2_ip>
```

Grafana: http://192.168.32.80:3000 (admin / see host `.env`)

## Destroy

**Jenkins (manual):** `devops-exam-infra` → `destroy` → Build with Parameters → `CONFIRM_DESTROY=true`.

Or locally:

```bash
cd terraform/envs/exam && terraform destroy -auto-approve
# optional:
cd ../bootstrap && terraform destroy -auto-approve
```

## Layout

```
terraform/   modules + bootstrap + envs/exam (VMs + NLB)
ansible/     kubeadm + UFW + node_exporter
jenkins/     CasC + setup_jenkins.py
monitoring/  Prometheus/Grafana/Alertmanager/Loki
scripts/     bootstrap, demo_curl, ansible/cert helpers
```

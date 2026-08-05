# devops-exam-infra

IaC and platform config for the DevOps diploma exam.

- Terraform: VPC + 3× `t3.small` Ubuntu (kubeadm)
- Ansible: UFW, containerd, kubeadm, Flannel, node_exporter
- Jenkins: folder `devops-exam-app` + Multibranch + JCasC
- Monitoring: Prometheus / Grafana / Alertmanager / Loki configs for host `192.168.32.80`

Live cluster details: [docs/LIVE.md](docs/LIVE.md)

## Bootstrap (few commands)

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-central-1

./scripts/bootstrap.sh
```

Then:

```bash
export KUBECONFIG=$PWD/ansible/files/kubeconfig
kubectl get nodes
kubectl apply -f ../devops-exam-app/k8s/deployment.yaml
./scripts/demo_curl.sh http://$(cd terraform/envs/exam && terraform output -raw control_plane_public_ip):30080
```

## Monitoring

```bash
./monitoring/scripts/apply_monitoring.sh <cp_ip> <w1_ip> <w2_ip>
```

## Jenkins

```bash
# from machine with access to Jenkins
source ../.env   # or export JENKINS_* 
bash jenkins/scripts/create_folder_job.sh
```

Credentials to create in Jenkins UI:

- `github-token` (Secret text / username+token)
- `dockerhub` (username/password)
- `kubeconfig-exam` (Secret file)

## Destroy (stop spend)

```bash
cd terraform/envs/exam && terraform destroy -auto-approve
```

## Layout

```
terraform/modules/   reusable vpc, ec2-node, s3-backend
terraform/bootstrap/ S3 + DynamoDB state
terraform/envs/exam/ cluster VMs
ansible/             kubeadm + firewall
jenkins/             CasC + job script
monitoring/          scrape/alert/dashboard configs
docs/RUBRIC.md       scoring checklist
```

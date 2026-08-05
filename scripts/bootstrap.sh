#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-eu-central-1}"
BUCKET="${TF_STATE_BUCKET:-devops-exam-tfstate-646819876267}"

if [[ ! -f "$HOME/.ssh/devops-exam" ]]; then
  ssh-keygen -t ed25519 -f "$HOME/.ssh/devops-exam" -N "" -C "devops-exam"
fi

cd "$ROOT/terraform/bootstrap"
cat > terraform.tfvars <<EOF
aws_region        = "$REGION"
state_bucket_name = "$BUCKET"
lock_table_name   = "devops-exam-tf-lock"
EOF
terraform init
terraform apply -auto-approve

cd "$ROOT/terraform/envs/exam"
cat > terraform.tfvars <<EOF
aws_region      = "$REGION"
az              = "${REGION}a"
instance_type   = "t3.small"
key_name        = "devops-exam"
public_key_path = "$HOME/.ssh/devops-exam.pub"
ssh_cidr        = "0.0.0.0/0"
monitoring_cidr = "0.0.0.0/0"
EOF
terraform init
terraform apply -auto-approve

CP=$(terraform output -raw control_plane_public_ip)
W1=$(terraform output -json worker_public_ips | jq -r '.[0]')
W2=$(terraform output -json worker_public_ips | jq -r '.[1]')

cd "$ROOT/ansible"
ansible-playbook playbooks/generate_inventory.yml -e "cp_ip=$CP" -e "w1_ip=$W1" -e "w2_ip=$W2" -e "key_path=$HOME/.ssh/devops-exam"
ansible-playbook playbooks/site.yml

echo "Cluster ready. App NodePort: http://$CP:30080"
echo "Kubeconfig: $ROOT/ansible/files/kubeconfig"
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.ssh"
cp /mnt/c/Users/sergi/.ssh/devops-exam "$HOME/.ssh/devops-exam"
chmod 600 "$HOME/.ssh/devops-exam"
rm -rf "$HOME/devops-exam-infra"
cp -a /mnt/c/Users/sergi/devops_diploma/devops-exam-infra "$HOME/devops-exam-infra"
chmod -R go-w "$HOME/devops-exam-infra/ansible"
cat > "$HOME/devops-exam-infra/ansible/inventory/hosts.ini" <<EOF
[control_plane]
cp ansible_host=63.184.114.206 private_ip=10.42.1.175

[workers]
w1 ansible_host=18.184.182.88 private_ip=10.42.1.163
w2 ansible_host=18.193.83.196 private_ip=10.42.1.223

[k8s:children]
control_plane
workers

[k8s:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=$HOME/.ssh/devops-exam
ansible_ssh_common_args=-o StrictHostKeyChecking=no
EOF
cd "$HOME/devops-exam-infra/ansible"
export ANSIBLE_CONFIG="$HOME/devops-exam-infra/ansible/ansible.cfg"
export ANSIBLE_ROLES_PATH="$HOME/devops-exam-infra/ansible/roles"
ansible -i inventory/hosts.ini k8s -m ping
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
mkdir -p /mnt/c/Users/sergi/devops_diploma/devops-exam-infra/ansible/files
if [[ -f files/kubeconfig ]]; then
  cp files/kubeconfig /mnt/c/Users/sergi/devops_diploma/devops-exam-infra/ansible/files/kubeconfig
fi
kubectl --kubeconfig=files/kubeconfig get nodes || true

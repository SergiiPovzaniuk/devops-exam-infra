#!/bin/bash
set -eu
PUBLIC_IP=52.59.86.56
PRIVATE_IP=10.42.1.75
KEY=${1:-$HOME/.ssh/devops-exam}

ssh -o StrictHostKeyChecking=no -i "$KEY" "ubuntu@${PUBLIC_IP}" "PUBLIC_IP=$PUBLIC_IP PRIVATE_IP=$PRIVATE_IP bash -s" <<'EOS'
set -eu
if [ ! -f /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
  for f in /tmp/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak; do
    if [ -f "$f" ]; then sudo mv "$f" /etc/kubernetes/manifests/kube-apiserver.yaml; break; fi
  done
fi
sudo ls -la /etc/kubernetes/manifests/
K8S_VER=$(kubeadm version -o short)
cat <<CFG | sudo tee /tmp/kubeadm-new.yaml >/dev/null
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: ${K8S_VER}
controlPlaneEndpoint: ${PRIVATE_IP}:6443
networking:
  podSubnet: 10.244.0.0/16
apiServer:
  certSANs:
    - ${PRIVATE_IP}
    - ${PUBLIC_IP}
    - 127.0.0.1
    - localhost
    - kubernetes
CFG
sudo rm -f /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver.key
sudo kubeadm init phase certs apiserver --config=/tmp/kubeadm-new.yaml
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A2 'Subject Alternative'
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml
sleep 5
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
for i in $(seq 1 40); do
  if sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get --raw=/readyz >/dev/null 2>&1; then
    echo ready
    break
  fi
  sleep 3
done
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
EOS

KC=/mnt/c/Users/sergi/devops_diploma/devops-exam-infra/ansible/files/kubeconfig
if [ -f "$KC" ]; then
  sed -i "s#server: https://.*:6443#server: https://${PUBLIC_IP}:6443#" "$KC"
fi
sleep 2
kubectl --kubeconfig="$KC" get nodes || true

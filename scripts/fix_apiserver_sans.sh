#!/bin/bash
set -eu
CP_PUBLIC="${1:?public ip}"
CP_PRIVATE="${2:?private ip}"
KEY="${3:-$HOME/.ssh/devops-exam}"

ssh -o StrictHostKeyChecking=no -i "$KEY" "ubuntu@${CP_PUBLIC}" bash -s -- "$CP_PUBLIC" "$CP_PRIVATE" <<'EOS'
set -eu
PUBLIC_IP="$1"
PRIVATE_IP="$2"
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak
# patch kubeadm ClusterConfiguration with certSANs
sudo kubeadm config view > /tmp/kubeadm-view.yaml || true
cat <<CFG | sudo tee /tmp/kubeadm-new.yaml >/dev/null
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.29.15
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
    - kubernetes.default
    - kubernetes.default.svc
    - kubernetes.default.svc.cluster.local
  extraArgs:
    advertise-address: ${PRIVATE_IP}
CFG
sudo kubeadm init phase certs apiserver --config=/tmp/kubeadm-new.yaml
# restart apiserver by touching manifest
sudo mkdir -p /etc/kubernetes/manifests
sudo sed -i "s#--advertise-address=.*#--advertise-address=${PRIVATE_IP}#" /etc/kubernetes/manifests/kube-apiserver.yaml || true
if ! grep -q "${PUBLIC_IP}" /etc/kubernetes/manifests/kube-apiserver.yaml; then
  true
fi
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml && sleep 3 && sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 20
kubectl --kubeconfig=/home/ubuntu/.kube/config get --raw=/readyz && echo apiserver-ok
EOS

# Live environment (updated during bootstrap)

## AWS kubeadm

| Role | Public IP | Private IP |
|------|-----------|------------|
| control-plane | 63.184.114.206 | 10.42.1.175 |
| worker-1 | 18.184.182.88 | 10.42.1.163 |
| worker-2 | 18.193.83.196 | 10.42.1.223 |

- App URL: http://63.184.114.206:30080
- SSH: `ssh -i ~/.ssh/devops-exam ubuntu@<public-ip>`
- Kubeconfig: `ansible/files/kubeconfig` (API server rewritten to CP public IP)

## Local platform

| Service | URL |
|---------|-----|
| Jenkins | http://192.168.32.70:8080 |
| Jenkins folder | http://192.168.32.70:8080/job/devops-exam-app/ |
| Prometheus | http://192.168.32.80:9090 |
| Grafana | http://192.168.32.80:3000 |
| Alertmanager | http://192.168.32.80:9093 |
| Loki | http://192.168.32.80:3100 |

## GitHub

- https://github.com/SergiiPovzaniuk/devops-exam-app
- https://github.com/SergiiPovzaniuk/devops-exam-infra
- Fork: https://github.com/SergiiPovzaniuk/simple-java-maven-app

## Demo

```bash
./scripts/demo_curl.sh http://63.184.114.206:30080
```

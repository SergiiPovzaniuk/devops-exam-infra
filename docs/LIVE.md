# Live environment

## AWS kubeadm + NLB

| Role | Public IP | Private IP |
|------|-----------|------------|
| control-plane | 52.59.86.56 | 10.42.1.75 |
| worker-1 | 63.176.147.227 | 10.42.1.182 |
| worker-2 | 3.71.181.214 | 10.42.1.56 |

- **App (NLB):** http://devops-exam-nlb-24ed18fcdecb3ba1.elb.eu-central-1.amazonaws.com
- NodePort debug: `http://<node-ip>:30080`
- SSH: `ssh -i ~/.ssh/devops-exam ubuntu@<public-ip>`
- Kubeconfig: `ansible/files/kubeconfig`

## Local platform

| Service | URL |
|---------|-----|
| Jenkins | https://jenkins.iba-expert.uk/ |
| Folder | https://jenkins.iba-expert.uk/job/devops-exam-app/ |
| LAN (optional) | http://192.168.32.70:8080 |
| Prometheus | http://192.168.32.80:9090 |
| Grafana | http://192.168.32.80:3000 |
| Alertmanager | http://192.168.32.80:9093 |
| Loki | http://192.168.32.80:3100 (local) / cluster NodePort http://52.59.86.56:31000 |

## CI/CD branches

| Branch | Trigger | Deploy |
|--------|---------|--------|
| `develop` | automatic on push | yes (after green tests) |
| `main` | **manual** Build in Jenkins | yes (after green tests) |

## GitHub

- https://github.com/SergiiPovzaniuk/devops-exam-app
- https://github.com/SergiiPovzaniuk/devops-exam-infra
- Fork: https://github.com/SergiiPovzaniuk/simple-java-maven-app

## Demo

```bash
./scripts/demo_curl.sh "$(cd terraform/envs/exam && terraform output -raw app_url)"
```

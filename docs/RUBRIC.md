# Rubric checklist

## Mandatory

| Item | Evidence |
|------|----------|
| GIT | Commits by Sergii Povzaniuk in both repos |
| GitHub | `devops-exam-app`, `devops-exam-infra`, fork `simple-java-maven-app` |
| Terraform | `terraform/` modules + envs, reusable |
| AWS EC2 | 3x t3.small kubeadm, SG + key |
| Ubuntu + firewall | Ansible UFW role |
| Docker | App Dockerfile, networks/volumes via K8s/runtime |
| Docker Hub | `sergejpovzaniuk/devops-exam-app` |
| CI Jenkins | Folder `devops-exam-app`, stages, any-branch publish |
| CD Jenkins | `main` deploy + email notify |
| Docs | READMEs + this checklist |

## Optional

| Item | Evidence |
|------|----------|
| TF state S3 | `terraform/bootstrap` |
| Kubernetes | kubeadm 3-node |
| Jenkins agent | JCasC `exam-agent` |
| Jenkins CasC | `jenkins/casc/` |
| Ansible | `ansible/playbooks/site.yml` |
| Prometheus | `monitoring/prometheus/` |
| Grafana | dashboard + datasources |
| Alertmanager | `monitoring/alertmanager/` |
| Loki | promtail config |
| Unit tests | `devops-exam-app/tests` |
| Domain + SSL (optional) | Free path: cert-manager + nip.io on NodePort/Ingress if public HTTP works — see `docs/SSL.md` |
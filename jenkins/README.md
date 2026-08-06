# Jenkins

```bash
python jenkins/scripts/setup_jenkins.py
python jenkins/scripts/setup_webhook.py   # GitHub → Jenkins webhook
```

## Webhook (required for auto develop builds)

Jenkins public URL: **https://jenkins.iba-expert.uk/**

```text
GitHub push/PR → https://jenkins.iba-expert.uk/github-webhook/ → Multibranch
```

| Event | Effect |
|-------|--------|
| `push` to `develop` | Multibranch builds automatically |
| `push` to `main` | No auto-build (`NoTriggerBranchProperty`) |
| `pull_request` | Delivered; branch filter still applies |

```bash
python jenkins/scripts/setup_webhook.py
```

Optional LAN relay (only if public HTTPS is down): `install_smee_relay.sh`

## App — `devops-exam-app/pipeline`

| Branch | SCM trigger | Deploy |
|--------|-------------|--------|
| develop | **GitHub webhook** (push) | after green tests |
| main | manual Build only | after green tests |

## Infra destroy — `devops-exam-infra/destroy`

Manual only. Pipeline script: [`Jenkinsfile.destroy`](../Jenkinsfile.destroy).

1. Open http://192.168.32.70:8080/job/devops-exam-infra/job/destroy/
2. **Build with Parameters**
3. Set `CONFIRM_DESTROY=true`
4. Optional: `DESTROY_BOOTSTRAP=true` (S3 state + lock table)

Credentials: `github-token`, `dockerhub`, `kubeconfig-exam`, `aws-exam`.

# Jenkins

```bash
python jenkins/scripts/setup_jenkins.py
python jenkins/scripts/setup_webhook.py   # GitHub → Jenkins webhook
```

## Webhook (required for auto develop builds)

Flow:

```text
GitHub push/PR → https://smee.io/MKMit7OMtF4nBA7k → smee container on Jenkins host → http://127.0.0.1:8080/github-webhook/
```

(Direct public `46.174.75.130:8888` is not reachable from the internet; Smee relays events into the LAN.)

| Event | Effect |
|-------|--------|
| `push` to `develop` | Multibranch builds automatically |
| `push` to `main` | No auto-build (`NoTriggerBranchProperty`) |
| `pull_request` | Delivered; branch filter still applies |

```bash
# on your PC (with GITHUB_TOKEN)
python jenkins/scripts/setup_webhook.py

# on Jenkins host once
bash jenkins/scripts/install_smee_relay.sh
# or: ssh user@192.168.32.70 '...'
```

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

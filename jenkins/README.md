# Jenkins

```bash
python jenkins/scripts/setup_jenkins.py
```

Creates folder `devops-exam-app` / Multibranch `pipeline`.

| Branch | SCM trigger | Deploy |
|--------|-------------|--------|
| develop | automatic | after green tests |
| main | suppressed (`NoTriggerBranchProperty`) — Build Now only | after green tests |

Credentials: `github-token`, `dockerhub`, `kubeconfig-exam`.

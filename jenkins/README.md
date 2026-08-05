# Jenkins

```bash
python jenkins/scripts/setup_jenkins.py
```

## App — `devops-exam-app/pipeline`

| Branch | SCM trigger | Deploy |
|--------|-------------|--------|
| develop | automatic | after green tests |
| main | manual Build only | after green tests |

## Infra destroy — `devops-exam-infra/destroy`

Manual only. Pipeline script: [`Jenkinsfile.destroy`](../Jenkinsfile.destroy).

1. Open http://192.168.32.70:8080/job/devops-exam-infra/job/destroy/
2. **Build with Parameters**
3. Set `CONFIRM_DESTROY=true`
4. Optional: `DESTROY_BOOTSTRAP=true` (S3 state + lock table)

Credentials: `github-token`, `dockerhub`, `kubeconfig-exam`, `aws-exam`.

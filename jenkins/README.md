# Jenkins for devops-exam-app

## Folder

`devops-exam-app` / `pipeline` (Multibranch)

- Any branch: Test → Build → Publish (Docker Hub)
- `main`: also Deploy (kubectl)

## Credentials (IDs)

| ID | Type |
|----|------|
| `github-token` | Secret text |
| `dockerhub` | Username/password |
| `kubeconfig-exam` | Secret file |

## Agent

JCasC defines permanent agent label `exam docker` in `casc/jenkins.yaml`.
Attach a node with Docker + Python3 + kubectl, or run on built-in node with those tools.

## Apply jobs/creds

```bash
# from Windows with .env loaded
python jenkins/scripts/setup_jenkins.py
```

## CasC

Copy `casc/` into Jenkins CasC config path if CasC plugin is enabled.

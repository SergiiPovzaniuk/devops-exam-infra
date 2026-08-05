# Optional free SSL

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
# then Ingress + ClusterIssuer letsencrypt + host <cp-ip>.nip.io
```

Skipped by default to keep cost/complexity low; NodePort HTTP is enough for diploma demo.

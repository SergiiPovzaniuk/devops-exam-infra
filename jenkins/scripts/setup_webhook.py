#!/usr/bin/env python3
"""Point GitHub webhook at public Jenkins /github-webhook/."""
import json
import os
import urllib.error
import urllib.request

REPO = os.environ.get("GITHUB_REPO", "SergiiPovzaniuk/devops-exam-app")
TOKEN = os.environ["GITHUB_TOKEN"]
HOOK_URL = os.environ.get(
    "JENKINS_WEBHOOK_URL",
    "https://jenkins.iba-expert.uk/github-webhook/",
)


def api(method, path, data=None):
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        data=None if data is None else json.dumps(data).encode(),
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "devops-exam-setup",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read().decode()
            return r.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def main():
    payload = {
        "name": "web",
        "active": True,
        "events": ["push", "pull_request"],
        "config": {
            "url": HOOK_URL,
            "content_type": "json",
            "insecure_ssl": "0",
        },
    }
    status, hooks = api("GET", f"/repos/{REPO}/hooks")
    if status != 200:
        raise SystemExit(f"list hooks failed: {status} {hooks}")

    existing = None
    for h in hooks:
        cfg_url = h.get("config", {}).get("url", "")
        if "github-webhook" in cfg_url or "smee.io" in cfg_url or cfg_url == HOOK_URL:
            existing = h
            break

    if existing:
        status, _ = api("PATCH", f"/repos/{REPO}/hooks/{existing['id']}", payload)
        print("updated", existing["id"], status, HOOK_URL)
    else:
        status, _ = api("POST", f"/repos/{REPO}/hooks", payload)
        print("created", status, HOOK_URL)

    _, hooks = api("GET", f"/repos/{REPO}/hooks")
    for h in hooks:
        print(h["id"], h["config"].get("url"), h.get("events"), h.get("last_response"))


if __name__ == "__main__":
    main()

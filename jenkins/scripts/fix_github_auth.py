#!/usr/bin/env python3
import base64
import http.cookiejar
import json
import os
import urllib.parse
import urllib.request

J = os.environ["JENKINS_HOST"].rstrip("/")
U = os.environ["JENKINS_USER"]
P = os.environ["JENKINS_PASSWORD"]
GH = os.environ["GITHUB_TOKEN"]

cj = http.cookiejar.CookieJar()
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def auth():
    return {"Authorization": "Basic " + base64.b64encode(f"{U}:{P}".encode()).decode()}


def crumb():
    req = urllib.request.Request(f"{J}/crumbIssuer/api/json", headers=auth())
    with op.open(req, timeout=30) as r:
        d = json.load(r)
    return {d["crumbRequestField"]: d["crumb"]}


def script(groovy: str):
    h = auth()
    h.update(crumb())
    h["Content-Type"] = "application/x-www-form-urlencoded"
    body = f"script={urllib.parse.quote(groovy)}".encode()
    req = urllib.request.Request(f"{J}/scriptText", data=body, headers=h, method="POST")
    with op.open(req, timeout=60) as r:
        return r.read().decode()


groovy = f"""
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.github_branch_source.*
import org.jenkinsci.plugins.workflow.multibranch.*
import jenkins.branch.*
import hudson.util.Secret

def store = SystemCredentialsProvider.instance.store
def domain = Domain.global()
def id = 'github-token'
def existing = CredentialsProvider.lookupCredentials(Credentials.class, Jenkins.instance, null, null).find {{ it.id == id }}
if (existing != null) store.removeCredentials(domain, existing)
store.addCredentials(domain, new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL, id, 'GitHub PAT', 'SergiiPovzaniuk', '{GH}'
))

// Prefer ThrottleOnOver for GitHub API
try {{
  def ext = Jenkins.instance.getExtensionList(org.jenkinsci.plugins.github_branch_source.ApiRateLimitChecker.class)
  println 'rate checker present'
}} catch (Throwable t) {{
  println 'rate checker: ' + t.message
}}

def folder = Jenkins.instance.getItem('devops-exam-app')
def job = folder.getItem('pipeline')
def source = new GitHubSCMSource('SergiiPovzaniuk', 'devops-exam-app')
source.setCredentialsId('github-token')
source.setTraits([new BranchDiscoveryTrait(3)])
job.getSourcesList().clear()
job.getSourcesList().add(new BranchSource(source))
job.save()
Jenkins.instance.setNumExecutors(4)
Jenkins.instance.save()
println 'fixed-github-auth'
"""

print(script(groovy))

# stop current stuck builds
for n in range(1, 10):
    h = auth()
    h.update(crumb())
    req = urllib.request.Request(
        f"{J}/job/devops-exam-app/job/pipeline/job/main/{n}/stop",
        data=b"",
        headers=h,
        method="POST",
    )
    try:
        op.open(req, timeout=15).read()
    except Exception:
        pass

h = auth()
h.update(crumb())
req = urllib.request.Request(
    f"{J}/job/devops-exam-app/job/pipeline/job/main/build",
    data=b"",
    headers=h,
    method="POST",
)
print("rebuild", op.open(req, timeout=30).status)

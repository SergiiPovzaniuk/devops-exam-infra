#!/usr/bin/env python3
import base64
import http.cookiejar
import json
import os
import urllib.parse
import urllib.request

JENKINS = os.environ.get("JENKINS_HOST", "http://192.168.32.70:8080").rstrip("/")
USER = os.environ.get("JENKINS_USER", "admin")
PASS = os.environ.get("JENKINS_PASSWORD", "admin-change-me")
GH = os.environ.get("GITHUB_TOKEN", "")
DH_USER = os.environ.get("DOCKER_HUB_USERNAME", "sergejpovzaniuk")
DH_PASS = os.environ.get("DOCKER_HUB_ACCESS_TOKEN", "")
KUBECONFIG = os.environ.get(
    "KUBECONFIG_PATH",
    r"c:\Users\sergi\devops_diploma\devops-exam-infra\ansible\files\kubeconfig",
)

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def auth_header():
    return {
        "Authorization": "Basic "
        + base64.b64encode(f"{USER}:{PASS}".encode()).decode()
    }


def crumb():
    req = urllib.request.Request(f"{JENKINS}/crumbIssuer/api/json", headers=auth_header())
    with opener.open(req, timeout=30) as r:
        data = json.load(r)
    return {data["crumbRequestField"]: data["crumb"]}


def script(groovy):
    h = auth_header()
    h.update(crumb())
    h["Content-Type"] = "application/x-www-form-urlencoded"
    body = f"script={urllib.parse.quote(groovy)}".encode()
    req = urllib.request.Request(f"{JENKINS}/scriptText", data=body, headers=h, method="POST")
    with opener.open(req, timeout=120) as r:
        return r.read().decode()


def main():
    print(
        script(
            f"""
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
def store = SystemCredentialsProvider.instance.store
def domain = Domain.global()
def upsert = {{ id, cred ->
  def existing = CredentialsProvider.lookupCredentials(Credentials.class, Jenkins.instance, null, null).find {{ it.id == id }}
  if (existing != null) store.removeCredentials(domain, existing)
  store.addCredentials(domain, cred)
}}
upsert('github-token', new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'github-token', 'GitHub PAT', 'SergiiPovzaniuk', '{GH}'))
upsert('dockerhub', new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'dockerhub', 'Docker Hub', '{DH_USER}', '{DH_PASS}'))
println 'creds-ok'
"""
        )
    )

    if os.path.exists(KUBECONFIG):
        b64 = base64.b64encode(open(KUBECONFIG, "rb").read()).decode()
        print(
            script(
                f"""
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import com.cloudbees.plugins.credentials.SecretBytes
def store = SystemCredentialsProvider.instance.store
def domain = Domain.global()
def id='kubeconfig-exam'
def existing = CredentialsProvider.lookupCredentials(Credentials.class, Jenkins.instance, null, null).find {{ it.id == id }}
if (existing != null) store.removeCredentials(domain, existing)
store.addCredentials(domain, new FileCredentialsImpl(CredentialsScope.GLOBAL, id, 'exam kubeconfig', 'kubeconfig', SecretBytes.fromBytes(java.util.Base64.decoder.decode('{b64}'))))
println 'kube-ok'
"""
            )
        )

    print(
        script(
            r"""
import jenkins.model.*
import jenkins.branch.*
import org.jenkinsci.plugins.workflow.multibranch.*
import com.cloudbees.hudson.plugins.folder.*
import org.jenkinsci.plugins.github_branch_source.*

def folder = Jenkins.instance.getItem('devops-exam-app')
if (folder == null) {
  folder = Jenkins.instance.createProject(Folder.class, 'devops-exam-app')
  folder.description = 'CI/CD for devops-exam-app'
  folder.save()
}

def job = folder.getItem('pipeline')
if (job == null) {
  job = folder.createProject(WorkflowMultiBranchProject.class, 'pipeline')
}
job.displayName = 'pipeline'
job.description = 'develop: auto CI/CD on push. main: manual Build only.'

def source = new GitHubSCMSource('SergiiPovzaniuk', 'devops-exam-app')
source.setCredentialsId('github-token')
def traits = [
  new BranchDiscoveryTrait(3),
  new WildcardSCMHeadFilterTrait('main develop', '')
]
source.setTraits(traits)

def branchSource = new BranchSource(source)
def namedMain = new NamedExceptionsBranchPropertyStrategy.Named(
  'main',
  [new NoTriggerBranchProperty()] as BranchProperty[]
)
branchSource.setStrategy(new NamedExceptionsBranchPropertyStrategy(
  new BranchProperty[0],
  [namedMain] as NamedExceptionsBranchPropertyStrategy.Named[]
))

job.getSourcesList().clear()
job.getSourcesList().add(branchSource)
def factory = new WorkflowBranchProjectFactory()
factory.setScriptPath('Jenkinsfile')
job.setProjectFactory(factory)
job.save()

Jenkins.instance.setNumExecutors(Math.max(2, Jenkins.instance.numExecutors))
def labels = (Jenkins.instance.labelString ?: '')
if (!labels.contains('exam')) {
  Jenkins.instance.setLabelString((labels + ' exam docker').trim())
}
Jenkins.instance.save()

job.scheduleBuild2(0)
println 'job-ok develop=auto main=NoTrigger'
"""
        )
    )


if __name__ == "__main__":
    main()

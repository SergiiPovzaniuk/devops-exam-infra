#!/usr/bin/env python3
import base64
import http.cookiejar
import json
import os
import ssl
import urllib.error
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
    token = base64.b64encode(f"{USER}:{PASS}".encode()).decode()
    return {"Authorization": f"Basic {token}"}


def crumb():
    req = urllib.request.Request(f"{JENKINS}/crumbIssuer/api/json", headers=auth_header())
    with opener.open(req, timeout=30) as r:
        data = json.load(r)
    return {data["crumbRequestField"]: data["crumb"]}


def request(method, path, data=None, content_type=None):
    h = auth_header()
    h.update(crumb())
    if content_type:
        h["Content-Type"] = content_type
    body = data.encode() if isinstance(data, str) else data
    req = urllib.request.Request(f"{JENKINS}{path}", data=body, headers=h, method=method)
    try:
        with opener.open(req, timeout=60) as r:
            return r.status, r.read()[:200]
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:500]


def create_secret_text(cred_id, secret, description):
    xml = f"""<org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>{cred_id}</id>
  <description>{description}</description>
  <secret>{secret}</secret>
</org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>"""
    return request(
        "POST",
        "/credentials/store/system/domain/_/createCredentials",
        data=xml,
        content_type="application/xml",
    )


def create_username_password(cred_id, username, password, description):
    xml = f"""<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>{cred_id}</id>
  <description>{description}</description>
  <username>{username}</username>
  <password>{password}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>"""
    return request(
        "POST",
        "/credentials/store/system/domain/_/createCredentials",
        data=xml,
        content_type="application/xml",
    )


def create_file_credential(cred_id, path, description):
    with open(path, "rb") as f:
        content = f.read()
    # Jenkins FileCredentials expects secretBytes as base64 in some versions via stapler;
    # use groovy fallback if XML fails.
    b64 = base64.b64encode(content).decode()
    xml = f"""<org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>{cred_id}</id>
  <description>{description}</description>
  <fileName>kubeconfig</fileName>
  <secretBytes>{b64}</secretBytes>
</org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl>"""
    return request(
        "POST",
        "/credentials/store/system/domain/_/createCredentials",
        data=xml,
        content_type="application/xml",
    )


def script(groovy):
    return request(
        "POST",
        "/scriptText",
        data=f"script={urllib.parse.quote(groovy)}",
        content_type="application/x-www-form-urlencoded",
    )


def main():
    who = request("GET", "/whoAmI/api/json")
    print("whoAmI", who[0], who[1][:120])

    groovy_creds = f"""
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret

def store = SystemCredentialsProvider.instance.store
def domain = Domain.global()

def upsert = {{ id, cred ->
  def existing = CredentialsProvider.lookupCredentials(Credentials.class, Jenkins.instance, null, null).find {{ it.id == id }}
  if (existing != null) store.removeCredentials(domain, existing)
  store.addCredentials(domain, cred)
}}

upsert('github-token', new StringCredentialsImpl(CredentialsScope.GLOBAL, 'github-token', 'GitHub PAT', Secret.fromString('''{GH}''')))
upsert('dockerhub', new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'dockerhub', 'Docker Hub', '{DH_USER}', '{DH_PASS}'))
println 'creds-ok'
"""
    print("groovy creds", script(groovy_creds))

    if os.path.exists(KUBECONFIG):
        with open(KUBECONFIG, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        groovy_kube = f"""
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
def bytes = SecretBytes.fromBytes(java.util.Base64.decoder.decode('{b64}'))
store.addCredentials(domain, new FileCredentialsImpl(CredentialsScope.GLOBAL, id, 'exam kubeconfig', 'kubeconfig', bytes))
println 'kube-ok'
"""
        print("groovy kube", script(groovy_kube))

    groovy_jobs = r"""
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
job.description = 'Any branch: test/build/publish. main: also deploy.'

def source = new GitHubSCMSource('SergiiPovzaniuk', 'devops-exam-app')
source.setCredentialsId('github-token')
source.setTraits([new BranchDiscoveryTrait(3)])

def branchSource = new BranchSource(source)
job.getSourcesList().clear()
job.getSourcesList().add(branchSource)
def factory = new WorkflowBranchProjectFactory()
factory.setScriptPath('Jenkinsfile')
job.setProjectFactory(factory)
job.save()
job.scheduleBuild2(0)
println 'job-ok'
"""
    print("groovy jobs", script(groovy_jobs))


if __name__ == "__main__":
    main()

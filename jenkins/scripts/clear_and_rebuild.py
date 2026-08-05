#!/usr/bin/env python3
import base64
import http.cookiejar
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

J = os.environ["JENKINS_HOST"].rstrip("/")
U = os.environ["JENKINS_USER"]
P = os.environ["JENKINS_PASSWORD"]

cj = http.cookiejar.CookieJar()
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def auth():
    return {"Authorization": "Basic " + base64.b64encode(f"{U}:{P}".encode()).decode()}


def crumb():
    req = urllib.request.Request(f"{J}/crumbIssuer/api/json", headers=auth())
    with op.open(req, timeout=30) as r:
        d = json.load(r)
    return {d["crumbRequestField"]: d["crumb"]}


def get(path):
    req = urllib.request.Request(f"{J}{path}", headers=auth())
    with op.open(req, timeout=30) as r:
        return json.load(r)


def post(path):
    h = auth()
    h.update(crumb())
    req = urllib.request.Request(f"{J}{path}", data=b"", headers=h, method="POST")
    try:
        with op.open(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def script(groovy):
    h = auth()
    h.update(crumb())
    h["Content-Type"] = "application/x-www-form-urlencoded"
    body = f"script={urllib.parse.quote(groovy)}".encode()
    req = urllib.request.Request(f"{J}/scriptText", data=body, headers=h, method="POST")
    with op.open(req, timeout=60) as r:
        return r.read().decode()


for n in range(1, 20):
    post(f"/job/devops-exam-app/job/pipeline/job/main/{n}/kill")

q = get("/queue/api/json")
for item in q.get("items", []):
    print("cancel", item.get("id"), post(f"/queue/cancelItem?id={item['id']}"))

print(
    script(
        """
import jenkins.model.*
import hudson.model.*
Jenkins.instance.queue.clear()
Jenkins.instance.computers.each { c ->
  c.executors.each { e ->
    if (!e.idle) {
      println 'interrupt ' + e.currentExecutable
      e.interrupt(Result.ABORTED)
    }
  }
}
Jenkins.instance.setNumExecutors(4)
Jenkins.instance.save()
println 'cleared executors=' + Jenkins.instance.numExecutors
"""
    )
)

time.sleep(5)
print("rebuild", post("/job/devops-exam-app/job/pipeline/job/main/build"))
time.sleep(10)
b = get("/job/devops-exam-app/job/pipeline/job/main/lastBuild/api/json")
print("last", b["number"], "building", b["building"], "result", b.get("result"))

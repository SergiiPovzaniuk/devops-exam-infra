#!/usr/bin/env bash
set -euo pipefail
JENKINS_URL="${JENKINS_HOST:-http://192.168.32.70:8080}"
USER="${JENKINS_USER:-admin}"
PASS="${JENKINS_PASSWORD:-admin-change-me}"

crumb=$(curl -s -u "$USER:$PASS" "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")
auth=(-u "$USER:$PASS" -H "$crumb")

curl -s "${auth[@]}" -X POST "$JENKINS_URL/createItem?name=devops-exam-app&mode=com.cloudbees.hudson.plugins.folder.Folder" \
  -H "Content-Type: application/x-www-form-urlencoded" || true

cat > /tmp/mb-config.xml <<'XML'
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject plugin="workflow-multibranch">
  <actions/>
  <description>Any branch: test/build/publish. main: also deploy.</description>
  <displayName>pipeline</displayName>
  <properties/>
  <folderViews class="jenkins.branch.MultiBranchProjectViewHolder" plugin="branch-api"/>
  <healthMetrics/>
  <icon class="jenkins.branch.MetadataActionFolderIcon" plugin="branch-api"/>
  <sources class="jenkins.branch.MultiBranchProject$BranchSourceList" plugin="branch-api">
    <data>
      <jenkins.branch.BranchSource>
        <source class="org.jenkinsci.plugins.github_branch_source.GitHubSCMSource" plugin="github-branch-source">
          <id>devops-exam-app</id>
          <credentialsId>github-token</credentialsId>
          <repoOwner>SergiiPovzaniuk</repoOwner>
          <repository>devops-exam-app</repository>
          <repositoryUrl>https://github.com/SergiiPovzaniuk/devops-exam-app.git</repositoryUrl>
          <configuredByUrl>true</configuredByUrl>
          <traits>
            <org.jenkinsci.plugins.github__branch__source.BranchDiscoveryTrait>
              <strategyId>3</strategyId>
            </org.jenkinsci.plugins.github__branch__source.BranchDiscoveryTrait>
          </traits>
        </source>
        <strategy class="jenkins.branch.DefaultBranchPropertyStrategy">
          <properties class="empty-list"/>
        </strategy>
      </jenkins.branch.BranchSource>
    </data>
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </sources>
  <factory class="org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
    <scriptPath>Jenkinsfile</scriptPath>
  </factory>
  <orphanItemStrategy class="com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy" plugin="cloudbees-folder">
    <pruneDeadBranches>true</pruneDeadBranches>
    <daysToKeep>-1</daysToKeep>
    <numToKeep>10</numToKeep>
  </orphanItemStrategy>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
XML

curl -s "${auth[@]}" -X POST "$JENKINS_URL/job/devops-exam-app/createItem?name=pipeline" \
  -H "Content-Type: application/xml" \
  --data-binary @/tmp/mb-config.xml

curl -s "${auth[@]}" -X POST "$JENKINS_URL/job/devops-exam-app/job/pipeline/build" || true
echo "Created folder devops-exam-app / pipeline"
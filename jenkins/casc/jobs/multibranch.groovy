multibranchPipelineJob('devops-exam-app/pipeline') {
  displayName('pipeline')
  description('Any branch: test/build/publish. main: also deploy.')
  branchSources {
    branchSource {
      source {
        github {
          id('devops-exam-app')
          repoOwner('SergiiPovzaniuk')
          repository('devops-exam-app')
          repositoryUrl('https://github.com/SergiiPovzaniuk/devops-exam-app.git')
          configuredByUrl(true)
          credentialsId('github-token')
          traits {
            gitHubBranchDiscovery {
              strategyId(3)
            }
            gitHubPullRequestDiscovery {
              strategyId(2)
            }
          }
        }
      }
    }
  }
  orphanedItemStrategy {
    discardOldItems {
      numToKeep(10)
    }
  }
  factory {
    workflowBranchProjectFactory {
      scriptPath('Jenkinsfile')
    }
  }
}
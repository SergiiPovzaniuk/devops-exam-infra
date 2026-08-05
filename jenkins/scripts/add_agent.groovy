import jenkins.model.*
import hudson.model.*
import hudson.slaves.*
import hudson.plugins.sshslaves.*
import hudson.plugins.sshslaves.verifiers.*

// Documents intended permanent agent. Prefer built-in node with labels if SSH plugin/agent host differs.
def name = 'exam-agent'
def jenkins = Jenkins.instance
if (jenkins.getNode(name) == null) {
  def launcher = new JNLPLauncher(true)
  def node = new DumbSlave(name, '/home/jenkins/agent', launcher)
  node.setNumExecutors(2)
  node.setLabelString('exam docker')
  node.setMode(Node.Mode.NORMAL)
  node.setRetentionStrategy(new RetentionStrategy.Always())
  jenkins.addNode(node)
  println "added ${name}"
} else {
  println "exists ${name}"
}

output "control_plane_public_ip" {
  value = module.control_plane.public_ip
}

output "control_plane_private_ip" {
  value = module.control_plane.private_ip
}

output "worker_public_ips" {
  value = [for w in module.worker : w.public_ip]
}

output "worker_private_ips" {
  value = [for w in module.worker : w.private_ip]
}

output "ssh_user" {
  value = "ubuntu"
}

output "lb_dns_name" {
  value = aws_lb.app.dns_name
}

output "app_url" {
  value = "http://${aws_lb.app.dns_name}"
}

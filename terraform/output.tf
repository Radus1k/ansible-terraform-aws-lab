output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Elastic IP attached to the app instance"
  value       = aws_eip.app.public_ip
}

output "ssh_command" {
  description = "Ready-to-paste SSH command"
  value       = "ssh ubuntu@${aws_eip.app.public_ip}"
}

output "app_url" {
  value = "http://${aws_eip.app.public_ip}"
}

# Consumed by the static-inventory fallback (make inventory-static).
# The preferred path is the aws_ec2 dynamic inventory plugin.
output "ansible_inventory" {
  description = "JSON blob Ansible can read as a static inventory"
  value = jsonencode({
    app = {
      hosts = {
        (aws_eip.app.public_ip) = {
          ansible_user               = "ubuntu"
          ansible_python_interpreter = "/usr/bin/python3"
        }
      }
    }
  })
}
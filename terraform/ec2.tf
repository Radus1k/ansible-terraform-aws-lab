# ---------------------------------------------------------------------------
# Compute. No AMI ID is hardcoded: we query Canonical's account for the newest
# Ubuntu 22.04 image. Hardcoded AMIs are region-specific and go stale.
# ---------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.admin.key_name
  iam_instance_profile   = aws_iam_instance_profile.app.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only - blocks SSRF-based credential theft
    http_endpoint = "enabled"
  }

  # Deliberately minimal. Everything else is Ansible's job.
  # Mixing user_data provisioning with config management gives you two
  # sources of truth for the same box.
  user_data = <<-EOT
    #!/bin/bash
    set -eux
    apt-get update -y
    apt-get install -y python3 python3-apt
  EOT

  # If the AMI updates, don't silently recreate the box on the next apply.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${local.name_prefix}-app-01"
    Role = "app" # <-- the contract with Ansible dynamic inventory
    OS   = "ubuntu2204"
  }
}

# A stable address that survives stop/start and instance replacement.
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-app-eip"
  }

  depends_on = [aws_internet_gateway.main]
}
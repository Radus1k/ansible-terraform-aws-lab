# ---------------------------------------------------------------------------
# Networking: VPC -> IGW -> public subnet -> route table -> security group
# Deliberately hand-rolled instead of using the terraform-aws-modules/vpc
# module, because the point here is to understand what the module does.
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required if you ever want private DNS / EFS / RDS by name

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Pick the first AZ in the region rather than hardcoding "eu-central-1a"
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-a"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security group. Note the separate aws_vpc_security_group_*_rule resources:
# inline `ingress {}` blocks inside aws_security_group cause Terraform to fight
# with any rule added out-of-band. Separate rule resources are the current
# recommended pattern.
# ---------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Allow SSH from admin, HTTP/HTTPS from the world"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH for Ansible"
  cidr_ipv4         = var.restrict_ssh_to_my_ip ? local.my_cidr : "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP"
  cidr_ipv4         = var.allow_http_from
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS"
  cidr_ipv4         = var.allow_http_from
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound (apt, docker pull)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
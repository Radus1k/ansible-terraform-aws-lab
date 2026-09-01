variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Short project identifier; used in names and tags"
  type        = string
  default     = "tf-ansible-lab"
}

variable "environment" {
  description = "Deployment environment (dev/stage/prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "owner" {
  description = "Tag value identifying who owns these resources"
  type        = string
  default     = "sica"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro is free-tier eligible in most regions)"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Path to the SSH public key uploaded to AWS"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allow_http_from" {
  description = "CIDR allowed to reach ports 80/443"
  type        = string
  default     = "0.0.0.0/0"
}

variable "restrict_ssh_to_my_ip" {
  description = "If true, SSH is only open to the IP running terraform apply"
  type        = bool
  default     = true
}
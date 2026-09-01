# ---------------------------------------------------------------------------
# BOOTSTRAP: creates the S3 bucket + DynamoDB table that hold Terraform state
# for the main stack. Run this ONCE, with local state, before ../terraform.
# Chicken-and-egg: the backend can't create its own backend.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  # e.g. "tfstate-marius-lab-4f2a"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Safety net: prevents `terraform destroy` from nuking your state store.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = var.state_bucket_name
    Purpose   = "terraform-remote-state"
    ManagedBy = "terraform"
  }
}

# State files contain plaintext secrets (DB passwords, keys). Always version + encrypt.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Distributed lock: stops two people (or two CI jobs) applying at once.
resource "aws_dynamodb_table" "tflock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Purpose   = "terraform-state-locking"
    ManagedBy = "terraform"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.id
}

output "lock_table" {
  value = aws_dynamodb_table.tflock.name
}

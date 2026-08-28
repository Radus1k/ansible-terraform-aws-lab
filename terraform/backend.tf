# ---------------------------------------------------------------------------
# Remote state. Values here CANNOT be interpolated (no variables allowed),
# so they're supplied at init time from backend.hcl:
#   terraform init -backend-config=backend.hcl
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {
    key            = "tf-ansible-lab/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    # bucket + region come from backend.hcl
  }
}
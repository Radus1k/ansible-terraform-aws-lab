# Terraform + Ansible + AWS hands-on lab

Terraform builds the infrastructure. Ansible configures what runs on it.
The two never talk directly — they meet at **EC2 tags**.

## Layout

```
.
├── bootstrap/          # one-time: S3 state bucket + DynamoDB lock table
├── terraform/          # VPC, subnet, IGW, SG, IAM, EC2, EIP
├── ansible/
│   ├── inventory/aws_ec2.yml     # dynamic inventory (queries the EC2 API)
│   ├── group_vars/all/           # non-secret vars + vault example
│   ├── playbook.yml
│   └── roles/{docker,app_deploy}
└── Makefile
```

## What you must supply from your own AWS account

| Thing | Where it goes | Notes |
|---|---|---|
| **AWS credentials** | `aws configure` / `AWS_PROFILE` / env vars | The identity needs to create VPC, EC2, EIP, IAM role+policy, S3, DynamoDB. An admin user or `PowerUserAccess` + `IAMFullAccess` is enough for a lab. |
| **Region** | `terraform/terraform.tfvars`, `bootstrap/terraform.tfvars`, `ansible/inventory/aws_ec2.yml`, `terraform/backend.hcl` | Must be the **same** in all four. Default is `eu-north-1`. |
| **SSH keypair** | `~/.ssh/id_ed25519{,.pub}` | `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519`. Only the `.pub` is uploaded (`public_key_path`). |
| **Globally-unique S3 bucket name** | `bootstrap/terraform.tfvars` → `state_bucket_name`, then the same value in `terraform/backend.hcl` | S3 bucket names are global across all AWS accounts — add something random. |
| **Your project/owner tags** | `terraform/terraform.tfvars` (`project_name`, `owner`, `environment`) | If you change `project_name` or `environment`, update the matching `filters:` in `ansible/inventory/aws_ec2.yml` — that tag match is the Terraform↔Ansible contract. |

### Local tooling

- Terraform ≥ 1.6
- Ansible (core ≥ 2.16) + `ansible-lint` (optional, used by `make fmt`)
- **Python** `boto3` and `botocore` — required by the dynamic inventory:
  `pip install boto3 botocore`
- AWS CLI (optional but handy): `pip install awscli` or the bundled installer
- The Ansible collections in `ansible/requirements.yml` — installed by `make deps`

## Run order

```bash
# 0. one-time state backend
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars   # set state_bucket_name + region
make bootstrap

cp terraform/backend.hcl.example      terraform/backend.hcl        # same bucket name + region
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # set owner, key path, region

# 1. infrastructure
make init
make plan
make apply

# 2. configuration
make deps          # install amazon.aws + community.docker
make ping          # proves inventory + SSH work
make configure

# 3. check
curl "$(terraform -chdir=terraform output -raw app_url)"

# ...or do 1+2 in one shot:
make up

# 4. clean up (avoid EIP charges)
make destroy
```

If you keep secrets in `ansible/group_vars/all/vault.yml` (see `vault.yml.example`),
add `--ask-vault-pass` to the `configure`/`deploy` invocations.

## What gets deployed

`role: docker` installs Docker Engine from the upstream apt repo (idempotently).
`role: app_deploy` runs two containers on a shared user-defined network:

- `demo-app` — `traefik/whoami` (swap `app_image` in `group_vars/all/main.yml`)
- `reverse-proxy` — `nginx:alpine`, publishing port 80 on the host, proxying to the app

## The two-run test

Run `make configure` twice. The second run must report `changed=0`.
If it doesn't, a task isn't idempotent — that's the single most useful
exercise in this whole project.

## Cost

t3.micro + 20 GB gp3 + one attached EIP ≈ free tier.
An **unattached** EIP is billed hourly — always `make destroy`.
The bootstrap S3 bucket and DynamoDB table are pay-per-use and effectively free;
they survive `make destroy` on purpose.

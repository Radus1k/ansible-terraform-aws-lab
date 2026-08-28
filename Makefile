# ---------------------------------------------------------------------------
# One entrypoint for the whole lifecycle. In a real team this becomes the
# CI pipeline; keeping it in a Makefile first means the pipeline is just
# "run the same targets a human runs".
# ---------------------------------------------------------------------------

TF      := terraform -chdir=terraform
ANSIBLE := ansible-playbook
export ANSIBLE_CONFIG := ansible/ansible.cfg

.DEFAULT_GOAL := help
.PHONY: help bootstrap init fmt validate plan apply deps ping inventory configure deploy up destroy clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## One-time: create S3 state bucket + DynamoDB lock table
	cd bootstrap && terraform init && terraform apply

init: ## terraform init with the S3 backend
	$(TF) init -backend-config=backend.hcl

fmt: ## Format and lint
	$(TF) fmt -recursive
	ansible-lint ansible/ || true

validate: ## Static checks
	$(TF) validate
	$(ANSIBLE) --syntax-check ansible/playbook.yml

plan: ## Show the execution plan
	$(TF) plan -out=tfplan

apply: ## Apply the saved plan
	$(TF) apply tfplan

deps: ## Install required Ansible collections
	ansible-galaxy collection install -r ansible/requirements.yml

ping: ## Prove dynamic inventory + SSH work
	ansible -i ansible/inventory/aws_ec2.yml role_app -m ping

inventory: ## Dump what the dynamic inventory currently sees
	ansible-inventory -i ansible/inventory/aws_ec2.yml --graph --vars

configure: ## Run the full playbook
	$(ANSIBLE) ansible/playbook.yml

deploy: ## Re-run only the deployment tasks
	$(ANSIBLE) ansible/playbook.yml --tags deploy

up: init plan apply deps configure ## Full provision + configure
	@echo "App URL: $$($(TF) output -raw app_url)"

destroy: ## Tear everything down (bootstrap bucket survives)
	$(TF) destroy

clean: ## Remove local artefacts
	rm -f terraform/tfplan
	rm -rf /tmp/ansible_ec2_inventory_cache
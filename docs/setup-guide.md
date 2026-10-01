# Setup guide

## Prerequisites

- An AWS account and AWS CLI v2, with admin credentials for the first bootstrap
- Terraform 1.10 or later
- Docker
- A GitHub repository with this code

## 1. Run locally

```bash
docker compose up --build -d
API_URL=http://127.0.0.1:8000 API_KEY=local-dev-key scripts/smoke-test.sh
```

API docs are at http://127.0.0.1:8000/docs.

To run the tests (needs [uv](https://docs.astral.sh/uv/)):

```bash
docker compose exec db psql -U banking -c "CREATE DATABASE banking_test"
cd app && DB_PASSWORD=banking-local-only uv run pytest
```

## 2. Bootstrap

This creates the Terraform state bucket and the IAM roles GitHub Actions uses. Run it once, from your machine:

```bash
cd infra/bootstrap
terraform init
terraform apply -var github_repo=<owner>/<repo>
```

If the account already has the GitHub OIDC provider, add `-var create_oidc_provider=false`.

## 3. Configure GitHub

1. Create two environments, `infra` and `production`, and add yourself as a required reviewer on both. These are the manual approval steps for Terraform apply and for app deploys.
2. Add these repository variables (Settings → Secrets and variables → Actions → Variables):

| Variable | Value |
|---|---|
| `AWS_REGION` | e.g. `us-east-1` |
| `TF_STATE_BUCKET` | bootstrap output `state_bucket` |
| `TF_STATE_KMS_KEY_ARN` | bootstrap output `state_kms_key_arn` |
| `AWS_TF_PLAN_ROLE_ARN` | bootstrap output `terraform_plan_role_arn` |
| `AWS_TF_APPLY_ROLE_ARN` | bootstrap output `terraform_apply_role_arn` |
| `ALERT_EMAIL` | email address for alarm notifications |
| `AWS_APP_BUILD_ROLE_ARN` | `terraform output github_app_build_role_arn`, after step 4 |
| `AWS_APP_DEPLOY_ROLE_ARN` | `terraform output github_app_deploy_role_arn`, after step 4 |

## 4. Create the infrastructure

Run the `terraform` workflow (Actions → terraform → Run workflow), review the plan in the job summary and approve the `infra` deployment. The first run takes about 15 minutes, mostly RDS.

Then set `AWS_APP_BUILD_ROLE_ARN` and `AWS_APP_DEPLOY_ROLE_ARN` from the Terraform outputs, and confirm the SNS subscription email AWS sends to `ALERT_EMAIL`.

Later changes under `infra/` run the same workflow: the plan is posted on the pull request, and merging to `main` plans again and waits for approval before applying.

To run Terraform from your machine instead of the workflow:

```bash
cd infra/envs/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply
```

Fill in `backend.hcl` from the bootstrap outputs, and `terraform.tfvars` with your values.

## 5. Deploy the app

Push a change under `app/` to `main`, or run the `deploy` workflow manually. It runs validation, builds and pushes the image, then waits for your approval on `production` before deploying and running the smoke test.

The infrastructure must exist first, because the image is pushed to the ECR repository Terraform creates.

## 6. Test

```bash
cd infra/envs/dev
API_URL=$(terraform output -raw api_url)
API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw api_client_key_secret_arn)" \
  --query SecretString --output text)

curl -k -X POST "$API_URL/v1/accounts" -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" -d '{"owner_name": "Jane Doe"}'

curl -k -X POST "$API_URL/v1/accounts/<id>/deposit" -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" -d '{"amount": "250.00"}'

curl -k -X POST "$API_URL/v1/accounts/<id>/withdraw" -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" -d '{"amount": "75.50"}'

curl -k "$API_URL/v1/accounts/<id>/balance" -H "X-API-Key: $API_KEY"
```

`-k` is needed only while the ALB uses the self-signed certificate, which it does when no `domain_name` is set.

The CloudWatch dashboard URL is in `terraform output dashboard_url`.

## 7. Clean up

```bash
cd infra/envs/dev && terraform destroy
```

To also remove the bootstrap resources, empty the state bucket, then run `terraform destroy` in `infra/bootstrap`.

# Banking API on AWS

A REST API for bank accounts (balance, deposit, withdraw), deployed to AWS with Terraform and GitHub Actions.

- `app/`: FastAPI service, tests, Alembic migrations, Dockerfile
- `infra/bootstrap/`: Terraform state bucket and GitHub OIDC roles
- `infra/modules/`: network, ALB/WAF, ECS, RDS, ECR, KMS, monitoring, audit
- `infra/envs/dev/`: dev environment
- `.github/workflows/`: `validation.yaml`, `build.yaml`, `deploy.yaml` (validation → build → deploy with manual approval), `terraform.yaml` (runs on infra changes)

## Run locally

```bash
docker compose up --build -d
curl -X POST http://127.0.0.1:8000/v1/accounts \
  -H "X-API-Key: local-dev-key" -H "Content-Type: application/json" \
  -d '{"owner_name": "Jane Doe"}'
```

## Docs

- [Architecture](docs/architecture.md)
- [Setup guide](docs/setup-guide.md)

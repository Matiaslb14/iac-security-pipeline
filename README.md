# IaC Security Pipeline (Terraform + GitHub Actions + Checkov + TFLint)

![Pipeline](https://img.shields.io/badge/IaC%20Security-Checkov%20%2B%20TFLint-blue)

> Shift‑left security for Terraform: fmt/validate, lint, and security scan on every push/PR.

## What this repo shows
- **Terraform formatting & validation** (no backend required).
- **Linting** with **TFLint** for common Terraform anti‑patterns.
- **Security scanning** with **Checkov** (fails the build on high‑severity issues).
- **SARIF** upload so findings appear in the GitHub **Security** tab.

## Quick start
1. **Use this template** or push this folder to a new GitHub repository.
2. Open a PR. The workflow will run **fmt**, **validate**, **tflint**, and **checkov** automatically.
3. Start with the sample `main.tf`. It contains a few *intentional* misconfigs (commented) to demo the pipeline.

> This repo does **not** deploy anything and does **not** require AWS credentials.

## Repo structure
```
.
├── .github/workflows/iac-security.yml
├── .tflint.hcl
├── .pre-commit-config.yaml
├── main.tf
├── variables.tf
└── README.md
```

## Badges (replace `YOUR_ORG/YOUR_REPO`)
```
![CI](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/iac-security.yml/badge.svg)
```

## Local dev (optional)
```bash
# Terraform checks (no backend)
terraform -version
terraform fmt -recursive
terraform init -backend=false
terraform validate

# TFLint
tflint --init
tflint

# Checkov
pip install checkov
checkov -d . --quiet
```

## Notes
- The workflow **fails** on Checkov high/critical findings. Tune this behavior with `CHECKOV_HARD_FAIL_ON` in the workflow file.
- Add more policies, e.g., tfsec or OPA/Conftest, if you want.

---

### Español (resumen)
Pipeline DevSecOps de IaC con **Terraform + TFLint + Checkov** en GitHub Actions. Valida formato, lint y seguridad en cada push/PR. **No requiere AWS** ni despliegue.

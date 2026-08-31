# Security Hardening Checklist



Final review performed at the end of the project build, verifying consistency and least-privilege design across all components.



## Identity & Access Management

- [x] RBAC roles reviewed at rg-workload-environment scope - exactly 2 Reader assignments, no broader roles present

- [x] No Owner or Contributor roles assigned to SG-SecurityReviewers or mi-workload-identity

- [x] Confirmed via `--all` flag that no hidden subscription-level role assignments exist for the Managed Identity

- [x] SG-SecurityReviewers is security-enabled (usable for RBAC), not a mail-enabled distribution group

- [x] No long-lived credentials created anywhere in the project - Managed Identity used exclusively for workload access



## MFA & Identity Protection

- [x] Microsoft Entra Security Defaults confirmed enabled (tenant-wide MFA enforcement)

- [x] Real MFA enforcement observed and handled correctly during a CLI re-authentication event



## Resource Hygiene

- [x] rg-workload-environment contains no orphaned resources

- [x] rg-cross-account-iam-security contains only the intended Managed Identity

- [x] Six unused legacy resource groups identified and deleted early in the project

- [x] Log Analytics Workspace deleted after monitoring evidence was captured, to control cost



## Infrastructure as Code

- [x] All manually-created resources successfully imported into Terraform state

- [x] `terraform plan` confirms zero drift between code and live environment

- [x] `terraform.tfstate` and `terraform.tfvars` correctly excluded from version control

- [x] `.terraform.lock.hcl` correctly included in version control for reproducible provider versions



## CI/CD Security

- [x] GitHub Actions pipeline runs Terraform format check, validate, and tfsec security scan on every push/PR

- [x] Pipeline correctly failed on an initial formatting issue, proving it functions as a real gate, not a formality

- [x] Fix verified locally before pushing, then confirmed passing in CI



## Source Control

- [x] Branch protection enabled on main (pull request required before merging)

- [x] No secrets, credentials, or private keys committed to the repository at any point

- [x] Sensitive CLI output (auth token claims) identified mid-project and handled with a credential rotation (az logout/az login)



## Known, Documented Limitations

- [x] Single-subscription simulation of the AWS project's multi-account boundary, documented in README

- [x] Entra PIM and Conditional Access evaluated but not deployed due to student-tier licensing constraints, documented honestly rather than omitted



## Sign-off

All checks above were manually verified via Azure CLI and Terraform output on the date of this review. No outstanding security findings remain open.



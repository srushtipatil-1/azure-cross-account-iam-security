# Azure Cross-Account IAM Security



A hands-on Azure security project translating an AWS cross-account IAM access pattern into Azure-native identity and access management, using Microsoft Entra ID, Azure RBAC, Managed Identity, and Terraform. The access controls are mapped to ISO/IEC 27001:2022, SOC 2, NIST CSF 2.0 and the Microsoft cloud security benchmark, and the access review is documented as an audit control test.



## Project Status

Complete — see [Known Limitations](#known-limitations) for the two scope boundaries not achievable on an Azure for Students subscription (documented, not left as open work), and [Results / Proof](#results--proof) for verification against the live subscription.



## What This Project Demonstrates

- Least-privilege access design using Azure RBAC, scoped to resource-group level

- Managed Identity for credential-free workload access (no secrets stored anywhere)

- Infrastructure as Code with Terraform, including importing pre-existing manually-created resources

- Security monitoring via Azure Activity Log

- Deliberate misconfiguration testing (over-privileged roles, overly broad scope) with detection and remediation

- Compliance mapping of 10 controls to ISO/IEC 27001:2022, SOC 2, NIST CSF 2.0 and the Microsoft cloud security benchmark, each linked to its evidence

- Access review written up as an audit workpaper (test of design, test of operating effectiveness, observations, conclusion)

- Honest documentation of licensing limitations on a student subscription (e.g., PIM, Conditional Access)



## Architecture

![Architecture Diagram](docs/images/architecture-diagram.png)

Two Resource Groups within a single subscription simulate the AWS project's separate Security and Workload accounts. Access flows from Entra ID identities into the workload boundary through explicit, least-privilege RBAC role assignments — never through a shared "admin" role.



## Prerequisites

- An Azure subscription (this project was built on Azure for Students)

- Azure CLI installed

- Terraform installed (v1.5.0+)

- Git installed

- A GitHub account



## Setup — Step by Step



### 1. Clone this repository

```bash

git clone https://github.com/srushtipatil-1/azure-cross-account-iam-security.git

cd azure-cross-account-iam-security

```



### 2. Authenticate to Azure

```bash

az login

az account show

```

Confirm the correct subscription appears before continuing.



### 3. Create the two Resource Groups (Security and Workload boundaries)

```bash

az group create --name rg-cross-account-iam-security --location centralindia

az group create --name rg-workload-environment --location centralindia

```



### 4. Create the Entra ID Security Group

```bash

az ad group create --display-name "SG-SecurityReviewers" --mail-nickname "SG-SecurityReviewers"

```



### 5. Create the User-Assigned Managed Identity

```bash

az identity create --name mi-workload-identity --resource-group rg-cross-account-iam-security --location centralindia

```



### 6. Assign least-privilege RBAC roles

Fetch the group's object ID and the identity's principal ID:

```bash

az ad group show --group "SG-SecurityReviewers" --query id --output tsv

az identity show --name mi-workload-identity --resource-group rg-cross-account-iam-security --query principalId --output tsv

```

Assign Reader to both, scoped to the workload resource group:

```bash

az role assignment create --assignee "<GROUP_ID>" --role "Reader" --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment"

az role assignment create --assignee "<PRINCIPAL_ID>" --role "Reader" --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment"

```



### 7. Manage the same infrastructure with Terraform

```bash

cd terraform

terraform init

```

Create a `terraform.tfvars` file (never committed to Git) containing:



subscription_id = "<SUBSCRIPTION_ID>"



Import each manually-created resource so Terraform manages it going forward:

```bash

terraform import azurerm_resource_group.security "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-cross-account-iam-security"

terraform import azurerm_resource_group.workload "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment"

terraform import azuread_group.security_reviewers "<GROUP_ID>"

terraform import azurerm_user_assigned_identity.workload_identity "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-cross-account-iam-security/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-workload-identity"

terraform import azurerm_role_assignment.reviewers_reader "<ROLE_ASSIGNMENT_ID_1>"

terraform import azurerm_role_assignment.identity_reader "<ROLE_ASSIGNMENT_ID_2>"

```

Confirm everything matches:

```bash

terraform plan

```

Expected result: `No changes. Your infrastructure matches the configuration.`



## Verifying the RBAC Design

```bash

az role assignment list --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment" --output table

```

Expected: exactly two Reader assignments, no broader roles.



## Security Testing Performed

- Simulated an over-privileged role assignment (Contributor added alongside Reader) — detected via role assignment audit, remediated

- Simulated overly broad scope (subscription-level instead of resource-group-level) — detected using the `--all` flag on role assignment queries, remediated

The full sign-off checklist for these tests and the rest of the security review is in [`docs/security-hardening-checklist.md`](docs/security-hardening-checklist.md).



### Reproducible Evidence (scripted)

Every stage below is scripted and its output is committed under [`docs/evidence/`](docs/evidence/). Re-run everything with `./scripts/run-evidence.sh`.

| Stage | Command | Evidence |
|---|---|---|
| Baseline | `scripts/audit-role-assignments.sh` | [01-baseline-audit.txt](docs/evidence/01-baseline-audit.txt) |
| Simulate | `scripts/simulate-overprivilege.sh`: Contributor on workload RG (managed identity); Reader at subscription scope (reviewers group) | [02-simulation.txt](docs/evidence/02-simulation.txt) |
| Detect | `scripts/audit-role-assignments.sh` exits 1 with 2 findings | [03-detection-audit.txt](docs/evidence/03-detection-audit.txt) |
| Terraform blind spot | `terraform plan` reports "No changes" while the violations exist, because out-of-band assignments are not in Terraform state. This is why a separate audit is needed. | [04-terraform-plan-blind-spot.txt](docs/evidence/04-terraform-plan-blind-spot.txt) |
| Remediate | `scripts/audit-role-assignments.sh --remediate` | [05-remediation.txt](docs/evidence/05-remediation.txt) |
| Verify | `scripts/audit-role-assignments.sh` returns COMPLIANT | [06-post-remediation-audit.txt](docs/evidence/06-post-remediation-audit.txt) |
| Activity Log | `scripts/export-activity-log.sh`: `roleAssignments/write` and `/delete` events, correlated with audit findings by role-assignment ID | [07-activity-log-role-events.json](docs/evidence/07-activity-log-role-events.json) |
| Managed identity effective access | `terraform apply -var enable_identity_test=true`: an ACI logs in as `mi-workload-identity` with no secret; read allowed, write denied, only the workload RG visible | [08-mi-access-test.log](docs/evidence/08-mi-access-test.log) |

Optional real-time detection: set `alert_email` in `terraform.tfvars` to deploy an Activity Log alert (`terraform/monitoring.tf`) that emails on any new role assignment.



## Compliance Mapping & Access Review

The same work, viewed the way a GRC or IT audit team would review it.

| Document | What it shows |
|---|---|
| [Control mapping](docs/compliance/control-mapping.md) | 10 controls (access, logging, change management) mapped to ISO/IEC 27001:2022 Annex A, SOC 2, NIST CSF 2.0 and the Microsoft cloud security benchmark, each linked to its evidence file; shared responsibility model and known gaps |
| [Access review workpaper](docs/compliance/access-review-workpaper.md) | The role-assignment audit tested as a control: test of design, operating effectiveness with seeded violations, Activity Log completeness check, observations and conclusion |

**Access review result (19 Oct 2026):** both seeded violations (Contributor on the workload RG; Reader at subscription scope) were detected, removed and re-verified as COMPLIANT within about 2 minutes. Each change is matched to its Activity Log `write` and `delete` event by role-assignment ID. Conclusion: **effective**.

| Control area | ISO/IEC 27001:2022 | SOC 2 | NIST CSF 2.0 |
|---|---|---|---|
| Least privilege and access review | A.5.15, A.5.18, A.8.2 | CC6.1–CC6.3 | PR.AA-05 |
| Workload identity without secrets | A.5.17, A.8.5 | CC6.1 | PR.AA-01 |
| Logging and alerting | A.8.15, A.8.16 | CC7.2 | PR.PS-04, DE.CM-03 |
| Change management (PR + CI gate) | A.8.32, A.8.4 | CC8.1 | PR.PS-01 |

> Partial, illustrative mapping for a lab environment. Control titles are paraphrased; this is not a certification or a claim of compliance.



## GitHub & CI/CD Security

- **Branch protection**: `main` requires a pull request before merging (no direct pushes).

- **CI/CD pipeline** (`.github/workflows/terraform-security.yml`) runs on every push/PR to `main`:
  1. `terraform fmt -check -recursive` — blocks on formatting drift.
  2. `terraform init` / `terraform validate` — blocks on invalid configuration.
  3. `tfsec` security scan, gated at `--minimum-severity HIGH` — blocks the run on any HIGH or CRITICAL finding; MEDIUM/LOW findings are reported in the log but do not fail the job.
- This is a real gate, not a formality: an early version of this repo had a Terraform formatting issue that the pipeline correctly failed on (see commit history — `Fix Terraform formatting to pass terraform fmt -check in CI pipeline`), and the fix was verified locally before being confirmed passing in CI.



## Results / Proof

**`terraform plan` — clean state, zero drift:**

```
$ terraform plan
azuread_group.security_reviewers: Refreshing state... [id=<GROUP_ID>]
azurerm_resource_group.workload: Refreshing state... [id=/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment]
azurerm_user_assigned_identity.workload_identity: Refreshing state... [id=/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-cross-account-iam-security/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-workload-identity]
azurerm_role_assignment.reviewers_reader: Refreshing state... [id=/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment/providers/Microsoft.Authorization/roleAssignments/<ROLE_ASSIGNMENT_ID>]
azurerm_role_assignment.identity_reader: Refreshing state... [id=/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment/providers/Microsoft.Authorization/roleAssignments/<ROLE_ASSIGNMENT_ID>]

No changes. Your infrastructure matches the configuration.
```

**Role assignment audit — exactly two Reader assignments, nothing broader:**

```
$ az role assignment list --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment" --output table
Principal                             Role    Scope
------------------------------------  ------  ------------------------------------------------------------------------------------------
SG-SecurityReviewers                  Reader  /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment
<mi-workload-identity principal id>   Reader  /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-workload-environment
```

**CI/CD pipeline**: see the [Actions tab](../../actions) for `terraform-security.yml` run history on `main`.

Both commands above were run directly against the live subscription on the date of this README update — not copied from documentation.

## Known Limitations

- This project uses a single Azure subscription (Azure for Students); two Resource Groups simulate the multi-account boundary from the original AWS design (this is why Multi-Subscription Access above is a documented limitation rather than a completed phase)

- Entra PIM and Conditional Access were evaluated but not deployed, as they require Entra ID P1/P2 licensing not included in this subscription tier



## Project Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | Orientation | Done |
| 2 | Azure Environment Setup | Done |
| 3 | Identity Architecture | Done |
| 4 | Multi-Subscription Access | Documented limitation — see [Known Limitations](#known-limitations) (single subscription on Azure for Students) |
| 5 | Azure RBAC | Done |
| 6 | Secure Identity | Done |
| 7 | Infrastructure as Code | Done |
| 8 | Security Monitoring | Done |
| 9 | Security Testing | Done |
| 10 | GitHub | Done — branch protection + PR-required workflow on `main` |
| 11 | CI/CD Security | Done — `tfsec` gate in `.github/workflows/terraform-security.yml`, see [GitHub & CI/CD Security](#github--cicd-security) |
| 12 | Security Hardening & Documentation | Done — see [`docs/security-hardening-checklist.md`](docs/security-hardening-checklist.md) and this README |
| 13 | Compliance Mapping & Audit Workpaper | Done — see [Compliance Mapping & Access Review](#compliance-mapping--access-review) |


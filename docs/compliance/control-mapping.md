# Control Mapping: Azure Least-Privilege Access

This page maps the work already done in this project to common security and compliance frameworks, and links each control to the evidence that proves it.

> Partial, illustrative mapping for a single-subscription lab (Azure for Students). Control titles are short paraphrases, not the standards' text. This is not a certification or a claim of compliance.

## Scope

| Item | In scope |
| --- | --- |
| Subscription | One Azure for Students subscription |
| Boundary | `rg-workload-environment` (workload) and `rg-cross-account-iam-security` (security/admin) |
| Identities | `SG-SecurityReviewers` (Entra ID security group), `mi-workload-identity` (user-assigned managed identity) |
| Approved baseline | Each identity holds exactly one `Reader` role, scoped to `rg-workload-environment`, at every scope in the subscription |

## Control matrix

| ID | Control (what must be true) | How it is met in this project | Evidence |
| --- | --- | --- | --- |
| AC-01 | Access follows least privilege and is limited to an approved baseline | Two `Reader` assignments at resource-group scope, defined in Terraform; no Owner or Contributor roles | [`terraform/main.tf`](../../terraform/main.tf), [01-baseline-audit.txt](../evidence/01-baseline-audit.txt) |
| AC-02 | Access is reviewed and violations are detected | `audit-role-assignments.sh` checks every scope (`--all`) against the baseline and exits non-zero on any violation | [`scripts/audit-role-assignments.sh`](../../scripts/audit-role-assignments.sh), [03-detection-audit.txt](../evidence/03-detection-audit.txt) |
| AC-03 | Excess access is removed and removal is re-verified | `--remediate` deletes out-of-baseline assignments; a re-run returns COMPLIANT | [05-remediation.txt](../evidence/05-remediation.txt), [06-post-remediation-audit.txt](../evidence/06-post-remediation-audit.txt) |
| AC-04 | Workloads use managed identities, not stored secrets | `mi-workload-identity` signs in with no credential; read allowed, write denied, only the workload RG visible | [08-mi-access-test.log](../evidence/08-mi-access-test.log) |
| AC-05 | Users are protected by MFA | Microsoft Entra Security Defaults confirmed enabled | [security-hardening-checklist.md](../security-hardening-checklist.md) |
| LM-01 | Access changes are logged and traceable | Activity Log `roleAssignments/write` and `/delete` events matched to audit findings by role-assignment ID | [07-activity-log-role-events.json](../evidence/07-activity-log-role-events.json) |
| LM-02 | New role assignments raise an alert | Optional Activity Log alert on any new role assignment | [`terraform/monitoring.tf`](../../terraform/monitoring.tf) |
| CM-01 | Infrastructure changes are controlled | Pull request required on `main`; CI runs `terraform fmt`, `validate` and a `tfsec` scan that blocks HIGH/CRITICAL findings | [`.github/workflows/terraform-security.yml`](../../.github/workflows/terraform-security.yml) |
| CM-02 | Configuration drift is detected | `terraform plan` showed no drift while violations existed, so a separate access audit is required | [04-terraform-plan-blind-spot.txt](../evidence/04-terraform-plan-blind-spot.txt) |
| CM-03 | Secrets and state are kept out of source control | `terraform.tfstate` and `terraform.tfvars` excluded by `.gitignore` | [`.gitignore`](../../.gitignore), [security-hardening-checklist.md](../security-hardening-checklist.md) |

## Framework cross-reference

| ID | ISO/IEC 27001:2022 Annex A | SOC 2 (2017 TSC) | NIST CSF 2.0 | Microsoft cloud security benchmark |
| --- | --- | --- | --- | --- |
| AC-01 | A.5.15 Access control; A.8.2 Privileged access rights | CC6.1, CC6.3 | PR.AA-05 | PA-7 Least privilege |
| AC-02 | A.5.18 Access rights (review) | CC6.2, CC6.3 | PR.AA-05 | PA-4 Review user access regularly |
| AC-03 | A.5.18 Access rights (removal) | CC6.3 | PR.AA-05 | PA-4 |
| AC-04 | A.5.17 Authentication information; A.8.5 Secure authentication | CC6.1 | PR.AA-01 | IM-3 Manage application identities |
| AC-05 | A.8.5 Secure authentication | CC6.1 | PR.AA-03 | IM-6 Strong authentication |
| LM-01 | A.8.15 Logging | CC7.2 | PR.PS-04 | LT-3 Logging for investigation |
| LM-02 | A.8.16 Monitoring activities | CC7.2 | DE.CM-03 | LT-1 Threat detection |
| CM-01 | A.8.32 Change management; A.8.4 Access to source code | CC8.1 | PR.PS-01 | DS-6 DevOps security |
| CM-02 | A.8.9 Configuration management | CC7.1 | PR.PS-01 | PV-1 Secure configuration |
| CM-03 | A.5.17 Authentication information | CC6.1 | PR.AA-01 | IM-8 Restrict exposure of secrets |

All controls also support ISO/IEC 27001:2022 A.5.23 (security for use of cloud services).

## Shared responsibility

| Area | Microsoft (provider) | This project (customer) |
| --- | --- | --- |
| Physical data centres, hypervisor, Azure Resource Manager | Yes | — |
| Entra ID platform and MFA capability | Yes | Turning on Security Defaults |
| Who gets which role, at which scope | — | RBAC baseline, access audit, remediation |
| Workload credentials | Managed identity platform | Choosing managed identity over secrets |
| Logging | Activity Log collection | Exporting, correlating and alerting |

## Known gaps

Recorded honestly, as an auditor would expect:

| Gap | Why | Risk accepted / next step |
| --- | --- | --- |
| No Privileged Identity Management (just-in-time admin) | Needs Entra ID P2 | Standing admin access remains; would use PIM in production |
| No Conditional Access policies | Needs Entra ID P1 | Security Defaults used instead |
| Single subscription | Azure for Students | Two resource groups simulate two accounts |
| Access audit is run on demand | No scheduler in scope | Would run on a schedule (e.g. GitHub Actions or Automation) |
| No preventive guardrail on resource location or role use | Not built in the core project | Would add Azure Policy assignments (e.g. allowed locations) in production |

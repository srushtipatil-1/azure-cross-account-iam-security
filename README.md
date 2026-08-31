# Azure Cross-Account IAM Security



A hands-on Azure security project translating an AWS cross-account IAM access pattern into Azure-native identity and access management, using Microsoft Entra ID, Azure RBAC, Managed Identity, and Terraform.



## Project Status

In progress — currently through Phase 9 of 12.



## What This Project Demonstrates

- Least-privilege access design using Azure RBAC, scoped to resource-group level

- Managed Identity for credential-free workload access (no secrets stored anywhere)

- Infrastructure as Code with Terraform, including importing pre-existing manually-created resources

- Security monitoring via Azure Activity Log

- Deliberate misconfiguration testing (over-privileged roles, overly broad scope) with detection and remediation

- Honest documentation of licensing limitations on a student subscription (e.g., PIM, Conditional Access)



## Architecture

&#x20;                +---------------------------+

&#x20;                ¦   Microsoft Entra ID       ¦

&#x20;                ¦   (Tenant-wide identity)   ¦

&#x20;                +---------------------------+

&#x20;                              ¦

&#x20;         +-----------------------------------------+

&#x20;         ¦                                          ¦



+-------------->-------------+ +---------------->---------------+

¦ rg-cross-account-iam- ¦ ¦ rg-workload-environment ¦

¦ security ¦ ¦ (Workload boundary) ¦

¦ (Security/Admin boundary) ¦ ¦ ¦

¦ ¦ ¦ RBAC Role Assignments: ¦

¦ mi-workload-identity ¦---Reader--->¦ - SG-SecurityReviewers ¦

¦ (Managed Identity) ¦ ¦ - mi-workload-identity ¦

¦ ¦ ¦ ¦

+----------------------------+ +--------------------------------+

¦

¦ monitored by

->

Azure Activity Log





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

Full write-ups are in the `docs/` folder. Summary:

- Simulated an over-privileged role assignment (Contributor added alongside Reader) — detected via role assignment audit, remediated

- Simulated overly broad scope (subscription-level instead of resource-group-level) — detected using the `--all` flag on role assignment queries, remediated



## Known Limitations

- This project uses a single Azure subscription (Azure for Students); two Resource Groups simulate the multi-account boundary from the original AWS design

- Entra PIM and Conditional Access were evaluated but not deployed, as they require Entra ID P1/P2 licensing not included in this subscription tier



## Project Phases

Orientation -> Azure Environment Setup -> Identity Architecture -> Multi-Subscription Access -> Azure RBAC -> Secure Identity -> Infrastructure as Code -> Security Monitoring -> Security Testing -> GitHub -> CI/CD Security -> Security Hardening -> Documentation


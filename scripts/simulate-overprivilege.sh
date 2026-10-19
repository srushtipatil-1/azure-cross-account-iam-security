#!/usr/bin/env bash
# Deliberately introduces two least-privilege violations for detection testing.
# Low risk: target RG is empty; both are removed by audit-role-assignments.sh --remediate.
set -euo pipefail
# Git Bash on Windows rewrites args starting with "/" (e.g. /subscriptions/...) into C:/Program Files/Git/... for native tools (az, jq). Disable that.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"

SUB_ID=$(az account show --query id -o tsv)
WORKLOAD_RG_ID=$(az group show -n rg-workload-environment --query id -o tsv)
GROUP_ID=$(az ad group show --group SG-SecurityReviewers --query id -o tsv)
MI_PRINCIPAL_ID=$(az identity show -n mi-workload-identity -g rg-cross-account-iam-security --query principalId -o tsv)

echo "[$(date -u +%FT%TZ)] Misconfig 1: over-privileged role (Contributor) on workload RG for the managed identity"
az role assignment create --assignee-object-id "$MI_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "$WORKLOAD_RG_ID" --query "{role:roleDefinitionName,scope:scope,id:id}" -o table

echo
echo "[$(date -u +%FT%TZ)] Misconfig 2: overly broad scope (Reader at SUBSCRIPTION) for the reviewers group"
az role assignment create --assignee-object-id "$GROUP_ID" --assignee-principal-type Group \
  --role Reader --scope "/subscriptions/$SUB_ID" --query "{role:roleDefinitionName,scope:scope,id:id}" -o table

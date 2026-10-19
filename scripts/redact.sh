#!/usr/bin/env bash
# Replaces subscription ID, tenant ID and admin UPN in evidence files (in place).
# Role-assignment GUIDs are kept so audit findings can be correlated with Activity Log events.
set -euo pipefail
# Git Bash on Windows rewrites args starting with "/" (e.g. /subscriptions/...) into C:/Program Files/Git/... for native tools (az, jq). Disable that.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
ADMIN_UPN=$(az account show --query user.name -o tsv)
for f in "$@"; do
  sed -i -e "s|$SUB_ID|<SUBSCRIPTION_ID>|g" -e "s|$TENANT_ID|<TENANT_ID>|g" -e "s|$ADMIN_UPN|<ADMIN_UPN>|g" "$f"
done
echo "Redacted: $*"

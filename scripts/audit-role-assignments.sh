#!/usr/bin/env bash
# Least-privilege RBAC audit for the governed principals.
# Baseline: each principal holds exactly ONE 'Reader' assignment, scoped to the workload RG.
# Exit 0 = compliant, 1 = violations. Pass --remediate to delete violating assignments.
set -euo pipefail
# Git Bash on Windows rewrites args starting with "/" (e.g. /subscriptions/...) into C:/Program Files/Git/... for native tools (az, jq). Disable that.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"

SEC_RG="${SEC_RG:-rg-cross-account-iam-security}"
WORKLOAD_RG="${WORKLOAD_RG:-rg-workload-environment}"
GROUP_NAME="${GROUP_NAME:-SG-SecurityReviewers}"
MI_NAME="${MI_NAME:-mi-workload-identity}"
ALLOWED_ROLE="Reader"
REMEDIATE=false
[ "${1:-}" = "--remediate" ] && REMEDIATE=true

WORKLOAD_RG_ID=$(az group show -n "$WORKLOAD_RG" --query id -o tsv)
GROUP_ID=$(az ad group show --group "$GROUP_NAME" --query id -o tsv)
MI_PRINCIPAL_ID=$(az identity show -n "$MI_NAME" -g "$SEC_RG" --query principalId -o tsv)

# Safety guard: abort if the scope string is altered when passed to jq (path mangling would cause false violations
# and, with --remediate, deletion of the legitimate baseline assignments).
if [ "$(jq -rn --arg s "$WORKLOAD_RG_ID" '$s')" != "$WORKLOAD_RG_ID" ]; then
  echo "ABORT: scope argument was altered in transit (shell path conversion). Nothing was changed." >&2
  exit 2
fi

echo "Audit run : $(date -u +%Y-%m-%dT%H:%M:%SZ)  (remediate=$REMEDIATE)"
echo "Baseline  : exactly one '$ALLOWED_ROLE' at $WORKLOAD_RG_ID per principal"
echo

violations=0
for entry in "$GROUP_NAME:$GROUP_ID" "$MI_NAME:$MI_PRINCIPAL_ID"; do
  label="${entry%%:*}"; pid="${entry#*:}"

  # --all = every scope in the subscription (subscription, all RGs, individual resources)
  assignments=$(az role assignment list --assignee "$pid" --all \
    --query "[].{role:roleDefinitionName, scope:scope, id:id}" -o json)
  total=$(jq length <<<"$assignments")

  echo "== $label ($pid) - $total assignment(s)"
  jq -r '.[] | "   \(.role)\t\(.scope)"' <<<"$assignments"

  bad=$(jq --arg role "$ALLOWED_ROLE" --arg scope "$WORKLOAD_RG_ID" \
    '[.[] | select(.role != $role or (.scope|ascii_downcase) != ($scope|ascii_downcase))]' <<<"$assignments")
  nbad=$(jq length <<<"$bad")

  if [ "$nbad" -gt 0 ]; then
    violations=$((violations + nbad))
    echo "   VIOLATION: $nbad assignment(s) outside baseline"
    jq -r '.[] | "     - \(.role) at \(.scope)\n       id: \(.id)"' <<<"$bad"
    if $REMEDIATE; then
      for id in $(jq -r '.[].id' <<<"$bad"); do
        az role assignment delete --ids "$id" && echo "     REMEDIATED: deleted $id"
      done
    fi
  elif [ "$total" -ne 1 ]; then
    violations=$((violations + 1))
    echo "   VIOLATION: baseline Reader assignment missing"
  else
    echo "   OK"
  fi
  echo
done

if [ "$violations" -gt 0 ]; then
  if $REMEDIATE; then
    echo "RESULT: NON-COMPLIANT ($violations finding(s)) - remediation attempted; re-run to confirm"
  else
    echo "RESULT: NON-COMPLIANT ($violations finding(s))"
  fi
  exit 1
fi
echo "RESULT: COMPLIANT"

#!/usr/bin/env bash
# Exports role-assignment write/delete events from the subscription Activity Log.
# Usage: ./scripts/export-activity-log.sh <start ISO8601> [end ISO8601]
# Activity Log retention is 90 days; start time must be within that window.
set -euo pipefail
# Git Bash on Windows rewrites args starting with "/" (e.g. /subscriptions/...) into C:/Program Files/Git/... for native tools (az, jq). Disable that.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"

START="${1:?usage: $0 <start-time e.g. 2026-08-25T00:00:00Z> [end-time]}"
END="${2:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
OUT="${OUT:-docs/evidence/activity-log-role-events.json}"

az monitor activity-log list \
  --start-time "$START" --end-time "$END" --max-events 2000 \
  --query "[?authorization.action=='Microsoft.Authorization/roleAssignments/write' || authorization.action=='Microsoft.Authorization/roleAssignments/delete'].{time:eventTimestamp, operation:authorization.action, status:status.value, caller:caller, scope:authorization.scope, correlationId:correlationId}" \
  -o json > "$OUT"

echo "Saved $(jq length "$OUT") events to $OUT"
echo
jq -r '.[] | "\(.time)  \(.status)\t\(.operation | split("/") | last)\t\(.scope)"' "$OUT" | sort

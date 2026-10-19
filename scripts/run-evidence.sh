#!/usr/bin/env bash
# One-shot evidence run: baseline -> simulate -> detect -> terraform blind spot -> remediate -> verify -> Activity Log.
# Run from the repo root (Azure Cloud Shell Bash, or Git Bash/WSL with az + jq + terraform).
# Requires: az login done, terraform state present in ./terraform.
set -uo pipefail
# Git Bash on Windows rewrites args starting with "/" (e.g. /subscriptions/...) into C:/Program Files/Git/... for native tools (az, jq). Disable that.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"
cd "$(dirname "$0")/.."
EV=docs/evidence
mkdir -p "$EV"
START=$(date -u +%FT%TZ)

step() { echo; echo "######## $1"; }

step "01 Baseline audit (expect COMPLIANT)"
./scripts/audit-role-assignments.sh | tee "$EV/01-baseline-audit.txt"

step "02 Simulate over-privileged roles"
./scripts/simulate-overprivilege.sh | tee "$EV/02-simulation.txt"

echo "Waiting 60s for RBAC propagation..."; sleep 60

step "03 Detection audit (expect NON-COMPLIANT, 2 findings)"
./scripts/audit-role-assignments.sh | tee "$EV/03-detection-audit.txt"

step "04 terraform plan while violations exist (expect 'No changes' = Terraform blind spot)"
(cd terraform && terraform plan -no-color) | tee "$EV/04-terraform-plan-blind-spot.txt"

step "05 Remediate"
./scripts/audit-role-assignments.sh --remediate | tee "$EV/05-remediation.txt"

echo "Waiting 60s for RBAC propagation..."; sleep 60

step "06 Post-remediation audit (expect COMPLIANT)"
./scripts/audit-role-assignments.sh | tee "$EV/06-post-remediation-audit.txt"

step "07 Activity Log export (waiting 10 min for ingestion)"
sleep 600
OUT="$EV/07-activity-log-role-events.json" ./scripts/export-activity-log.sh "$START"

step "Redacting subscription/tenant IDs and UPN"
./scripts/redact.sh "$EV"/0*.txt "$EV"/07-activity-log-role-events.json

echo
echo "Done. If 07 shows fewer than 4 Succeeded events, wait a few minutes and re-run:"
echo "  OUT=$EV/07-activity-log-role-events.json ./scripts/export-activity-log.sh $START && ./scripts/redact.sh $EV/07-activity-log-role-events.json"

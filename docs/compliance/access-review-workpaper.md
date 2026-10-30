# Workpaper AC-02: Azure Role-Assignment Access Review

Written as an IT audit control test of the access review performed in this project. Every result below comes from the evidence files in [`docs/evidence/`](../evidence/).

| | |
| --- | --- |
| **Control** | Role assignments for governed identities are limited to the approved baseline; anything outside it is detected and removed |
| **Control type** | Detective (audit script) with corrective follow-up (remediation) |
| **Frameworks** | ISO/IEC 27001:2022 A.5.18, A.8.2 · SOC 2 CC6.2, CC6.3 · NIST CSF 2.0 PR.AA-05 · MCSB PA-4, PA-7 |
| **Population** | Every role assignment held by `SG-SecurityReviewers` and `mi-workload-identity`, at every scope in the subscription (`az role assignment list --all`) |
| **Test date** | 19 October 2026 (UTC) |
| **Prepared by** | Srushti Patil |

## 1. Test of design

| Question | Answer | Evidence |
| --- | --- | --- |
| Is the approved baseline written down? | Yes: one `Reader` at `rg-workload-environment` per identity, in Terraform and in the audit script | [`terraform/main.tf`](../../terraform/main.tf), [`scripts/audit-role-assignments.sh`](../../scripts/audit-role-assignments.sh) |
| Does the review cover all scopes, not only one resource group? | Yes: `--all` lists subscription, resource-group and resource-level assignments | Audit script |
| Can it catch both wrong role and wrong scope? | Yes: anything that is not `Reader` **or** not at the workload RG scope is a violation | Audit script |
| Does it fail loudly? | Yes: exit code 1 and `NON-COMPLIANT` on any violation | Audit script |
| Can it remove access safely? | Yes: `--remediate` deletes only violating assignment IDs; a guard aborts if the scope string is altered in transit | Audit script |
| Is a separate review needed beyond IaC? | Yes: `terraform plan` reported no changes while two violations existed | [04-terraform-plan-blind-spot.txt](../evidence/04-terraform-plan-blind-spot.txt) |

**Design conclusion:** designed appropriately.

## 2. Test of operating effectiveness

Two known violations were introduced on purpose to confirm the control catches them (a re-performance test with seeded exceptions).

| Time (UTC) | Step | Result | Evidence |
| --- | --- | --- | --- |
| 05:25:07 | Baseline audit | COMPLIANT: 1 `Reader` per identity | [01](../evidence/01-baseline-audit.txt) |
| 05:25:22–31 | Seeded violations | (1) `Contributor` on the workload RG for the managed identity; (2) `Reader` at **subscription** scope for the reviewers group | [02](../evidence/02-simulation.txt), [07](../evidence/07-activity-log-role-events.json) |
| — | IaC check | `terraform plan`: "No changes" — violations invisible to Terraform | [04](../evidence/04-terraform-plan-blind-spot.txt) |
| 05:26:36 | Detection audit | NON-COMPLIANT, 2 findings, each with its role-assignment ID | [03](../evidence/03-detection-audit.txt) |
| 05:27:09–30 | Remediation | Both assignments deleted | [05](../evidence/05-remediation.txt), [07](../evidence/07-activity-log-role-events.json) |
| 05:28:35 | Re-test | COMPLIANT | [06](../evidence/06-post-remediation-audit.txt) |

**Completeness check (Activity Log):** 4 operations, each `Started` then `Succeeded` — 2 `roleAssignments/write` (05:25) and 2 `roleAssignments/delete` (05:27). The IDs match the audit findings one to one:

| Role-assignment ID | Created | Detected | Removed |
| --- | --- | --- | --- |
| `a5b3f88d-…02e` (Contributor, managed identity) | 05:25:26 | 05:26:36 | 05:27:30 |
| `23bc38fe-…5ce` (Reader at subscription, group) | 05:25:31 | 05:26:36 | 05:27:19 |

Time from violation to removal: about 2 minutes. Both seeded exceptions were detected (2 of 2); no false positives on the two baseline assignments.

**Effective access check:** signed in as the managed identity with no secret — read on the workload RG allowed, write denied (`AuthorizationFailed`), only the workload RG visible ([08](../evidence/08-mi-access-test.log)).

## 3. Exceptions and observations

| Ref | Observation | Rating | Recommendation |
| --- | --- | --- | --- |
| OBS-1 | Infrastructure-as-code alone did not detect out-of-band access changes | Medium | Keep the access audit as a separate control; run it on a schedule |
| OBS-2 | The access review runs on demand only | Low | Schedule it and keep each run's output as evidence |
| OBS-3 | No just-in-time admin (PIM) or Conditional Access | Low (lab) | Licensing limit (Entra ID P1/P2); use both in production |

## 4. Conclusion

**Effective.** The control detected both seeded violations at different scopes, removal was confirmed by a re-test, and every change is traceable in the Activity Log.

## Limitations

Lab environment with two governed identities and seeded violations, not a production population. One test run on one date. Times and IDs come from the committed evidence; subscription and user IDs are redacted.

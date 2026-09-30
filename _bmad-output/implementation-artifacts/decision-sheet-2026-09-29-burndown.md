# Burn-down plan and decision sheet, 2026-09-29

For the owner, relayed by the Planner session. Measured on feature at `dc385623` (ledger 1,311 entries; `ledger.sh load`: routed 112, decision-pending 3, escalated 0, status_unknown 0, owner_unknown 0). Nothing here starts before the owner approves it, and nothing starts before the 1.0.4 cut (Wed 2026-09-30 14:00 PDT).

## The plan

- **When and where:** after the 1.0.4 cut, on **slot B**. Epic 18 finishes its two pending safety fixes (DW-1859 instance-state sweep, DW-1860 new-volume threshold) first, then pauses while the cleanup runs, then resumes with 18.15. Slot A stays on Epic 16 and then Epic 19 as planned. No third slot: slot C was retired for rate limits, and the account has hit its weekly quota twice.
- **Fresh story, not a resume.** Close 23.1 as it stands (partial, merged 09-26, its spec is oversized) and charter **Story 23.2 "Range-end cleanup, part 2"** with at most 12 entries, the kit's `burndown_story_max`, chosen by priority: CI flakes first, which cost reruns in every lane every day, then security, then entries with repeat occurrences. Then **Story 23.3** takes the next 12 after the following release. 23.1's 53 `range-end-cleanup` entries are re-sorted into 23.2 and 23.3 by the same priority. Its 28 LOWs close as `wontfix-accepted` with a reopen probe unless they are small enough for a fix pack, because the kit says a LOW is never parked on a cleanup owner.
- **Each story runs the full pipeline:** plan, validate, implement, QA, review, adjudication, smoke, CI, merge at its boundary.

## Decision sheet, the 31 entries parked on `burndown`

Recommended disposition per entry. Say "as recommended" to take them all, or name the exceptions.

**Already decided by the orchestrator under your standing grant; confirm:**

| DW | Summary | Decided |
|---|---|---|
| 1775 | Eight admin API defect candidates on namespaces and mappings | `wontfix-accepted`: well-known vendor behaviour, no upstream report, following your DW-1820 call |
| 1798 | PathPort did not cover OcuPilot's own served files | Resolved by 18.14 (PATH.SERVED) |
| 1824 | New Namespace form discards typed values on Create a database | Fix: keep the form and return to it, as the classic portal does (Epic 18) |

**Into Story 23.2 (fix now; 12 by priority):**

| DW | Why it's first |
|---|---|
| 1829 | CI flake: the background-task seed can read Running for its whole wait |
| 1831 | CI flake: an OAuth discover test case misreads intermittently |
| 1450 | Security: a secret argument may name a derived field the write tool doesn't permit |
| 1663 | Security: adding %Manager, %Operator or %SecurityAdministrator to the auth server's customization role isn't flagged as a privilege grant |
| 1289 | Seen twice: a password refused by a validation routine answers 500, not 422 |
| 1451 | Seen twice: the destructive-test gate can't see a class that turns auditing off through the confirm path |
| 1497 | A row action and a concurrent confirm on the same target aren't ordered |
| 1290 | A wire test derives its expectation with the same assumption as the code |
| 1440 | The installer derives the anonymous applications' role from the wrong resource |
| 1210 | The progress poll returns every step's full result with no bound (up to ~6.4 MB a second) |
| 1669 | A proposal card's privilege line stops refreshing when its turn ends |
| 1414 | A background write's refusal is announced as the user's own action failing, and Home announces it twice |

**Into Story 23.3 (next release):** 1188 (a lint rule for template class names, the class of bug behind DW-1837's font), 1191, 1211, 1297, 1333, 1377, 1401, 1449, 1462, 1465, 1562.

**Routed to a feature story:**
- **1555** RSA and symmetric-key wallet secrets go to **18.7 Encryption**, where the key-material design belongs.
- **1813** An empty-low-end mapping range carries no system-global consequence; it goes to **Epic 18** as a small fix after DW-1860, since Epic 18 owns mappings.

**`wontfix-accepted`, with a reopen probe:**
- **429** and **1287** are untested error branches that need a test seam. Reopen if a defect is ever seen in those branches.
- **1645** The audit mask matches English audit texts. Reopen if OcuPilot supports a localized instance; 2026.2 Community is English.

## Five stale routes (owned by stories already done)

| DW | Owner (done) | Recommended |
|---|---|---|
| 415 | 10.1 | `wontfix-accepted`, untested conflict branch; reopen on a defect there |
| 1170 | 10.1 | 23.3: an error sentence says "or no body at all" on routes that refuse an absent body |
| 1084 | 4.7 | 23.3: the system prompt doesn't ask the model to name rows in backticks |
| 1086 | 4.7 | 23.3: turn-probe test helpers are copied per spec and drift, a flake source |
| 1423 | 16.17 | Epic 16 (with 16.25): "Updated: \<id\> created" contradicts its own prefix |

## Thirteen entries on Epic 17 (yours; out of the orchestrator's range)

Most are developer tooling, not the README, so the recommendation re-owns them:

| DW | Recommended |
|---|---|
| 48 | **23.2 (security):** the container start hook compiles every `Test.*` fixture, including fault-injection classes, into the product install |
| 216, 235 | 23.3: the smoke port assumption and a scratch-root guard |
| 446, 1177 | 23.3: CLAUDE.md claims that are out of date (rule count, pre-commit behaviour) |
| 432 | 23.3: document `OCUPILOT_ALLOW_PRODUCTION_INSTALL` in DEVELOPMENT.md |
| 309, 375, 416, 417, 418, 431 | `wontfix-accepted`: prose-tooling gaps (citation gate reach, back-reference drift, spelling sweep); reopen if a lint miss reaches a release |
| 1312 | Keep on Epic 17: operator documentation should name `OcuPilotIdentity` |

## For the owner separately

**Rule 27** ("cleanup stories carry only what blocks the 2026-09-27 application floor") is obsolete, because the floor has passed. The recommended restatement: *cleanup and burn-down charters carry entries that block the next scheduled release or a story in a downstream epic, plus CI flakes; everything else goes to the standing cleanup story chartered after each release, at most 12 entries, by priority. An N.0 never goes on the critical path.*

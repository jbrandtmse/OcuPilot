---
title: "Story 21.34: A backup action leaves the web process's null device open"
type: 'bugfix'
created: '2026-11-16'
status: 'done'
baseline_revision: '635d8e128ac581c8b7abb906e4c5b1e0800411e2'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - summary: >-
      The real VendorSuspend (its %SYS switch, namespace restore and freeze or thaw branch) is not run by BackupDevice, which replaces it.
    evidence: |-
      BackupWrite (armed, green on ocupilot-ci, 9/9) runs it for real; a mutation of its namespace restore was not run, so whether BackupWrite pins it is unverified.
    location: >-
      src/OcuPilot/Port/BackupPort.cls VendorSuspend
    severity: low (unverified)
---

<intent-contract>

## Intent

**Problem:** `BackupPort.SuspendCall` (the freeze and thaw) opens the null device when it is not the current device and closes it afterwards. In a pooled web process that already holds the null device, the open is a no-op and the close shuts the process's own device, so the next request that process serves and that `Use`s it without opening it, a DTL compile among them, fails with `<NOTOPEN>` (DW-2650; DW-2395's mechanism, fixed for `LogSourcePort.IntegrityReport` in Story 18.38).

**Approach:** One shared `DeviceIsOpen` in `OcuPilot.Kernel.Utils`, called by both ports. `SuspendCall` opens the null device only when the process does not hold it, closes it only when it opened it, and restores the caller's device on every path.

## Boundaries & Constraints

**Always:** the shared check replaces `LogSourcePort`'s private copy (Rule 31); the caller's device, with its mnemonic space and output redirection, is restored on a good status, an error status and a raise; the vendor still runs in `%SYS` with the null device current.

**Never:** a user-facing string, an AD change, a copy of the check, a test that freezes the instance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Held | Process holds the null device, a freeze or thaw runs | Still held afterwards | No error expected |
| Not held | Process does not hold it | Not held afterwards | No error expected |
| Current | The null device is the caller's current device | Still open and current | No error expected |
| Vendor fails | Error status or a raise, held or not | Device state as the first two rows | The status is the vendor's own |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Utils.cls` -- `DeviceIsOpen`, moved here from `LogSourcePort` (public).
- `src/OcuPilot/Port/LogSourcePort.cls` -- `IntegrityReport` calls the shared check; the private copy is removed.
- `src/OcuPilot/Port/BackupPort.cls` -- `SuspendCall` device handling; new private `VendorSuspend` holds the vendor call and its `%SYS` switch (it is a seam, and the switch stays inside it so no OcuPilot routine runs in `%SYS`).
- `src/OcuPilot/Test/BackupDeviceSeam.cls` -- `BackupPort` with `VendorSuspend` replaced (good status, error status or raise), recording the current device it ran under.
- `src/OcuPilot/Test/BackupDevice.cls` -- the device-state test.
- Reuse pointers: `Test/DatabaseIntegrity.cls` `TestTheReportLeavesTheNullDeviceAsItFoundIt` (the 18.38 test shape), `Test/BackupGateSeam.cls` (overrides `SuspendCall` whole, unaffected).

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Utils.cls` -- add `DeviceIsOpen` -- one shared check
- `src/OcuPilot/Port/LogSourcePort.cls` -- call it, delete the private method -- Rule 31
- `src/OcuPilot/Port/BackupPort.cls` -- held-aware open and close, restore on every path, extract `VendorSuspend` -- the fix and a seam
- `src/OcuPilot/Test/BackupDeviceSeam.cls`, `src/OcuPilot/Test/BackupDevice.cls` -- the hermetic device-state test

**Acceptance Criteria:**

- Given a process holding the null device, when a freeze or thaw runs, then it still holds it; given one that did not, then it does not.
- Given the null device is the caller's current device, when a suspend runs, then it is still open and current.
- Given the vendor answers an error or raises, then the device state is as above and the caller's device is current with output not redirected.
- Given a fresh instance, when the backup spec and then the interop-editors spec run, then both are green.

## Spec Change Log

## Review Triage Log

### 2026-11-16 - Review pass

- verdicts: 6 findings - high 0, medium 2, low 4, false 0, maybe-false 0, plus the intent layer's description
- findings:

  - `[medium]` `[patch]` the redirect assertion compared against a literal 0, so the entry state was never observed - the test now captures the redirection on entry and compares against it.
  - `[medium]` `[patch]` no mutation line for the restore of the caller's device - mutation 4 run (red on every held leg's current-device assertion), recorded in Verification.
  - `[low]` `[defer]` the real `VendorSuspend` is not run by `BackupDevice` - in the frontmatter `deferred:` list; `BackupWrite` runs it for real.
  - `[low]` `[reject]` the raise leg raises from the seam, not from the shipped `VendorSuspend`, which converts a raise to a status - the leg pins `SuspendCall`'s own `Catch`, which a raise from `DeviceIsOpen`, `Open` or `Use` reaches; the device outcome is the same either way; a fix would add a leg for an unlikely harm.
  - `[low]` `[reject]` the `DeviceIsOpen` non-`<NOTOPEN>` rethrow branch has no test - moved verbatim from 18.38 and a non-`<NOTOPEN>` raise cannot be provoked on a `Use` of a device name without a contrived fixture.
  - `[low]` `[reject]` the redirect-on and mnemonic-bound caller legs are not driven - restore logic is unchanged in kind from the shipped code; the redirection is now compared against its entry value; a bound mnemonic needs a routine fixture for no changed behavior.
  - Intent-alignment layer (descriptive): the diff implements the device-state contract on `SuspendCall` and the shared check; the cross-request symptom (backup, then a compile route in the same process) is exercised by the fresh browser chain, recorded in Verification, and the `VendorSuspend` extraction is the seam the intent asked for.

## Design Notes

Decided in-stage: the proof of AC1's reproduction is the runner's (`e21u/21-34/repro/`: `interop-editors` AC2 failed with ERROR #6220 and `<NOTOPEN>CompileDTL+30^%Api.InteropEditors.v3.impl` after `backup` ran). The test runs through `SuspendCall` itself with the vendor call replaced, so no freeze is issued. `LogSourcePort`'s integrity test stays the pin on that caller.

## Verification

**Commands:**

- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.BackupDevice` (loop) -- expected: 3 tests, 0 failed
- Classes (once, one per call): `OcuPilot.Test.DatabaseIntegrity`, `OcuPilot.Test.BackupWrite`, `OcuPilot.Test.BackupRead`, `OcuPilot.Test.PortGate`, `OcuPilot.Test.Utils` -- expected: green
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` -- expected: clean
- Fresh chain (once): `fresh.sh <dir> rebuild`, `build`, `deploy`, then `backup.browser-spec.mjs` and `interop-editors.browser-spec.mjs` -- expected: all green

mutation: `SuspendCall` opens the null device whether or not `DeviceIsOpen` says it is held (`If '..DeviceIsOpen` -> `If 1`), reloaded -> `BackupDevice.TestSuspendLeavesTheNullDeviceAsItFoundIt` red on all six held legs; reverted, green.
mutation: `DeviceIsOpen` answers 1 whatever the process holds, reloaded -> `TestDeviceIsOpenAnswersFromWhatTheProcessHolds` and the not-held legs of the suspend test red; reverted, green.
mutation: `SuspendCall` closes the null device whether or not it opened it (`If tOpened Close tNull` -> `Close tNull`), reloaded -> `TestSuspendKeepsACallersNullDevice` and the held legs red; reverted, green.
mutation: `SuspendCall` never restores the caller's device (`If tSwitched {` -> `If 0 {`), reloaded -> the "caller's device is current again" assertion red on every held leg; reverted (tree byte-identical to the pre-mutation copy), reloaded, green.
mutation: the fresh browser chain's red is the runner's reproduction on the unfixed port (`e21u/21-34/repro/`: `interop-editors` AC2 ERROR #6220, `<NOTOPEN>CompileDTL+30`); the fixed tree is green below.

**Fresh chain (once, after the last patch):** `fresh.sh rebuild` then `build` and `deploy`; `backup.browser-spec.mjs` 3/3, then `interop-editors.browser-spec.mjs` 23/23.

## Auto Run Result

Summary: `DeviceIsOpen` moved into `OcuPilot.Kernel.Utils` and is called by `LogSourcePort.IntegrityReport` and `BackupPort.SuspendCall`. `SuspendCall` opens the null device only when the process does not hold it, closes it only when it opened it, and restores the caller's device on every path; the vendor call and its `%SYS` switch moved into a private `VendorSuspend`, which the new `BackupDeviceSeam` replaces so no freeze is issued.

Files changed:

- `src/OcuPilot/Kernel/Utils.cls` -- `DeviceIsOpen`.
- `src/OcuPilot/Port/LogSourcePort.cls` -- calls the shared check; private copy removed.
- `src/OcuPilot/Port/BackupPort.cls` -- `SuspendCall` device handling and `VendorSuspend`.
- `src/OcuPilot/Test/BackupDeviceSeam.cls`, `src/OcuPilot/Test/BackupDevice.cls` -- new seam and 3-test device-state class.
- This spec.

Review: 2 patches applied (redirect compared against its entry value; restore mutation recorded), 1 deferred, 3 rejected with reasons in the triage log.

Verification: `LOADERRORS=0`; `BackupDevice` 3/3, `DatabaseIntegrity` 11/11, `BackupWrite` 9/9, `BackupRead` 10/10, `PortGate` 4/4, `Utils` 12/12; `check-objectscript` 0 problems, its harness 152 OK, `lint-docs` clean; four mutations observed red and reverted; fresh chain `backup` 3/3 then `interop-editors` 23/23.

Follow-up review recommended: false.

Residual risk: the caller's redirect-on and mnemonic-bound legs are not driven by a test (restore logic unchanged in kind).

Status: done
Blocking condition: none

# Epic 8 Context: Create and import

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 5. A user creates what the six areas administer through medium forms that validate server-side and open the new entity on success. Stories 8.1 to 8.8 are done and settled the create, edit and delete patterns that Epic 9's editors inherit. At least one create or edit form per area is part of the 2026-09-27 floor. Story 8.9 is the floor's last act: it checks that OcuPilot installs and works on stock plain IRIS Community, then either confirms the README's claim or corrects it. The owner scheduled it after the floor and accepted the risk of a late failure.

## Stories

- Story 8.1: Create a web application (done)
- Story 8.2: Create a user (done)
- Story 8.3: Create a role, and manage its resource grants (done)
- Story 8.4: The resource editor (done)
- Story 8.5: X.509 import, edit and delete (done)
- Story 8.6: The wallet secret form (done)
- Story 8.8: The device editor (done)
- Story 8.9: Plain IRIS Community verification

There is no Story 8.7. It moved to Epic 7 as Story 7.11.

## Requirements & Constraints

- **Story 8.9's four checks.** Each one passes, or its failure is documented and the README corrected.
  1. On a stock plain IRIS Community image, which has no `HSCUSTOM` namespace, install falls back to `USER` and completes.
  2. The credential ladder offers the environment-variable rung, and that rung works. The IRIS-credentials rung is **not offered** in a namespace that is not interoperability-enabled. Offering it and letting it fail does not pass.
  3. `/api/admin` is present, and its version is confirmed.
  4. The check runs after the floor, and the risk of a late failure is recorded as accepted, not discovered.
- **The claim under test.** The README's opening says OcuPilot "runs on IRIS Community and IRIS for Health Community". Its namespace table (container start: `HSCUSTOM` if present, else `USER`, overridable with `OCUPILOT_NAMESPACE`; install refuses when neither exists) is the other claim 8.9 confirms or corrects. The research containers and every dev and throwaway instance so far have been IRIS for Health Community. Until 8.9 runs, the plain-Community half of Community Edition compatibility is an untested claim.
- **The automated tests must run against both stock images and confirm the admin API is present on each.** The admin API is pinned to v2.
- **Form contract, settled by 8.1 to 8.8.** A full-page route. Fields follow the classic order. Validation is server-authored and inline, errors run through the shared error-summary focus sequence, and the sticky action bar has Save as its one primary. Save on a create opens the new entity. The unsaved-changes guard also holds an agent navigation. Every write ships with its agent write tool, and a save publishes to the change-event bus.
- **Secrets are write-only end to end**, excluded by schema declaration: the user password, the X.509 certificate, key and key password, and the wallet value.
- **Only OcuPilot's self-protection is refused.** Privilege grants go through at the strongest confirmation.
- **Deletes confirm by name.**

## Technical Decisions

- **Install (one installer class, two entry points, idempotent).** Install runs at container start, never at image build, and each start re-runs it. The default namespace is `HSCUSTOM` when it exists, then `USER`. When neither exists the answer is empty and every entry point refuses, naming both namespaces. `Installer.ResolveNamespace` probes each candidate through the `NamespaceExists` seam. The container path honours `OCUPILOT_NAMESPACE`. An IPM install lands in the namespace `zpm` runs from and refuses system namespaces. The `_SYSTEM` password is unexpired only from the container start path, only on a genuinely first install, and only for that account by name. Install enables auditing and registers OcuPilot's events. It also creates a named SSL configuration for outbound TLS, with server-identity checking on.
- **Readiness is the contract, not IRIS startup.** The health check reports healthy only once this start's install has recorded success. The unauthenticated readiness endpoint is `/api/ocupilot/readiness/`. There is one smoke path, `scripts/smoke.sh`, and its assertions live in `OcuPilot.Install.Smoke`. A run that executes zero checks is a failure. IPM is never a runtime dependency: the vendor image ships no loaded IPM.
- **Credential ladder (`Kernel/Secret/Ladder`).** It has two rungs:
  - `env` reads an environment variable in any namespace. It checks no namespace and no rung predicate, and it has no store path, because the operator owns that value.
  - `creds` reads `Ens.Config.Credentials` and is the only rung with `Store` and `Clear`. Its reachability predicate requires all three of: the credentials class is compiled in the namespace, `%Library.EnsembleMgr.IsEnsembleNamespace` is true, and the instance is licensed for interoperability (`$System.License.GetFeature(1)`).
  - The ladder never returns a value in a status or an error. An unresolvable credential fails the turn with a named reason.
  - Tests that exercise the non-interop shape through seams: `SecretNotInterop`, `NotEnsembleNamespace` and `RaisingEnsembleNamespace`.
- **Admin API dependency.** It is experimental, marked `[Hidden]`, and stays subject to change until IRIS 2027.1. Only `Port/AdminPort` names an `%Api.Admin.*` class. At startup `AdminPort` checks that the API reports v2 and that a named probe endpoint answers. If either check fails, it fails loudly with an actionable message. The version is **read**, not inferred: `AdminPort.HighestDispatchVersion(AdminPort.AdminApiClass())` parses `%Api.Admin`'s UrlMap and takes the highest `Dispatch.v<N>`. An endpoint-inventory fixture re-derives from the instance and fails CI on vendor drift. Images are pinned to an explicit tag, and a floating `latest-cd` or an untagged reference is refused.
- **CI (`.github/workflows/ci.yml`; Epic 8's footprint is it and `scripts/ci-*.sh`).** It has five jobs: `gates`, `instance`, `browser`, `images` and `package`.
  - `gates` runs the checkers, the build and the client suite, once per Node band at each band's floor.
  - `instance` starts an IRIS for Health throwaway on 52776/1975 and runs admin-API drift, the ObjectScript suite one class at a time, and smoke.
  - `browser` starts its own throwaway on 52780/1979.
  - `images` runs with `fail-fast: false` over `intersystems/irishealth-community:2026.2` and `intersystems/iris-community:2026.2`. For each, `scripts/ci-image-compile.sh` compiles `src/OcuPilot/` and reads the admin API version in a portless container with no start hook. **It compiles and probes; it never installs and never issues an HTTP request.** That is the gap 8.9 closes.
  - `package` builds the IPM archive and loads it on a second container. Both containers run `--network none`.
  - `ui/tools/ci.test.mjs` holds the workflow's shape in both directions: the job names, each `run:` command, the images matrix naming plain Community, the images job's `fail-fast: false`, `ci-image-compile.sh`'s verdict arms, and the throwaway's copied compose keys. A workflow or script change updates that test in the same pass.
  - Nothing in CI publishes, pushes or references `secrets.`, and the test asserts each absence. No step uses `continue-on-error` or `|| true`.
- **Throwaways and reserved ports.** `scripts/ci-throwaway.sh up|logs|down` takes `--dir`, `--project`, `--web`, `--super` and `--image`, and defaults to the IRIS for Health image. It refuses outright the live and slot ports and names (52774/1973 `ocupilot`, 52775/1974 slot B, 52778/1977 slot C) and a project name Compose already knows. The per-slot throwaways are `ocupilot-ci` on 52776/1975, `ocupilot-b-ci` on 52777/1976 and `ocupilot-c-ci` on 52779/1978. 52773/1972 belong to the unrelated `iris-community-edition` container. CI reserves 52776 and 52780 from the Linux ephemeral range. Tear down only a throwaway whose `up` you ran yourself. Never touch `ocupilot` or any `ocupilot-slot-*` container.
- **Write model, settled by 8.1 to 8.8.**
  - Create is its own write kind: it fingerprints the target's absence.
  - A screen Save and an agent confirm are two callers of one tool class.
  - Nothing merges on the server. OcuPilot reads fresh and sends the complete property set.
  - Verified writes re-read and refuse `PORT.NOTAPPLIED`.
  - There are three named port completions through vendor classes: the resource PUT with an empty public permission, the X.509 import from content, and the wallet-secret read. There is no general licence.
  - A write tool may declare pairs beyond its screen's read-only set only when the vendor class writes a database the screen's read does not. It is then refused by name before any port call. The one case is the device tools' `%DB_IRISSYS:WRITE`.
  - Administrative resources are gated at `USE`, never `WRITE`.
- **Devices (8.8).** The `os-management/devices/edit` form uses `osmgmt.devices.create`, `osmgmt.devices.update` (merge) and the agent-only `osmgmt.devices.delete`. Tool validation refuses `^` in any field (the vendor writes it straight into `iris.cpf`), an out-of-range `Type`, and a duplicate or fractional `Alias`.
- **Test discipline.** Run one test class at a time, and never two in one message. Sweep on a throwaway started after the last edit. Redeploy the bundle before trusting a browser spec. A denial test uses a purpose-built least-privileged role. The cross-file rosters are the story's to update.

## Cross-Story Dependencies

- **8.9 depends on** the installer and container start path (Epic 1), the credential ladder and provider configuration (Epic 3), and `AdminPort`'s version read. It extends CI rather than replacing it. A plain-Community install run is likely a throwaway using `--image intersystems/iris-community:2026.2` (inference). The README correction, if one is needed, is part of the story.
- **Epic 7 runs concurrently** over the same write-path, router, descriptor and coverage-test files. Reconcile carefully at the merge.
- **Range-end cleanup, after Epic 7's merge:** DW-1562, the Devices-list Delete row action on Epic 7's row-action route; and DW-1555, RSA and symmetric-key wallet create and edit.
- **Open at the merge gate:** DW-1502, whether a server-only refusal sentence must also be published in Fixed strings.
- **Downstream:**
  - Epic 9's editors extend the form contract and take over `web-applications/list/edit/:id`.
  - Story 9.3 owns the Roles- and Resources-list Delete row actions.
  - Story 9.5 owns the X.509-list row action and the wallet delete.
  - Epic 12 needs Epics 7 and 8 merged.

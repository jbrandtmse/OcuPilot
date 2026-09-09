---
name: Adversarial review — the 2026-09-08 update (AD-48, LogSourcePort, AD-21, AD-3)
type: review
lens: adversarial
scope: 'Material changed in the 2026-09-08 update pass only: new AD-48; the LogFilePort -> LogSourcePort rename and its broadened scope; the amended clause in AD-21 (globals and namespace selection); the amended clause in AD-3 (%SYS.Task as the semantic-half source).'
target: ARCHITECTURE-SPINE.md
date: '2026-09-08'
method: 'Construct pairs of units one level down that each obey every AD to the letter and still build incompatibly. Claims are checked against the running ocupilot-iris instance where the instance can settle them.'
verdict: 'AD-48 closes the ownership hole it names and misses the boundary. Three sanctioned paths still reach ^ERRORS outside the port, the namespace-selection rule is not implementable as written, the delete has no expressible fingerprint, and AD-48 binds the wrong ADs — AD-35 above all.'
findings: 12
severity: '3 critical, 3 high, 1 medium-high, 4 medium, 1 low-medium'
---

# Adversarial review — the 2026-09-08 update

## How this review was run

The lens is scoped to what the 2026-09-08 pass changed. For each changed clause I built two
units one level down — a slice and a tool, a read tool and a screen, a generator and a schema
author — gave each of them the whole spine, and let each satisfy every AD literally. Where the
two units then produce artifacts that cannot both be right, that is a finding. Where the spine
does not contain enough text for either unit to be wrong, that is a worse finding.

Instance claims were settled against `ocupilot-iris` (IRIS for Health 2026.2, build 221U) rather
than reasoned about. Probes are quoted inline and marked **Probed**.

### What the update got right, stated once so the findings are not read as a verdict on the whole

- The diagnosis in the memlog is correct and was not obvious: `LogFilePort`'s file-only scope was
  never reasoned about, it was assumed, and under the absolute boundary rule FR-63's read
  genuinely had no owner. Finding an unexamined assumption in a document this dense is the hard
  part.
- The rename over a widened `LogFilePort` is the right of the three alternatives, for the reason
  given — a port is defined by what sits outside it, not by transport — and rejecting a sixth
  `ErrorLogPort` correctly anticipated the `GlobalPort` attractor.
- **The sharp half is the valuable half.** "The delete is an ordinary write" and "a builder who
  reads *no `AdminPort` call* as *not a real write* produces exactly the unconfirmed, unaudited
  deletion this spine exists to prevent" is the single most useful sentence added in this pass.
  Every finding below assumes that sentence stands.
- **Probed and confirmed:** no `%Api.Admin.Endpoints.*` class on the instance has `Err` or `Error`
  in its name. AD-48's premise — that no admin API endpoint backs the error log — holds.
- **Probed and confirmed:** in `HSCUSTOM`, `^ERRORS` is unmapped and resolves to the namespace's
  own globals database (`^/durable/iris/mgr/HSCUSTOM/`). AD-48's "held per namespace" is exact.

The findings below are what the pass then failed to carry through.

---

## Summary table

| # | Severity | Units that diverge | One-line claim |
| --- | --- | --- | --- |
| 1 | **Critical** | `Area/Log` error-log screen × `log.*.delete` write tool | Two namespaces bind to one screen — the route's `?ns=` and the drill's own namespace level — and a compliant delete can purge the wrong namespace. |
| 2 | **Critical** | error-log read tool × the screen | AD-48 omits AD-35 from its Binds; SEC-12's read-path redaction clause is in no AD; AD-48 then widens the surface from one namespace to all of them. |
| 3 | **Critical** | `LogSourcePort` gate × `Screen/Tool` dispatch gate | AD-29's single static descriptor resource cannot express a per-namespace database resource, and AD-29's own headline invariant fails. |
| 4 | **High** | `Area/Log` slice × `Port/LogSourcePort` | The bound harvest companion still routes error-log access into `Area/Log/` through `%CSP.ErrorLog` — which is a CSP error *page*, not a store. |
| 5 | **High** | proposal mint × confirm | AD-6's fingerprint vocabulary is field-based; a set-delete has no property set, and three compliant readings give livelock, silent residue, or no check at all. |
| 6 | **High** | schema generator × screen editor | AD-21's amended "no filesystem path from a caller, **anywhere**" contradicts AD-3's derived field lists, which carry `OutputDirectory` on a Release 1 write. |
| 7 | **Medium–High** | schema generator × tool author | The Task template's `Settings` object falls through both halves of AD-3, and AD-3's own fallback classifies it as **secret**. |
| 8 | **Medium** | task write tool × task screen | AD-3's `%SYS.Task` clause names a class holding no property definitions, and introduces a conditional privilege AD-8 cannot express. |
| 9 | **Medium** | harvested handler body × the port | AD-23 plus the capability map still sanction a slice-resident handler body reaching `^ERRORS`. |
| 10 | **Medium** | `LogSourcePort` × AD-16 | AD-16's rule and Binds are about `%SYS`; AD-48 assigns it a switch to a namespace chosen from data. |
| 11 | **Low–Medium** | documentation × itself | Both spine diagrams and one C4 node still carry `LogFile` and manager-directory-only scope. |
| 12 | **Medium** | `Kernel` prohibited set × the Logs area's only agent write | AD-10 does not close over the new write; the Logs area's sole agent write is a bulk deletion of diagnostic evidence. |

---

## 1. Two namespaces bind to one screen, and the delete can purge the wrong one · **CRITICAL**

**Units.** `Area/Log`'s application-error-log screen and its signal store (AD-19) × `Screen/Tool`'s
`log.applicationerrors.delete` write tool and the proposal minter (`Kernel/Proposal/`).

### Unit A — the screen, fully compliant

The builder reads FR-63 ("a user can drill from **namespaces** to dates to errors"), EXPERIENCE.md
line 84 (archetype `drill-down`, "namespaces → dates → errors"), and AD-48's new clause ("the
target namespace reaches it as **a selection from the set the user can read**"). Level 1 of the
drill is therefore a list of every namespace the user can read. The screen obeys AD-36 (one
descriptor-declared read, bounded, reports truncation), AD-29 (a declared gate), AD-21 (a
selection, not a caller string) and AD-48 (through the port, no `Set $NAMESPACE` of its own).
It ignores `?ns=`, because on this screen the namespace is *content*, not scope.

### Unit B — the delete tool, fully compliant

The builder reads AD-44: "**The namespace in the route is data scope, not decoration.** It selects
the namespace **every read and write on that screen** executes against (AD-13's scope), it is
carried into proposals and change events." And AD-13: every entity reference crossing a boundary
carries `(entity type, scope, id)` "where scope is the namespace for a namespace-scoped object".
So the tool scopes its proposal target to the route's `ns`, mints the fingerprint against that
namespace's `^ERRORS`, and publishes the change event under that scope.

### The incompatibility

The user is on `/ocupilot/logs/application-errors?ns=HSCUSTOM`, drills into `USER`, and picks
"delete all errors in this namespace" from the row-overflow menu (EXPERIENCE.md line 85: the
delete is available "on **any** drill-down level", "by namespace or one error"). The dialog names
the scope the screen believes it is in — `USER`. The proposal's scoped target is `HSCUSTOM`.

AD-6's confirm then does exactly what it is supposed to: it re-reads the target, compares the
fingerprint — against `HSCUSTOM` — finds it matches, and executes. **The wrong namespace's error
log is deleted, with a matching fingerprint, a confirmed diff the user read, and an audit marker
(AD-15) recording the operation as correct.** Every invariant in the spine held. AD-6's fingerprint
cannot catch this, because a fingerprint checks that the target has not *moved*, not that it is the
target the user meant.

This is the only screen in the product where the two namespace sources can differ, and it is
precisely because it is the only screen whose *content* is a list of namespaces. The spine has
sixty screens' worth of "the namespace is the route's `ns`" and one screen that FR-63 and the UX
both describe as ranging over all of them, and it never notices the collision.

### The rule is also not implementable as written, in three separate ways

**(a) "The set the user can read" and the header switch's set are different sets.** EXPERIENCE.md
line 314 defines the namespace switch as "a select listing only namespaces the user can read **and
write**". AD-21's amended clause says "chosen from the set the user **can read**". A user with read
but not write on `USER` is in AD-21's set and not in the header's. So either the error-log screen
cannot reach a namespace whose errors it is entitled to show, or it computes a *second* namespace
list by a different predicate than the shell's — two list computations, no owner named for either,
which is the divergence the spine exists to prevent.

**(b) Nobody is assigned to compute the list.** The candidates are all defensible and all
different: namespaces from `Config.Namespaces:List` (requires the `%SYS` switch and its own
privilege); namespaces where `$System.Security.Check` passes on the globals database's resource;
namespaces where `^ERRORS` is defined (which hides an empty-but-authorized namespace and leaks
existence of a non-empty unauthorized one); or the shell's existing header list. The spine names
none.

**(c) "A selection from the set" is not a wire format, and both readings break something.**
An *index* into a server-enumerated list is literally "a selection" and is not a caller string —
but it breaks AD-13's route grammar (`?ns=<NAMESPACE>`), breaks deep linking (EXPERIENCE.md line
66: "Deep links are honored after sign-in"), breaks the context chip's `<Screen>, <NAMESPACE>`
format, and makes the list order load-bearing across a re-render. A *validated name* is just a
bound-and-membership-checked caller string — which is correct engineering, but then AD-21's
"never as a caller-supplied string" is literally false of every route in the product, since
`?ns=HSCUSTOM` **is** a caller-supplied string. As written the rule cannot be both satisfied and
checked; two builders will read it two ways and produce two URL grammars.

### What to change

1. State that the namespace for **every** screen, this one included, is the route's `ns`, and that
   the error-log drill's first level is a **navigation affordance that sets `ns`**, not a scope of
   its own. Then `?ns=` is the single source and Unit A and Unit B converge by construction.
2. Name one kernel service as the owner of the readable-namespace list, with its exact predicate,
   and say the header switch and the error-log drill both consume it. Reconcile "can read" with
   the UX's "read and write" explicitly — the log screens need read-only namespaces, so the
   header's predicate is the one that should change.
3. Replace "never as a caller-supplied string" with the checkable rule actually intended: *the
   namespace travels as its name and is refused unless it is a member of the server-computed
   readable set, resolved before any `Set $NAMESPACE`.* That is enforceable, testable, and does
   not contradict AD-13.

---

## 2. AD-48 omits AD-35, and the read-path half of SEC-12 is in no AD at all · **CRITICAL**

**Units.** the `log.applicationerrors.read` read tool (feeding `Kernel/Agent/` and thence
`ProviderPort`) × the application-error-log screen.

### The dropped clause

`reviews/review-security.md` SEC-12 (rated HIGH) proposed a rule with **two** halves:

> The credential is resolved immediately before the HTTP send, held in a variable `Kill`ed in the
> same method … **Independently, the application-error-log read tool and viewer pass every returned
> value through the shared secret matcher before it leaves the port — the log is untrusted output
> as well as untrusted input.**

AD-35 kept the first half verbatim in spirit and **dropped the second**. AD-35's rule is entirely
about what `ProviderPort` must not *write*: "`ProviderPort` therefore never lets a credential enter
an exception, a status, a log line or a trap … A test asserts that a forced provider failure leaves
no credential material in the error log." There is no rule anywhere in the spine about what the
error-log **read** path must not *emit*.

### Why the 2026-09-08 pass is the moment this became critical

AD-48 is the AD that promotes the error log from an unowned edge case to a first-class,
port-owned, per-namespace read with a read tool whose output is delimited tool-result content fed
to an external LLM (AD-11, AD-24, AD-36). It is the exact change that turns a dropped clause into
an egress path. And it makes it strictly wider than SEC-12 assumed:

- SEC-12 reasoned about "`^ERRORS` **in the install namespace**" — OcuPilot's own errors.
- AD-48's read is **per namespace, for every namespace the user can read**.

`^ERRORS` is written by `^%ETN`, which captures the **local variable table at the point of an
unhandled error**. So the read tool now ships, to an external provider, the trapped in-memory
variables of *every other application on the instance* — on an IRIS **for Health** instance, that
is PHI and third-party credential material, not merely OcuPilot's own provider key.

### The Binds lines confirm nobody owns it

- **AD-48's Binds:** "`LogSourcePort`, `Area/Log/`; FR-63; **AD-16, AD-21, AD-29**" — AD-35 is
  absent. The AD that created the port's new responsibility does not cite the AD that governs
  secrets in the thing it now owns.
- **AD-35's Binds:** "NFR-5, FR-63, FR-62; `ProviderPort`, the error log and messages.log
  **screens**" — `LogSourcePort` is absent, and "screens" excludes the read tool by its own words.

### The primary redaction mechanism is structurally inapplicable here

The Consistency Conventions "Secrets" row is explicit that redaction is **schema-driven**: "a field
is secret because its **descriptor says so** (FR-21), not because its name matched a pattern; a
wallet secret field named `Value` defeats any matcher. A name-pattern matcher runs as a **second,
backstop** layer."

An `^ERRORS` row is free-form trap data with **no schema and no fields**. The primary mechanism has
nothing to key on, and the spine invokes the backstop matcher nowhere on this path. So the source
with the least structure is the one source with no redaction rule.

### The two units diverge

- **Unit A (read tool).** Reads AD-35's Binds, sees `ProviderPort` and "screens", concludes
  redaction is ProviderPort's problem on the write side, and emits `^ERRORS` rows verbatim into
  tool-result content. Compliant: AD-36 (same view as the screen, narrowed by AD-24), AD-24 (row,
  size and per-field caps applied), AD-11 (delimited, never instruction).
- **Unit B (screen).** Reads AD-35's "the error log … screens" in its Binds, applies the backstop
  matcher client-side for display.

Result: the screen shows redacted text, the tool sends unredacted text, and the difference is
invisible — AD-36's "a screen and its tool cannot diverge" is satisfied on *filter, sort and field
set*, which is all AD-36 constrains, and violated on content. AD-11's seeded-injection test asserts
zero proposals, navigations and outbound requests; it does not assert on egress content.

### What to change

1. Restore SEC-12's second clause into AD-35, at the **port**, before the value reaches either
   consumer: a log source with no schema is redacted by the backstop matcher inside
   `LogSourcePort`, and both the screen and the tool receive the redacted form.
2. Add AD-35 to AD-48's Binds; add `LogSourcePort` and "the error-log read tool" to AD-35's Binds.
3. Extend AD-35's test: currently it forces a *provider* failure and checks `^ERRORS`. Add the
   mirror — plant credential-shaped material in `^ERRORS` in a non-install namespace and assert it
   does not appear in the read tool's result.
4. State AD-35's namespace explicitly. It is written as though there is one error log; under AD-48
   there are as many as there are namespaces, and its existing test must name which one it reads.

---

## 3. AD-29's per-port gate cannot express a per-namespace resource, and its own invariant fails · **CRITICAL**

**Units.** `Port/LogSourcePort`'s declared gate × `Screen/Tool`'s dispatch gate (AD-8).

### The two rules do not agree with each other, before `^ERRORS` is even considered

- **AD-8:** the gate is evaluated "against the privileges the screen descriptor names — **a set of
  `(resource, permission)` pairs, never a single resource** … a descriptor field that holds one
  string cannot express what the screen actually requires."
- **AD-29:** "each declares **the resource** it requires and evaluates it with
  `$System.Security.Check` before any call, using **the resource** its screen descriptor names."

AD-29 is written in the singular that AD-8 was explicitly amended to abolish. AD-48 binds AD-29
for the error-log gate, so the new write inherits the stale wording.

### And for `^ERRORS` the resource is not a constant at all

**Probed on `ocupilot-iris`:**

```
HSCUSTOM  ->  globals DB HSCUSTOM         resource %DB_HSCUSTOM
USER      ->  globals DB USER             resource %DB_USER
%SYS      ->  globals DB IRISSYS          resource %DB_IRISSYS
          ->  HSLIB / HSSYS / HSSYSLOCALTEMP  ->  %DB_HSLIB / %DB_HSSYS / %DB_HSSYSLOCALTEMP
```

and `^ERRORS` in `HSCUSTOM` resolves to `^/durable/iris/mgr/HSCUSTOM/` — unmapped, in the
namespace's own globals database.

The resource required to read `^ERRORS` in namespace *N* is therefore
`%DB_<globals database of N>:READ` — **a function of the namespace the caller selected**, not a
literal a descriptor can name at build time. AD-29's mechanism is unbuildable for the source AD-48
just handed it.

### The two units

- **Unit A.** Declares `%Admin_Operate:U` in the descriptor — supported by PRD §396: "The log
  endpoints (FR-60, FR-62, FR-63) require **the same resource the classic portal's log pages
  require**." Gate passes once, per screen. The port then reads every namespace's `^ERRORS` under
  that single check. Fully compliant with AD-29 as written.
- **Unit B.** Computes `%DB_<globalsdb(ns)>:R` at call time and checks it per request. Also fully
  compliant — AD-29 does not forbid computing the resource.

Unit A breaks **AD-29's own headline invariant**: "a metric, a log line and an audit row reach a
user through OcuPilot **only if that user could have read them directly**." An operator with
`%Admin_Operate` but no read on `USER` reads `USER`'s trapped variable tables through OcuPilot and
could not have read them directly. That is precisely the bypass AD-29 was written to close, arriving
through the port AD-48 just widened.

### The backstop exists but is unspecified, and its failure mode is wrong

IRIS's own database security *is* a real backstop here — AD-1 and AD-8 put the user's `$ROLES` on
the process, and AD-9 forbids re-entry from an escalated frame, so a direct `$Data(^ERRORS)` in an
unauthorized namespace raises `<PROTECT>`. But:

- **AD-2's `<PROTECT>` → 403 mapping is AdminPort's alone** (AD-2 step 7). `LogSourcePort` has no
  equivalent rule, so under AD-12 an unauthorized read renders as a generic internal-failure
  envelope, not as AD-8's requirement that "a denial names the pair that failed so the UX can say
  which privilege is missing."
- Unit A, having passed its own gate, will treat a `<PROTECT>` as an unexpected error and log it —
  and under AD-35's absent read-path rule (finding 2) the trap text goes into the error log the
  screen displays.
- A builder relying on the backstop and a builder pre-checking produce different HTTP statuses
  (500 vs 403) for the same request, which AD-39's "one envelope, two renderings" cannot reconcile
  because the *status class* differs.

### What to change

1. Amend AD-29's wording from "the resource" to "the privilege **set** (AD-8)" — a one-line fix
   that was missed when AD-8 was amended.
2. Add to AD-29: *where a port's required privilege is a function of the request's scope, the
   descriptor declares the **rule** that computes it, not a literal, and the port evaluates it per
   call.* Name `%DB_<globals database of the selected namespace>:READ` as that rule for `^ERRORS`,
   **in addition to** the classic page's `%Admin_Operate:U`, and say the gate requires both.
3. Give `LogSourcePort` the `<PROTECT>` → 403 mapping that AD-2 gives `AdminPort`, and say the
   denial names the computed pair.

---

## 4. The bound harvest companion still routes error-log access into a slice, through the wrong class · **HIGH**

**Units.** `Area/Log/` (per the harvest plan) × `Port/LogSourcePort` (per AD-48).

`harvest/HARVEST-PLAN.md` is named in the spine's own `companions:` frontmatter and is, by the
spine's opening section, "the file-level plan for reused sibling code" — the document a builder
opens to start the Logs slice. Two adjacent rows in its "Logs (step 1 and step 4)" table:

```
line 81 | The tail-with-byte-offset-paging pattern | new | `Port/LogSourcePort` | … The application
         error log is not a file — it is the `^ERRORS` global per namespace, owned by the same port (AD-48) |
line 82 | Application error log access | `%CSP.ErrorLog` | `Area/Log/` | System class, not a harvest |
```

Line 81 was updated for AD-48. **Line 82, immediately below it, was not.** It still names:

- **a slice (`Area/Log/`) as the home** — flatly contradicting AD-48's "no slice touches `^ERRORS`
  directly" and "`LogSourcePort` owns it — reads and deletes alike"; and
- **`%CSP.ErrorLog` as the backing class.**

### `%CSP.ErrorLog` is not a store

**Probed on `ocupilot-iris`:** `%CSP.ErrorLog` extends **`%CSP.Page`**, and its own class
documentation reads *"This is the default CSP error page. Extend any custom error pages from this
class. `HyperEventError` defines the response for errors during a hyperevent."*

It is the HTML page IRIS renders when a CSP request fails. It has no relationship to the
application error log. A builder following line 82 opens a `%CSP.Page` subclass, finds no data, and
then does one of two things — invents a source, or reaches `^ERRORS` from inside `Area/Log/`,
which is exactly the boundary violation AD-48 exists to prevent, arrived at by following a document
the spine binds.

The same stale claim survives in `.memlog.md` line 21 ("The application error log is the
`%CSP.ErrorLog` class"), which is the original OQ-4 resolution the AD-48 probe superseded. The
update pass corrected the spine and left the two documents that a builder actually reads first.

**This is the direct answer to "does AD-48 close the boundary hole": no.** The hole is not in
another AD's wording — it is in the companion the spine points builders at.

**What to change.** Replace line 82's Source and Destination with `^ERRORS` and
`Port/LogSourcePort`, strike `%CSP.ErrorLog` entirely, and correct the memlog entry so the
superseded claim is not mined later as evidence.

---

## 5. A set-delete has no expressible fingerprint; three compliant readings, three different products · **HIGH**

**Units.** `Kernel/Proposal/` mint × `Kernel/Proposal/` confirm, built by two people from AD-6 and
AD-48.

AD-48 says the delete "shows a diff the instance computed (**the scope and count to be removed**)".
AD-6 says:

> The fingerprint covers **the complete property set the write will send** (AD-4), excluding fields
> the endpoint itself mutates as a side effect … the descriptor declares the exclusions and the
> default is "everything else".

That vocabulary is **field-based** and presupposes AD-4's read-merge-put over one object. A delete
of a *set of rows* sends no property set at all. AD-6 has no set-target form, so each builder
supplies one:

- **Reading A — fingerprint the count** (the literal reading of AD-48's diff). `^%ETN` writes
  `^ERRORS` continuously and asynchronously; any error anywhere in that namespace between mint and
  confirm changes the count, so the fingerprint mismatches and AD-6 refuses. **On a busy instance —
  exactly the instance where an operator wants to purge errors — the proposal can never be
  confirmed.** With AD-6's 10-minute expiry this is an unbreakable livelock, and it is a
  demo-day failure mode: the more errors the instance is producing, the less the feature works.
- **Reading B — fingerprint the enumerated id set.** Confirm succeeds. But the write then deletes
  only what existed at mint time, silently leaving rows the user was shown a count for and believes
  they removed. The audit marker (AD-15) records the proposal's scope, not the residue, so the
  discrepancy is invisible in the authoritative record.
- **Reading C — fingerprint nothing.** AD-6 says "**the descriptor declares the exclusions**". A
  descriptor that excludes everything is compliant, and confirm then performs no state check at
  all — AD-6's entire purpose opted out of through a descriptor field, with no build check to catch
  it.

AD-6's exclusion mechanism cannot express the thing that would fix this, because it excludes
**fields**, not **members**: there is no way to say "exclude rows that arrived since the read".

### AD-13 and AD-34 compound it

- **AD-13** requires the triple `(entity type, scope, id)` on every proposal target, change event,
  highlight target and audit marker. **A namespace-wide delete has no id.** Three builders produce
  `id = ""`, `id = <namespace>` (duplicating scope), and a synthetic composite under AD-5's
  composite-id rule. Each produces a different audit marker and a different change-event key, and
  AD-14's closed entity-type enum does not make the *id* consistent — only the type.
- **AD-34** cancels "siblings **on the same scoped target**". Under any id scheme, a namespace-wide
  delete and a single-error delete are different targets, so confirming the namespace-wide delete
  does not cancel the pending single-error proposal inside it. The single one then fails at
  fingerprint re-read (correct, per AD-37) — but as an error the user did not cause, on a proposal
  the UX says should have shown "sibling proposal was confirmed".

**What to change.** Add a **set-target** form to AD-13 and AD-6 explicitly:

- a set target is `(entity type, scope, selector)` with the selector stored server-side;
- its fingerprint is over the **enumerated member ids at mint**, not a count;
- the diff states "N errors as of `<mint time>`", and the confirm result reports arrivals since as
  untouched, so Reading B's silent residue becomes visible rather than eliminated;
- AD-34's sibling cancellation matches a set target against members contained in it;
- AD-15's marker records the enumerated set, not the scope alone.

---

## 6. AD-21's amended "no path from a caller, anywhere" contradicts AD-3's derived field lists · **HIGH**

**Units.** the AD-3 build-time schema generator × the `Area/Task` screen editor (FR-53, Release 1).

AD-21's amended rule states it absolutely, and the amendment is what makes the conflict bite:

> **No OcuPilot endpoint accepts a filesystem path from a caller, anywhere** — not only the log
> endpoints.

AD-3 states the opposite instruction for the same tool:

> A write tool's **field list and each field's JSON type** are derived at build time from the
> endpoint's own body-template method; they are **never transcribed by hand** … A write tool whose
> field list was typed by a human, for an endpoint that publishes a template, is a **review
> failure**.

**Probed on `ocupilot-iris`** — `%Api.Admin.Endpoints.Task.CRUD:PutAndPostSchema()`, which is the
single `PutAndPostSchema` case AD-3 itself counts, contains:

```objectscript
"OutputDirectory"    : "",
"OutputFilename"     : "",
"OutputFileIsBinary" : true,
```

So the Release 1 task write tool's field list, **derived exactly as AD-3 mandates**, accepts a
filesystem directory and filename from a caller — including from the model. Both ADs cannot be
followed.

### The two units

- **Generator author.** Emits `OutputDirectory`, because AD-3 says the list is derived and only
  `required` / `enum` / `description` are hand-authored, and because omitting a derived field is
  itself the review failure AD-3 names.
- **Screen author.** Reads AD-21's "anywhere" and omits the field from the editor.

The tool schema and the screen editor now disagree about the field set — the exact divergence AD-3
and AD-5 exist to prevent — and **AD-4 makes it destructive**: "read fresh, apply the diff, send the
**complete property set**". A save from the screen that omits `OutputDirectory` sends a complete
body without it and **erases the operator's configured task output directory**, which is the precise
class of accident AD-4 was inverted to prevent.

Note this is not confined to tasks; it is the general shape of "derive from the vendor, then apply
an OcuPilot-absolute rule to the result". The `anywhere` broadening in this pass converted a rule
about OcuPilot's own log endpoints into a rule about ~40 vendor-derived payloads, without checking
what those payloads contain.

**What to change.** Scope AD-21's "anywhere" to **OcuPilot-authored** endpoints, and add the
missing distinction: *a vendor-derived field that happens to be a path is passed through to the
vendor's own validation verbatim; OcuPilot never resolves, normalizes, opens or serves it, and the
generator marks it as a pass-through path in the descriptor so the confirm diff can show it as
one.* That keeps AD-21's actual security property (OcuPilot never turns a caller string into a
file it reads) while letting AD-3 stay absolute.

---

## 7. `Settings` falls through both halves of AD-3, and AD-3's fallback makes it secret · **MEDIUM–HIGH**

**Units.** the schema generator × the tool author writing the semantic half.

**Probed:** the Task template's final field is `"Settings" : {}` — a free-form object whose legal
keys depend on the value of **another field** (`TaskClass`) and are declared on the named
`%SYS.Task.Definition` subclass, not on the task itself.

- **The derived half** (AD-3) yields "an object with no fields". A prototype of placeholder values
  cannot describe it, because its shape is not fixed at build time.
- **The semantic half**, which the 2026-09-08 amendment newly points at `%SYS.Task`'s properties,
  says nothing about it either — `Settings` is not a `%SYS.Task` property vocabulary, it is a
  reflection over a class named at runtime.

AD-3's written fallback then fires:

> **A field the generator cannot classify is treated as secret.**

Applied literally, `Settings` becomes secret-typed, and the cascade is severe and entirely
compliant: AD-6 makes it a confirm-channel-only key ("the only keys a client may supply at confirm
are the fields the descriptor declared secret-typed"); AD-24 never sends it to the model; AD-41
excludes it from the ledger; AD-5's context serializer drops it. **A task's entire parameter payload
becomes invisible to the agent, to the ledger, and to the diff the user reviews** — while remaining
the only part of the payload a client may inject at confirm.

But AD-3's *next* sentence points the other way: "The generator additionally refuses to emit any
field whose name matches the credential pattern as an ordinary field, so **a classification miss
fails the build** rather than reaching the model." So one builder ships `Settings` as secret and
one fails the build on it. Neither is wrong.

**What to change.** Add a third classification to AD-3 — **opaque pass-through** — for a template
field that is a free-form object: neither secret nor schema-described, shown verbatim in the diff,
bounded by AD-24's per-field size cap, and never accepted on the confirm channel. State that the
"unclassified ⇒ secret" fallback applies to **scalar** fields only, which is what it was written
for.

---

## 8. The `%SYS.Task` clause names a class with no property definitions, and adds a privilege AD-8 cannot express · **MEDIUM**

**Units.** the task write tool's descriptor × the task screen's privilege set.

### The class name is wrong for the use the clause puts it to

AD-3's amended text: "the source is **`%SYS.Task`'s 66 documented properties**".

**Probed:** `%SYS.Task` has **66 compiled properties** — the count is right — but **zero property
definitions of its own**. All 64 declared properties, and every description AD-3 depends on
(`TimePeriod`'s 0–5 vocabulary, `DailyFrequency`'s 0/1 with its increment/start/end triple, the
expiry offsets), are declared on **`%SYS.TaskSuper`**. The other two of the 66 are `%%OID`
(`%Library.RegisteredObject`) and `%Concurrency` (`%Library.Persistent`) — framework properties with
no documentation at all.

So the count silently includes two non-task properties, and a builder or a generator pointed at
`%SYS.Task`'s definition finds nothing. Name `%SYS.TaskSuper`, or say "66 **compiled** (inherited)
properties, declared on `%SYS.TaskSuper`".

### The `RunAsUser` privilege is conditional, and AD-8's gate is static

**Probed** — `%SYS.TaskSuper:RunAsUser` documents precisely what AD-3 claims:

> *"Username of user to run as. A user must have the `%Admin_Secure:Use` privilege to define a task
> to run as another user."*

AD-3 is right that the vocabulary is there. But AD-8's gate is "the privileges **the screen
descriptor names**" — a static set, evaluated at call time. There is no mechanism anywhere in the
spine for *"this privilege is required only when this field is present in the payload."*

- **Unit A** declares the screen's set as the endpoint's own and lets the vendor refuse. Result: a
  proposal is minted, the diff is reviewed, the user confirms, AD-34's token is **burned in the
  same atomic transition as the write**, and the write then fails 403 at the vendor's gate. AD-6
  explicitly promises the opposite — "Confirm re-checks **authorization** as well as state" — and
  it cannot keep that promise for a privilege it does not know is required.
- **Unit B** adds `%Admin_Secure:U` to the screen's declared set, which locks every task edit out
  for users who could legitimately edit tasks that never touch `RunAsUser`, and contradicts AD-44's
  "the privilege set is the union of the admin API's requirement".

Both obey AD-3 and AD-8.

### A related defect the same clause exposes

**Probed** — `Task.CRUD:ResourcesOR()` returns `$LISTBUILD("%Admin_Task", "%Admin_Operate")`, an
**OR**. AD-44 says the descriptor's privilege set is "**the union** of the admin API's requirement
and any custom resource assigned to that classic key", and AD-8 says the gate "**requires all of
it**". Unioning an OR-list into an AND-set makes OcuPilot strictly stricter than the vendor and
refuses users the classic portal admits — a silent parity regression across every admin-backed
screen, surfaced here because AD-3's amendment is the first clause to look closely at this endpoint.

**What to change.** (a) AD-3 names `%SYS.TaskSuper`. (b) AD-8 gains a **conditional** privilege
form — *"field X present in the payload ⇒ additionally require `R:P`"* — evaluated **at the write**,
inside AD-34's transition, alongside AD-10's predicates, so a confirm cannot burn a token for a
write that will be refused. (c) AD-44 states that a vendor `ResourcesOR()` list joins the descriptor
set as **one OR-group**, not as separate AND members.

---

## 9. AD-23 and the capability map still sanction a slice-resident body reaching `^ERRORS` · **MEDIUM**

**Units.** a harvested `ExecuteMCPv2.REST.*` handler body in `Area/Log/` × `Port/LogSourcePort`.

The Capability → Architecture Map row for **5.10 Logs** lists its governing ADs as
"AD-21, **AD-23**, AD-26 (FR-61 audit list), AD-29, AD-35, AD-46". AD-23's rule is that a harvested
body **keeps its call sites** and is **not edited**:

> Where OcuPilot harvests an `ExecuteMCPv2.REST.*` handler body, it inherits from an OcuPilot base
> class exposing `RenderResponseBody(…)` … **Handler bodies are not edited to change response
> shape.**

The memlog's founding decision was that the error log is one of the places OcuPilot harvests a
handler body ("only where no route exists — messages.log, application error log, alerts history
tail, and Stage 5 parity — does OcuPilot harvest an `ExecuteMCPv2.REST.*` handler body").

A harvested body lands in `Api/` or `Area/Log/`, not in `Port/`. AD-48 says "no slice touches
`^ERRORS` directly" and AD-23 says the body is not edited. A builder reconciling the two can
legitimately conclude the harvested body is the exception AD-23 carves out — and AD-48 does not
mention harvesting at all, so nothing contradicts him.

The practical harvest has since evaporated (HARVEST-PLAN.md line 81 now says "No sibling has it"),
which is why this is Medium rather than High — but the capability map still points 5.10 at AD-23,
and the map is one of the three places a builder looks before writing code.

**What to change.** Drop AD-23 from the 5.10 row — it now applies only to Stage 5 — or add one
sentence to AD-48: *a harvested body that touches `^ERRORS` is relocated into the port; AD-23's
no-edit rule governs response shape, not placement.*

---

## 10. AD-16's rule and Binds are about `%SYS`; AD-48 assigns it a switch driven by data · **MEDIUM**

AD-48: "The port performs the namespace switch **by AD-16's explicit save and restore**."

AD-16 as written does not cover it:

- **Its rule is literally about `%SYS`:** "`Set tOrigNS = $NAMESPACE` … `Set $NAMESPACE = "%SYS"` …
  restore, with the restore as the **first** line of every `Catch`."
- **Its Binds line is "every class that reaches `%SYS`; AdminPort, the installer, security reads"**
  — `LogSourcePort` is absent, and its target is not `%SYS`.

The difference is material, not cosmetic. `%SYS` is a compile-time constant; AD-48's target is
**data**, and data has failure modes a constant does not:

- **The namespace may not exist** → `<NAMESPACE>` is raised **by the assignment itself**, so AD-16's
  "restore as the first line of the Catch" restores to a value that was never left. No rule says
  the target is validated before the assignment.
- **The namespace may exist but be unreadable** → covered by finding 3.
- **The namespace may be `%SYS`.** Nothing in AD-21's amended clause or AD-48 excludes `%SYS` from
  "the set the user can read". `%SYS`'s `^ERRORS` is where security, configuration and licensing
  failures land, and under finding 2's missing redaction rule those rows reach the model. The one
  namespace that most needs an explicit decision is the one neither AD mentions.

**What to change.** Generalize AD-16 to cover **any** namespace switch, including one whose target
comes from data; add `LogSourcePort` to its Binds; require the target to be validated against the
server-computed readable set **before** the assignment; and state explicitly whether `%SYS` is a
selectable namespace for the error-log screen.

---

## 11. The rename did not reach both diagrams or the C4 store node · **LOW–MEDIUM**

The prose, the paradigm table and the port list were all updated correctly. Four artifacts were
not, and two of them are the diagrams a builder reads first:

| File · line | Current text | Problem |
| --- | --- | --- |
| `ARCHITECTURE-SPINE.md:64` | `Registry --> Ports["Ports: Admin, Monitor, Mgmnt, LogFile"]` | Pre-rename name, in the Invariants & Rules diagram |
| `ARCHITECTURE-SPINE.md:68` | `Ports --> Mgr["Manager directory files"]` | The port's **only** outside edge in that diagram; `^ERRORS` absent, so the diagram still asserts the file-only scope AD-48 abolished |
| `ARCHITECTURE-SPINE.md:548` | `Ports --> Files["Manager directory logs"]` | Same omission in the Structural Seed container diagram |
| `C4.md:51` | `Files[("Manager directory<br/>messages.log · alerts.log")]` | The only store behind the port, though `C4.md:98` **was** correctly updated to "manager files + `^ERRORS` global" — so C4.md contradicts itself |

Two Binds lines are also now inaccurate and are covered as findings in their own right because the
consequence is behavioral, not cosmetic: **AD-35** (finding 2) and **AD-16** (finding 10). AD-29's
Binds *was* updated to `LogSourcePort`, correctly.

A diagram that still shows one store behind the port is exactly the artifact that lets a builder
conclude the port is about files.

---

## 12. AD-10 does not close over the new write, and the Logs area's only agent write destroys evidence · **MEDIUM**

FR-63's delete is, by the PRD's own framing, **the Logs area's SM-3 write** — "Delete is a write
tool with a proposal, **so the Logs area has a confirmable agent write**". So the single thing the
agent can write in the Logs area is *delete the error log*.

AD-10 defines the prohibited set "**by effect, not by verb**" and enumerates: deleting or disabling
principals, granting privilege by any path, disabling the path that serves OcuPilot, terminating
system processes, and deleting OcuPilot's own artifacts. **Destruction of diagnostic evidence is not
on it**, and AD-48 did not revisit it.

Two ADs written in this pass's neighborhood assume the error log persists:

- **AD-35** makes it a security-relevant surface and asserts a test over its contents.
- **AD-46** establishes as a principle that OcuPilot never hides its own records, "because a portal
  that concealed its own writes would be exactly the anti-pattern the product exists to correct."

Under AD-11's stated threat model — "the model is assumed compromised by anything it reads", and
`^ERRORS` is now one of the things it reads — a namespace-wide error-log delete is the cheapest
anti-forensic action available in Release 1, and it is proposable at the ordinary confirmation
level.

This is an **authorization-complete, audited** action: AD-6 confirms it, AD-15 marks it, AD-34 makes
it atomic. So it is a *policy* gap, not a hole — but AD-22 defers per-tool policy to polish week,
which leaves AD-10 as Release 1's only lever, and AD-10 does not reach it.

**What to change.** Make the call explicitly, either way. Either add *"deleting the application
error log for an entire namespace"* to AD-10's set as agent-unproposable (leaving individual
deletes, which still satisfy SM-3), or state in AD-48 that a bulk error-log delete is accepted as
an ordinary confirmed write and why — so the next reader does not have to re-derive it.

---

## What I checked and did not find a problem with

Recorded so the absence is informative rather than ambiguous.

- **AD-48's factual premises all hold.** `^ERRORS` is per-namespace and unmapped (probed); no
  `%Api.Admin.Endpoints.*` class names errors (probed); the retention/`^%ETN` claims match the
  PRD's own OQ-4 closure.
- **The choice of rename over a sixth port is right**, and the memlog's rejection rationale for
  `ErrorLogPort` correctly anticipates the `GlobalPort` attractor. Nothing below changes that.
- **messages.log and alerts.log are genuinely unaffected**, as AD-48 claims. AD-21's file rules,
  the fixed enum and `$System.Util.ManagerDirectory()` all still apply unchanged, and the
  broadening does not weaken them.
- **AD-30, AD-40 and AD-41 need no amendment for the new write.** The write-side gate placement,
  the "not callable from a turn" rule and the ledger bounds are all expressed at the write, so they
  cover a port-owned write with no admin API call as readily as an AdminPort one. AD-40's rule that
  every gate is evaluated *at the write* is what makes AD-48's "the absence of an endpoint changes
  nothing" true, and it is already written that way.
- **AD-43's proposal-pause channel works here** without amendment: proposal-open/closed events are
  published for a **scoped entity type**, which a set target satisfies even though AD-13's *id*
  does not (finding 5).
- **AD-46 is not weakened by AD-48** — the agent's audit markers stay ordinary rows in the audit
  database, which is a different store from `^ERRORS`. The interaction worth naming is finding 12's,
  which is about AD-10, not AD-46.
- **AD-9's containment holds.** The port is not a storage class and does not escalate, so
  IRIS's own database security remains a real backstop for `^ERRORS` (finding 3 is about the gate's
  *expressiveness* and its failure mode, not about escalation).

---

## Recommended order of repair

Findings 1, 2 and 3 are each independently sufficient to produce a wrong or unsafe build from a
fully compliant reading, and 1 and 3 both come down to the same missing artifact — **a named owner
and predicate for the readable-namespace set**. Fixing that one thing closes most of 1 and gives 3
its computed resource.

1. **Finding 1** — declare `?ns=` the single namespace source for every screen; name the owner and
   predicate of the readable-namespace list; replace "never a caller string" with the membership
   check actually meant.
2. **Finding 2** — restore SEC-12's read-path redaction clause into AD-35, at the port; fix both
   Binds lines. This is the only finding with an external-egress consequence.
3. **Finding 3** — AD-29 to "privilege **set**"; add the computed-resource rule; give
   `LogSourcePort` AD-2's `<PROTECT>` → 403 mapping.
4. **Finding 4** — one line in `HARVEST-PLAN.md`; cheapest fix in the list, and it is the literal
   answer to whether the boundary is closed.
5. **Finding 5** — add the set-target form to AD-6 and AD-13 before any proposal code is written;
   retrofitting a target shape after `Kernel/Proposal/` exists is expensive.
6. **Finding 6** — scope AD-21's "anywhere"; this blocks the AD-3 generator, which is a build-step-0
   dependency for ~40 write tools.
7. Findings 7, 8, 9, 10, 12 — clarifications, each a sentence or two.
8. Finding 11 — documentation sweep.

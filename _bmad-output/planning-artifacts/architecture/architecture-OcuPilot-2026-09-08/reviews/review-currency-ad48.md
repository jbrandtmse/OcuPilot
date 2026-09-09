---
review: currency-and-reality-check (AD-48 / AD-21 / AD-3 amendments)
target: ARCHITECTURE-SPINE.md — AD-48 (new), AD-21 (amended clause), AD-3 (amended clause)
date: 2026-09-09
lens: "Is every factual claim in the changed material true of the running instance, or was it asserted from prose?"
verdict: "Every claim is substantially true. But AD-48 prescribes a namespace switch that the instance makes unnecessary — SYS.ApplicationError already takes namespace as a parameter — and two supporting details (AD-3's DailyFrequency triple, AD-3's '66 documented properties') are wrong in ways that would reach code."
instance: "ocupilot-iris — IRIS for Health 2026.2 (Build 221U), localhost:52774, /durable/iris/mgr"
---

# Currency Review — AD-48, and the amended clauses in AD-21 and AD-3

**Method.** Every claim was re-derived on the running `ocupilot` container (`server: "ocupilot-iris"`),
never from recollection and never from the prose under review. Where the fact could be *observed*
rather than merely *read*, it was observed: `^ERRORS` was undefined on this container at the start of
the review, so entries were seeded with `$$LOG^%ETN()` in `USER` and `HSCUSTOM`, the resulting global
was walked node by node, the purge was exercised against backdated entries, and the vendor read/delete
API was driven end to end. **The instance was restored to its original state** — `^ERRORS` is
undefined in `%SYS`, `HSCUSTOM` and `USER`, as it was before the review.

**Headline.** AD-48's *conclusions* survive contact with the instance: the error log really is a
per-namespace global, no admin API endpoint backs it, and its delete really is a first-class write.
What does not survive is AD-48's *mechanism*. The AD builds the port around an explicit `$NAMESPACE`
save-and-restore. The instance ships `SYS.ApplicationError`, an abstract `%SYS` class whose every read
and every delete takes **namespace as an argument** — verified working from `%SYS` against `USER` and
`HSCUSTOM` with `$NAMESPACE` unchanged before and after. AD-48 as written mandates a hazard (AD-16's
own stated hazard) that this feature does not have.

---

## Verdicts at a glance

| # | Claim | Verdict |
| --- | --- | --- |
| 1 | `^ERRORS`, per namespace, written by `^%ETN` | **CONFIRMED** — and the subscript structure is established below, both from source and empirically |
| 2 | Retention governed by `Config.Startup.ErrorPurge` | **CONFIRMED, qualified** — the property is a *setting*; the purge is a nightly task that an operator can suspend |
| 3 | `messages.log` is a plain file under the manager directory, no backing class | **CONFIRMED, qualified** — true here, but the path is operator-configurable via `Config.config.console` |
| 4a | `%SYS.Task` has **66 documented properties** | **WRONG (partly)** — 66 properties, but 2 are compiler artifacts and only **49** are documented |
| 4b | `TimePeriod` 0–5 = daily / weekly / monthly / monthly-special / run-after / on-demand | **CONFIRMED** — verbatim, and cross-checked at runtime |
| 4c | `DailyFrequency` 0=once, 1=several, "with an increment/start/end **triple**" | **WRONG** — it is a *quadruple*; the missing member is the units selector, and omitting it breaks the tool |
| 4d | "the expiry offsets" are among the vocabularies already written down | **WRONG** — the three offset properties carry no description at all |
| 4e | Setting `RunAsUser` to another user requires `%Admin_Secure:Use` | **CONFIRMED as documentation, UNVERIFIABLE as enforcement** — bodies are stripped in the shipped class |
| — | *(new)* AD-48's namespace switch is necessary | **WRONG** — `SYS.ApplicationError` parameterizes namespace; see §5 |

---

## 1. `^ERRORS`, `^%ETN`, and per-namespace holding — **CONFIRMED**

### The routine exists

```
%ETN.INT exists in %SYS: 1 | %ETN.MAC: 0 | %ETN.OBJ: 1
```

`%ETN` ships as a distributed `.int` plus its `.obj` in **IRISLIB** (timestamp `2026-06-26 10:08:10`).
There is no `.mac` — it is InterSystems-compiled source, not user-compilable. The AD's phrase "the
`^%ETN` error-trap routine" is exactly right: `FORE` is the foreground entry (`s $zt="^%ETN"`),
`BACK()` the background entry, `LOG()` the explicit-log entry, `apiOBJ()` the status-carrying entry.

### It is genuinely per namespace

`%ETN` writes `^ERRORS` **unqualified**, so it lands in whatever namespace the erroring process is in.
That this is a real separation, not a global mapping that would collapse them, was checked directly:

```
ERRORS dest %SYS:     ^/durable/iris/mgr/
ERRORS dest HSCUSTOM: ^/durable/iris/mgr/HSCUSTOM/
ERRORS dest USER:     ^/durable/iris/mgr/user/
```

Three namespaces, three distinct databases. `%ETN`'s own `ECPSync()` confirms the intent — it resolves
the ECP client index with `$zu(90,22,$Namespace,"^ERRORS",Inx)`, namespace-qualified.

### It was undefined on this container, and here is why that matters

At review start, `$Data(^ERRORS)` returned **0** in `%SYS`, `HSCUSTOM` **and** `USER`. This container
has recorded no application error since its last reset. **Say this plainly in any story that reads the
error log: the empty state is the normal state on a fresh instance**, and the Log screen must render it
as "no errors recorded", not as an error. The demo fixture (AD-25) is the only thing that will put rows
on this screen during the contest window unless something genuinely fails.

### The subscript structure

Read from `%ETN.int` (`Store()`, `VSet()`, `VIndex()`, `MinStore`, `ETNMINIM`) and then **proved** by
seeding entries and walking the result:

```
^ERRORS(<date>)                                     = high-water counter ($Increment)
^ERRORS(<date>,<errnum>,"*COM")                     = truncated/lost-entry marker
^ERRORS(<date>,<errnum>,"*CLASS",<class>[,<oref>])  = classes live at error time
^ERRORS(<date>,<errnum>,"*FORMAT")                  = storage format flag
^ERRORS(<date>,<errnum>,"*LEVEL",<lvl>[,<var>])     = level index
^ERRORS(<date>,<errnum>,"*NAMES",<var>,<lvl>,<lvl>) = index by variable name
^ERRORS(<date>,<errnum>,"*OREF",…)                  = object references
^ERRORS(<date>,<errnum>,"*STACK",<lvl>,"V",<var>…)  = the payload
^ERRORS(<date>,<errnum>,"*VARS",…)                  = variable index
```

- `<date>` is `+$H` — an integer `$Horolog` day (`67822` during this review), **not** a formatted date.
- `<errnum>` is allocated by `$Increment(^ERRORS(<date>))`. The root node is therefore a **high-water
  mark, not a live count** — after a delete it does not decrease. Anything reporting "N errors on this
  date" must count rows, not read `^ERRORS(<date>)`.
- Level `0` is the summary. `^ERRORS(d,e,"*STACK",0,"V",<name>)` holds `Error`, `Routine`, `Line` plus
  the process snapshot. Levels `>0` store each variable as
  `$LB($LFS(<subscript>,,2), <"O" if object>, <value>)` — Format 1, distinct from level 0's Format 0.
  A reader that assumes one format across levels will mis-decode every stack frame.

### A gap AD-48 does not cover: the entry is a secrets dump

The observed level-0 summary of a single seeded entry:

```
$Roles    = %All
$USERNAME = _SYSTEM
$P        = |TCP|1972|44255
$ZE       = OcuPilot AD-48 currency probe
… 75 expression rows in total, plus 40 stack levels of local variables
```

`PassOne`/`PassTwo` in `%ETN.int` walk **every local variable at every stack level** into the global.
An error thrown anywhere near credential handling therefore writes that credential into `^ERRORS` in
plaintext, and the level index (`*NAMES`) makes it trivially reachable by name.

AD-48 is silent on this. AD-35 says "secrets never reach a surface OcuPilot itself displays", and
AD-24 says a screen descriptor declares which fields are secret-typed and never sent — but neither can
apply here, because the error-log payload has no schema to classify against: the variable names are
whatever the failing code happened to use.

> **Recommendation.** AD-48 needs one clause. Either the error-log read tool returns **summary rows
> only** (`ErrorList`'s seven columns — see §5) and never the variable dump, with the full detail
> reachable only from the browser screen and never placed in model context; or the risk is accepted
> explicitly and named in the Operational Envelope. Silence here means the first builder ships the
> variable dump into the LLM turn, which is both an exfiltration path and an AD-11 injection surface
> (`^ERRORS` content is fully attacker-influenceable by anyone who can cause an error).

---

## 2. `Config.Startup.ErrorPurge` — **CONFIRMED**, with two qualifications

The property is real:

```objectscript
Property ErrorPurge As %Integer(MAXVAL = 1000, MINVAL = 1) [ InitialExpression = 30, Required ];
```

Current value on this instance: **30**. Its description is unambiguous — *"Number of days to store
application error logs before purging them."* So the AD's "retention is governed by
`Config.Startup.ErrorPurge`" is correct.

### Qualification A — it is a setting, not a mechanism

`Config.Startup` carries a **same-named class method** `ErrorPurge() As %Status [ Internal ]` that
performs the work, and it is invoked by a scheduled task:

```objectscript
// %SYS.Task.PurgeErrorsAndLogs.OnTask()
d $zu(5,"%SYS")
d ##Class(Config.Startup).SwitchConsoleLog()
d ##Class(Config.Startup).ErrorPurge()
```

The task is present and live on this instance:

| Name | Class | Suspended | Namespace | RunAsUser | TimePeriod | DailyFrequency | Start |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Purge errors and log files | `%SYS.Task.PurgeErrorsAndLogs` | 0 | `%SYS` | `_SYSTEM` | 0 (Daily) | 0 (Once) | 3600 (01:00) |

**Retention is therefore task-driven, not automatic.** On an instance where an operator has suspended
or deleted that task — which OcuPilot's own Task screens (FR-48…FR-53) let them do — `ErrorPurge = 30`
retains nothing and `^ERRORS` grows without bound. If the Log screen displays a retention figure, it
must display the task's state alongside it or it is telling the operator something untrue.

### Qualification B — it purges across namespaces, and it is not `errlog`

The cross-namespace behaviour was proved rather than assumed. Backdated entries were seeded at
`^ERRORS(60000)` in **both** `USER` and `HSCUSTOM`, then `##class(Config.Startup).ErrorPurge()` was
called once from `%SYS`:

```
ErrorPurge sc=[]              ← success
USER     old=0  today=11      ← backdated entry gone, today's entry retained
HSCUSTOM old=0                ← backdated entry gone
```

One call, from `%SYS`, sweeps every namespace and respects the day threshold. Good news for AD-48: the
port needs no per-namespace purge loop.

**Do not confuse it with `Config.config.errlog`**, which is `500` on this instance and means *"Maximum
number of entries you want to store in the **SYSLOG** log file"* — a different log with a different
retention model (count-based, requires a restart to change). A builder skimming for "error log
retention" will find `errlog` first.

---

## 3. `messages.log`, the manager directory, and no backing class — **CONFIRMED**, with a portability caveat

```
ManagerDirectory = /durable/iris/mgr/        ← note the trailing slash; do not add one
InstallDirectory = /usr/irissys/
messages.log     exists=1  size=76132
alerts.log       exists=1
```

Full listing of `/durable/iris/mgr/*.log`: `alerts.log`, `messages.log`, `journal.log`,
`SystemMonitor.log`, `HS.Util.Installer.HSLIB-0.log`. No `.old` files yet.

No persistent class backs `messages.log` — a full-text search of `%SYS` classes for `^ERRORS` returns
only `%CSP.ErrorLog` (a message string), `%SYS.Task.PurgeErrorsAndLogs` (a doc comment) and
`%UnitTest.Manager` (a comment). AD-48's "plain files under the manager directory" is right, and
AD-21's "the directory comes from `$System.Util.ManagerDirectory()` at runtime" is the right discipline.

### Caveat A — the location is operator-configurable

`Config.config` carries a `console` parameter whose description is:

> *"CPF file representation of console=VMSConsoleTerminal,**ConsoleFile**."*

Current value: `","` — both pieces empty, so the default (manager directory) applies. But an operator
who sets `ConsoleFile` moves `messages.log` somewhere else entirely, and AD-21's manager-directory join
then silently reads a stale or absent file. AD-21's **rule** is unaffected — the caller still names the
log from a fixed enum, never a path — but the *resolution* of the `messages` enum member should read
`Config.config.console` and fall back to the manager directory, not hardcode the join.

### Caveat B — a tail must survive rotation

`Config.Startup.MaxConsoleLogSize` is **5** — *"Maximum size in megabytes of the messages.log after
which it will be automatically switched."* `SwitchConsoleLog()` runs in the same nightly task as the
error purge, and `MoveConsoleLog()` renames the file with a `.old` suffix. A tail implementation that
holds a byte offset across requests will, after a switch, either read from the wrong file or read
garbage. The offset must be validated against the file's identity, not just its length.

---

## 4. AD-3's `%SYS.Task` claims

### 4a. "66 documented properties" — **the number is right, the word "documented" is not**

`SELECT COUNT(*) FROM %Dictionary.CompiledProperty WHERE parent = '%SYS.Task'` returns exactly **66**.
So the figure traces to something real. But the same query decomposes as:

| Measure | Count |
| --- | --- |
| Compiled properties | **66** |
| …of which are compiler artifacts (`%%OID`, `%Concurrency`) | 2 |
| Real task properties | **64** |
| …of which carry a description | **49** |
| Undocumented | **17** |

The 17 undocumented: thirteen `Display*` derived-display strings (`DisplayInterval`,
`DisplayNextScheduled`, `DisplayRunAfter`, …), plus **`ExpiresDays`, `ExpiresHours`, `ExpiresMinutes`**
and `SkipAuditOnReschedule`.

Also worth recording, because it changes where a builder looks: **every one of the 66 originates on
`%SYS.TaskSuper`, not `%SYS.Task`** (`Origin = '%SYS.TaskSuper'` for all of them). The vocabularies
live in `%SYS.TaskSuper`'s doc comments and `%SYS.Task` inherits them. An epic that says "read
`%SYS.Task`" sends someone to a class whose own source contains none of the prose being cited.

> **Fix.** "`%SYS.Task`'s 66 documented properties" → "`%SYS.Task`'s 64 properties (declared on
> `%SYS.TaskSuper`), **49 of them documented**". The distinction is load-bearing for AD-3, whose whole
> premise is *"where the semantic half is already written down, take it rather than invent it"* — for
> 17 of these it is not written down, and one of the four vocabularies the AD names is in that set
> (see 4d).

### 4b. `TimePeriod` 0–5 — **CONFIRMED, verbatim**

The property description enumerates exactly what the AD says, and each value does govern how
`TimePeriodEvery` and `TimePeriodDay` are read:

| Value | Name | `TimePeriodEvery` | `TimePeriodDay` |
| --- | --- | --- | --- |
| 0 | DAILY | every x days, 1–7 | ignored |
| 1 | WEEKLY | every x weeks, 1–5 | days `xxxx`, Sunday=1 … Saturday=7 (`23456` = Mon–Fri) |
| 2 | MONTHLY | every x months, 1–12 | day 1–31, **31 = last day of month** |
| 3 | MONTHLYSPECIAL | every x months, 1–12 | `week^day`, week 1–5 (**5 = last**), day 1–7 |
| 4 | RUNAFTER | not used | `0` — plus **`RunAfterGUID`** = JobGUID of the task to follow |
| 5 | ONDEMAND | ignored | ignored — scheduled by calling `RunOnce()` |

Cross-checked at runtime rather than only read: `%SYS.Task.TimePeriodLogicalToDisplay()` returns
`Daily / Weekly / Monthly / Monthly Special / Run After / On Demand` for 0–5, and passes `6` through
unmapped — so the domain really is closed at 0–5.

Two details the AD's one-line summary drops, both of which a write tool needs:
- `TimePeriod = 4` is not expressible without **`RunAfterGUID`**; `TimePeriodEvery` is inert.
- `31` and `5` are magic sentinels ("last day", "last week"), not ordinary maxima.

### 4c. `DailyFrequency` "increment, start and end **triple**" — **WRONG, and it would ship a broken tool**

The property description is explicit that `DailyFrequency` governs **four** properties, not three:

> *"This property governs how the properties **DailyFrequencyTime**, DailyIncrement, DailyStartTime,
> and DailyEndTime are interpreted."*

The member the AD omits, `DailyFrequencyTime`, is the **units selector**:

```
1 - SEVERAL
    DailyFrequencyTime - 0 - Run every x minutes
    DailyFrequencyTime - 1 - Run every x hours
    DailyIncrement     - # of minutes between runs or # of hours between runs
```

Confirmed at runtime: `DailyFrequencyTimeLogicalToDisplay()` → `0 = Minutes`, `1 = Hourly`.

Without it, `DailyIncrement = 2` is ambiguous between "every two minutes" and "every two hours" — a
120× difference. The vendor's own worked examples turn on it:

```
Run every 60 minutes, 5pm–9pm : DailyFrequency=1, DailyFrequencyTime=0, DailyIncrement=60,  …
Run every hour,      5pm–9pm : DailyFrequency=1, DailyFrequencyTime=1, DailyIncrement=1,   …
Run every two hours, 5pm–9pm : DailyFrequency=1, DailyFrequencyTime=1, DailyIncrement=2,   …
```

Note also that `DailyStartTime` / `DailyEndTime` are **seconds since midnight** (`$p($h,",",2)`),
not clock strings — `61200` is 5:00pm. A schema authored from the AD's sentence would emit three
fields, in the wrong unit vocabulary, and the resulting task tool could not express the most common
real schedule.

> **Fix.** "with its increment, start and end triple" → "with its **frequency-unit, increment, start
> and end quadruple** (`DailyFrequencyTime` 0=minutes / 1=hours; `DailyStartTime` and `DailyEndTime`
> in seconds since midnight)".

### 4d. "the expiry offsets" — **WRONG as a citation**

The offsets are real properties — `Expires` (`%Boolean`), `ExpiresDays`, `ExpiresHours`,
`ExpiresMinutes` — and `Expires`' own description names the concept:

> *"Whether this entry expires. Expiration is only checked if this flag is set to 1. Expiration is
> determined by whichever is first: 1) The current time passed the next submit time. 2) Expiration
> Offsets (Days, Hours, Minutes)."*

But **`ExpiresDays`, `ExpiresHours` and `ExpiresMinutes` each carry an empty description.** They are
three of the 17 undocumented properties from 4a.

This is precisely the case AD-3 says does not exist here. Of the four vocabularies the AD names as
"already written down", three are (TimePeriod, DailyFrequency, RunAsUser) and this one is not. The
semantics that *are* recorded — that the offsets only apply when `Expires = 1`, and that the earlier of
"offset elapsed" and "next submit time passed" wins — live on a *different* property, so a generator
walking `ExpiresDays` in isolation finds nothing.

> **Fix.** Either drop "the expiry offsets" from the list of things to harvest, or change the sentence
> to say the offsets must be authored by hand from `Expires`' description — which is the one place the
> rule is stated.

### 4e. `RunAsUser` requires `%Admin_Secure:Use` — **CONFIRMED as documentation, UNVERIFIABLE as enforcement**

The doc comment is verbatim what the AD claims:

```objectscript
/// Username of user to run as.<br>
/// A user must have the %Admin_Secure:Use privilege to define a task to run as another user.
Property RunAsUser As %Library.Username;
```

**But the enforcement could not be read on this instance.** `%SYS.TaskSuper` is shipped with its method
bodies stripped (`%OnValidateObject()` at line 349 is an empty shell), no `%SYS.TaskSuper.1.INT` is
exposed, and a scan of the whole 43 KB class text finds `%Admin_Secure` **only** in that comment —
nowhere in executable form. Testing it properly needs a second, non-privileged user session, which is
outside this review's blast radius.

Treat it as a vendor-documented contract, not an instance-verified fact. This is exactly the shape of
claim AD-3 already says must be pinned: *"must have their field lists derived from the underlying
`Security.*` / `%SYS.*` class and pinned by a test that fails when the instance disagrees."* Extend
that to the privilege assertion — a test that attempts `RunAsUser` as a user without `%Admin_Secure`
and asserts the failure. Without it, OcuPilot's task-create tool may be advertising a guard that is not
actually there, which is a worse posture than not claiming one.

---

## 5. **The finding that changes AD-48: `SYS.ApplicationError`**

AD-48 says the error log has no backing endpoint and therefore `LogSourcePort` owns it, performing
"the namespace switch by AD-16's explicit save and restore". The first half is right. The second half
is unnecessary, and the AD misses a supported vendor API that does the whole job.

**`SYS.ApplicationError`** is an `[Abstract]` class in `%SYS` (`IRISSYS`, ts `2026-06-26 10:15:08`)
that is a complete read *and* delete API over `^ERRORS` — and **every member takes namespace as a
parameter**:

| Member | Signature | Returns |
| --- | --- | --- |
| `NamespaceList` | `(ListType)` — 0 all, 1 remote, 2 local | namespaces that contain errors |
| `DateList` | `(Namespace)` | `Date:%Date, Qty:%Integer` |
| `ErrorList` | `(Namespace, Date)` | `Error #, Error message, Time, Process, DisplayPID, Username, Code line` |
| `ErrorDetail` | `(Namespace, Date, Error, Type)` — Type 0 = expressions, −1 = stack levels, −2 = collapsed levels, *i* = variables of level *i* | 4 generic columns |
| `DeleteByNamespace` | `(NspList)` — comma-separated | `%Status` |
| `DeleteByDate` | `(Namespace, DateList)` — comma-separated dates | `%Status` |
| `DeleteByError` | `(Nsp, Date, ErrorList)` | `%Status` |
| `GetComment` / `SetComment` | `(Namespace, Date, Error, …)` | per-error annotation |

### Driven end to end on this instance, from `%SYS`, with no namespace switch

```
current NS = %SYS
NamespaceList(0)                       →  HSCUSTOM, USER
NS after  = %SYS

DateList("USER")                       →  Date=09/09/2026  Qty=2
ErrorList("USER","09/09/2026")         →  #2 | OcuPilot probe B | 05:46:48 | pid=44255 | user=_SYSTEM
                                          #1 | OcuPilot probe A | 05:46:48 | pid=44255 | user=_SYSTEM
ErrorDetail("USER",…,1,0)              →  75 expression rows
ErrorDetail("USER",…,1,-1)             →  40 stack levels  (1 SIGN ON / 2 DO / 3 PARAMETER / 4 ERROR TRAP / …)
NS after  = %SYS

DeleteByError("USER","09/09/2026","1") →  OK;  remaining: #2 only
DeleteByNamespace("USER,HSCUSTOM")     →  OK;  namespaces with errors = 0
```

`$NAMESPACE` was `%SYS` before and after every one of these calls.

### What this means for AD-48, clause by clause

1. **"The port performs the namespace switch by AD-16's explicit save and restore."** — Unnecessary,
   and therefore harmful. Namespace is an *argument*, not process state. AD-16 exists because a
   switch that is not restored on the error path turns every failure into `<CLASS DOES NOT EXIST>`;
   mandating a switch that the API does not require imports that hazard for no benefit. Replace the
   clause with: *the port passes namespace as a parameter and never switches `$NAMESPACE` at all.*
   The rest of the paragraph — "One component owns that switch, so no slice writes `Set $NAMESPACE` of
   its own" — becomes stronger, not weaker: **nothing** writes `Set $NAMESPACE`.

2. **The AD-21 cross-reference gets easier, not harder.** "The target namespace reaches it as a
   selection from the set the user can read, never as a caller-supplied string" is exactly right —
   and `NamespaceList(0)` *is* that enumerator, shipped. The port offers the namespaces it returns and
   rejects anything else. No hand-built allow-list.

3. **"no slice touches `^ERRORS` directly" should be "no slice — and not the port either".** The port
   calls `SYS.ApplicationError`. Walking `^ERRORS` by hand means re-implementing two storage formats,
   the level indices and the `*OREF` handling, against a global whose layout is undocumented and
   version-specific. `.claude/rules/objectscript-basics.md` already forbids this: *"Prefer built-in
   IRIS classes over hand-rolled equivalents."*

4. **Delete granularity: the AD names two, the instance offers three.** AD-48 says "by namespace or
   individually", which maps onto `DeleteByNamespace` and `DeleteByError`. **`DeleteByDate` is the
   third**, and it is the one the classic portal leads with — "delete every error from 2026-09-08" is
   the operator's most common request. The proposal diff (AD-6) has to be able to express a date
   scope, and `DateList` already returns the `Qty` per date that the diff needs as its count.

5. **Date is passed in display format, not `$H`.** `DateList` returned `09/09/2026`, and `ErrorList`
   only accepted that form — the class comment says *"The Date has to be in display format (e.g.
   1/1/09)."* That is a **locale dependency**: the same code against a different `$ZDATE` format
   produces a different string. The port must round-trip the value it received from `DateList` rather
   than formatting one itself, and a test should pin it.

6. **`ErrorList` already returns `Username` per error** — so per-user filtering, and AD-46's "OcuPilot's
   own records are visible in OcuPilot's own screens", need no global walk.

### The vendor UI exists too — and its resource keys are not the obvious ones

AD-48 says "no admin API endpoint backs it", which is true. But a vendor **UI** does exist and is live
on this instance — four legacy `%CSP.Util.AutoPage` SysManager pages compiled into `%SYS`:

```
%cspapp.op.utilsysapperror            (%CSP.Util.Domain)
%cspapp.op.utilsysapperrordates       (%CSP.Util.AutoPage)
%cspapp.op.utilsysapperrornamespaces  (%CSP.Util.AutoPage)
%cspapp.op.utilsysapperrors           (%CSP.Util.AutoPage)
```

`GET /csp/sys/op/UtilSysAppErrorNamespaces.csp?Recent=1` → **HTTP 200**, title *"View Application Error
Log"*. There is no file on disk (`/usr/irissys/csp/sys/op/` holds only `images`); they are served from
the compiled classes, which is why they are absent from the `irissys/` export.

For AD-44 ("routes map back to the classic portal's resource keys"), the mapping is **not** what a
builder would guess. From `%CSP.UI.Portal.Application.GetSystemOperationArray()`:

```objectscript
Set tOperate = '..CheckSecurity("%Admin_Operate")
If tOperate = 1 Quit 1                                              ← whole section gated on %Admin_Operate
Set tNoDBSecurity = '$System.Security.Check("%DB_IRISSYS","READ,WRITE")
…
Set pData(n1,$i(n2)) = $LB($$$Text("Application Error Log"), …, tNoDBSecurity, …)
```

So the classic keys are **`%Admin_Operate`** for the System Logs section and **`%DB_IRISSYS:READ,WRITE`**
for the Application Error Log entry itself — a *database* resource, not `%Admin_Manage`. The same pair
gates the Messages Log entry (`UtilSysConsoleLog.csp`), which is convenient: one gate covers the whole
`Area/Log/` slice. AD-29's port gate should mirror this pair, and AD-48's "runs under the caller's own
privileges through the port's gate" then has something concrete to check.

> **Recommended AD-48 rewrite (rule paragraph 2):**
>
> The application error log is the `^ERRORS` global, held per namespace, written by the `^%ETN`
> error-trap routine, with retention governed by `Config.Startup.ErrorPurge` (a day count applied by
> the nightly `%SYS.Task.PurgeErrorsAndLogs` task, not continuously). It is not a file and no admin API
> endpoint backs it, but `SYS.ApplicationError` in `%SYS` is the supported read and delete API and
> `LogSourcePort` calls it — never walking `^ERRORS` itself. Namespace is a **parameter** of every one
> of its calls, so the port performs **no** `$NAMESPACE` switch; the namespace offered to the caller is
> whatever `SYS.ApplicationError:NamespaceList` returns, never a caller-supplied string (AD-21). The
> gate mirrors the classic portal's keys for this page: `%Admin_Operate` plus `%DB_IRISSYS:READ,WRITE`.
> Deletes come in three scopes — namespace, date, and individual error — matching
> `DeleteByNamespace` / `DeleteByDate` / `DeleteByError`, and each is an ordinary write.

---

## 6. Two smaller corrections

- **AD-48: "the alerts.log tail".** `alerts.log` exists (4,162 bytes) in the manager directory, so the
  claim holds. Note it is written by the System Monitor, not `%ETN`, and `SystemMonitor.log` sits
  beside it — if the Log screen's enum is meant to cover "what an operator tails", `SystemMonitor.log`
  and `journal.log` are the two obvious omissions from a three-member enum.

- **AD-3: the `%SYS.Task` write tool needs a fourth no-template source.** AD-3 lists five Release 1
  endpoints that publish no body template and names `Task.Manager` (FR-51) as "action-style with
  trivial or empty bodies". That is right for `Task.Manager`, but `Task.CRUD` (FR-53) is listed under
  AD-4 as an endpoint whose PUT does **not** merge — so the task write tool must send a complete
  64-property body derived from `%SYS.TaskSuper`, of which 17 properties have no description to derive
  a `description` from. That is the largest single hand-authoring job AD-3 implies, and it is worth
  naming in the AD so it is costed rather than discovered.

---

## Appendix — instance state

Every mutation made by this review was reverted.

```
USER     ^ERRORS = 0
HSCUSTOM ^ERRORS = 0
%SYS     ^ERRORS = 0
```

Seeded entries were removed with `SYS.ApplicationError:DeleteByNamespace` (itself part of the
verification); the backdated purge probes were removed by `Config.Startup.ErrorPurge()`. No
configuration value was changed, no task was modified, and no class was created or compiled.

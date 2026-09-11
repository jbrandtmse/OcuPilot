# ObjectScript Basics

General coding rules for InterSystems IRIS / ObjectScript source. They apply to any
`.cls`, `.mac`, or `.inc` written for this project.

## Naming and structure

- "namespace" means an IRIS namespace; a "package" prefix is the class-name prefix.
- Do not create classes or properties whose names contain `%` or `_`.
- Class **parameter** names must not contain underscores — use camel case (`MyParameter`)
  or all caps without underscores (`MYPARAMETER`).
- Method names must not contain underscores. Use camel case and keep formal identifiers
  (test IDs, ticket numbers) in comments or assertion messages, not in the method name.
- Parameters take a `p` prefix (`pItem`); local variables take a `t` prefix (`tIndex`).
- Class properties are capitalized with no prefix.
- Class parameters are accessed with `#`: `..#PARAMETERNAME`.

## Writing methods

- Return `%Status` from methods that produce no other return value.
- First line `Set tSC = $$$OK`, last line `Quit tSC`.
- Use `Try` / `Catch` for error trapping.
- Macro syntax uses **three** dollar signs (`$$$OK`), never two.
- `%DynamicObject` property names containing an underscore must be quoted, because `_`
  is the concatenation operator: `Set request."max_results" = 5`.
- To produce a JSON `null` in a `%DynamicObject`, use `%Set("key", "", "null")` — the third
  argument is the type hint. `%Set("key", "null", "null")` produces the *string* `"null"`.

## Abstract methods

Despite what the documentation implies, abstract methods must have a body with braces and
must return a value appropriate to their signature, or the class will not compile:

| Return type | Body |
| --- | --- |
| object | `Quit $$$NULLOREF` (or `Quit ""`) |
| `%Status` | `Quit $$$OK` |
| `%String` | `Quit ""` |
| `%Boolean` / `%Numeric` | `Quit 0` |

```objectscript
Method MyAbstractMethod() As %String [ Abstract ]
{
    Quit ""
}

Method CreateObject() As MyClass [ Abstract ]
{
    Quit $$$NULLOREF
}
```

Both instance and class methods can be abstract. Classes containing abstract methods are not
instantiated directly; concrete subclasses must implement every inherited abstract method.

## QUIT inside Try/Catch

Argumented `Quit` is **not** allowed inside a `Try` or `Catch` block (ERROR #1043). For a
method that must return a value:

```objectscript
Method CreateProduct() As Product
{
    Set result = ""          ; initialize the return variable first
    Try {
        Set result = ##class(Product).%New()
        Quit                 ; argumentless
    }
    Catch ex {
        Set result = ""
        Quit                 ; argumentless
    }
    Quit result              ; argumented Quit outside the block
}
```

`RETURN` is an alternative with different semantics. The `$QUIT` special variable reports
whether an argumented `Quit` is required in the current frame.

## Comments and formatting

- `///` for doc comments in class definitions. Do **not** use `//` in a class definition —
  it is not a comment there and can break parsing. `;` is the single-line comment inside
  method bodies.
- Reserve `/* ... */` for top-of-file banners; block comments placed immediately around
  method signatures can trigger ERROR #5559 parse failures.
- Class and method banners may use HTML/DocBook markup.
- Always indent commands inside a method by at least one space or tab, or the class will not
  compile. Keep block spacing consistent.

## Storage sections

**Never write or edit a class's Storage Default section.** The compiler generates and maintains it
from the declared properties and superclasses. Configure persistence through property
keywords and parameters, not by hand-editing the Storage XData.

## InterSystems library code

- Prefer built-in IRIS classes over hand-rolled equivalents.
- System packages begin with `%`, plus `HS`, `Ens`, `EnsLib` and others.
- **Read the system class source before using it.** Assumptions about system-class behavior
  are a recurring source of bugs: `$System.Security.Login()` switches the process's user
  context and must never be used to validate credentials (use
  `Security.Users.CheckPassword()`); `$System.Encryption.PBKDF2()` already exists, so do not
  reimplement crypto primitives; `$System.Encryption.HMACSHA()` takes bit sizes (160, 256,
  384, 512), not algorithm version numbers. In this project the exported system source is in
  [irislib/](../../irislib/) and [irissys/](../../irissys/) — read-only, see
  [reference-folders.md](reference-folders.md).

## Collections and object identity

- `$ListBuild()` / `$List()` serialize objects to strings and **lose object identity**. Store
  OREFs in individual variables or in a real collection class, never in a `$List`.
- `<INVALID OREF>` errors usually mean a serialized object is being accessed as if it were
  still an object — look for batch processing or list round-trips.
- Process-private globals (`^||X`) do **not** preserve OREFs either: `Set ^||X = oref` then
  `$IsObject(^||X)` returns 0, because global nodes are scalar and the OREF stringifies to
  `"oref@<class>"`. To survive a `^||` round trip, store the class name plus a
  `%DynamicObject.%ToJSON()` config blob and re-instantiate on read; for in-process singleton
  holders use a `%RegisteredObject` with a class-level OREF property instead.
- Process-private global **subscripts** follow identifier rules — letters, digits, `%`, and no
  hyphens. `^||MyTest2-11Ids` parses as a subtraction expression and fails with `<SYNTAX>`.
  Use `MyTest211Ids` or `my_test_211_ids`.
- Never call `%Set()` or `%Remove()` on a `%DynamicObject` while iterating it with
  `%GetIterator()`. Collect the keys into a `$ListBuild` list first, then iterate that list to
  make the modifications.
- **`%OpenId` on an object this process already holds returns the in-memory OREF and does not
  reload it.** `%Library.Persistent.%Open` reloads only when the call raises the object's
  concurrency from below 3 to above 2; at the default concurrency it hands back the same stale
  copy. A loop that re-opens a row to watch another process change it therefore never sees the
  change. To poll, drop the OREF before every re-open (`Set tObj = ""`, then `%OpenId`), or call
  `tObj.%Reload()`, and do not hold the OREF across the wait.
- **An OREF kept alive across a call that upgrades its concurrency keeps that lock alive.**
  Verified on this build: `%SYS.Task.RunNow(id)`, called while the caller still holds that
  task's OREF, raises the object to concurrency 4 and leaves an exclusive lock on
  `^SYS("Task","TaskD",id)` owned by the caller for as long as the OREF lives. The Task
  Manager runs a `RunNow` request at its next once-a-minute pass and skips a task whose lock
  is held, so the task does not run until the caller lets go. Release the OREF (`Set tObj = ""`)
  right after such a call.

## SQL

- IRIS SQL string comparison is case-insensitive by default. Wrap string columns in
  `%EXACT()` in `WHERE` clauses when case matters:
  `SELECT ... WHERE %EXACT(FieldValue) = 'order-001'`. This applies to embedded SQL (`&sql()`)
  and to dynamic SQL via `%SQL.Statement`.
- **`%EXACT()` in the SELECT list renames the column.** `SELECT %EXACT(ID) ...` followed by
  `tRS.%Get("ID")` returns `""`, because the output column is now aliased `%EXACT(ID)`. Either
  read positionally (`tRS.%GetData(1)`) or give an explicit alias
  (`SELECT %EXACT(ID) AS ID ...`).
- **Never concatenate caller-supplied values into SQL text.** Validate the shape first, then
  bind it:

  ```objectscript
  If '$Match(tClassName, "^[A-Za-z%][A-Za-z0-9%._]*$") {
      Set tSC = $$$ERROR($$$GeneralError, "invalid class name format")
      Quit tSC
  }
  Set tSC = tStmt.%Prepare("SELECT ... WHERE %EXACT(Name) = ?")
  Set tRS = tStmt.%Execute(tClassName)
  ```

  Regex validation does not make concatenation acceptable — parameterize regardless. Where the
  value originates from an LLM or an external API, state the expected format explicitly in the
  parameter's description so the caller is primed to send the right shape.

## The `$Char(0)` empty-string sentinel

A `%String` column set to `''` by a SQL `UPDATE` reads back through the object layer as
`$Char(0)`, not `""`. Because `$Char(0)` is a non-empty one-character string, the usual
`If tValue '= ""` guard is **true**, and defaulting-on-empty logic is silently bypassed —
the sentinel then reaches downstream code as a bogus URL, credential name, or env-var name.

Normalize at every read site of a `%String` property whose write path includes SQL UPDATE:

```objectscript
Set tStored = ""
If $IsObject(..Config) Set tStored = ..Config.SomeProperty
If tStored = $Char(0) Set tStored = ""
```

Exception: a read consumed only by an equality test against a non-empty literal
(`If ..Config.Provider = "openai"`) behaves the same either way — still safer to normalize so
the variable is reusable.

## Transactions

Never spawn background jobs (`JOB`), signal events (`$System.Event.Signal`), or perform I/O
against external systems inside a `TSTART` / `TCOMMIT` block — the side effect can observe
uncommitted data. Capture what the side effect needs in a local variable inside the
transaction and run the side effect after `TCOMMIT`.

## Error and status handling

- Every method returning `%Status` must have its result checked with `$$$ISERR(tSC)` by the
  caller. Do not silently discard write failures.
- Restore state on the error path. In particular, when a method switches `$NAMESPACE`, the
  first line of the `Catch` block must restore it.

## Namespace switching

- **Never use `New $NAMESPACE` in a REST dispatch handler.** `New $NAMESPACE` plus
  `Set $NAMESPACE = "%SYS"` makes classes from the original namespace invisible in the catch
  block, turning any error path into `<CLASS DOES NOT EXIST>`.
- Use explicit save/restore instead:

  ```objectscript
  Set tOrigNS = $NAMESPACE
  Set $NAMESPACE = "%SYS"
  ; ... work in %SYS ...
  Set $NAMESPACE = tOrigNS
  ```

- Do all input validation before switching to `%SYS`, and restore the namespace after each
  system-class call before any error handling.
- `Config.Namespaces`, `Config.Databases`, `Config.Map*`, `Security.Users`, `Security.Roles`,
  `Security.Resources`, `Security.Applications` and `Security.SSLConfigs` exist only in `%SYS`
  and require the switch.
- For listing operations prefer the named queries
  (`##class(%ResultSet).%New("Config.Namespaces:List")`) over guessing at class-method names.

## Timestamps and encoding

- ISO-8601 UTC: `$Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"` →
  `2026-04-13T10:30:45Z`.
- Use `$ZTimeStamp` (UTC), not `$Horolog` (local server time), whenever the `Z` suffix is
  appended. Never emit raw `$ZDateTime`, which is space-separated.
- Base64: encode in a single `$System.Encryption.Base64Encode(stream.Read(3600000))` call.
  Concatenating separately-encoded chunks produces interior padding and invalid output. Where
  round-trip fidelity matters, add a test that encodes and decodes.

## Auditing

`$System.Security.Audit("Source", "Type", "Name", ...)` silently returns 0 and drops the event
if the Source/Type/Name triple was never registered with `Security.Events.Create()` in `%SYS`.
There is no error and no log entry. Register every event type in an installation/upgrade
routine (guarded by `Security.Events.Exists()`) before any code emits one.

## Embedded Python

- Prefer native ObjectScript for IRIS operations — globals, persistence, SQL, transactions.
  Reserve embedded Python for external library integration.
- Use `%SYS.Python.Import()` for libraries and `[ Language = python ]` for methods; use the
  `import iris` bridge when calling back into IRIS.
- `##class(%SYS.Python).IsAvailable()` **does not exist**. `GetPythonVersion()` only reports
  whether Python has already been loaded — it does not load it. To probe availability,
  attempt `do ##class(%SYS.Python).Import("sys")` first, then check `GetPythonVersion()`.
- A `[ Language = python ]` method in a shipped class is a latent install failure on any IRIS
  instance without embedded Python configured. Where Python is genuinely needed for shipped
  code, host it as a standalone `.py` file distributed as a package resource and call into it,
  rather than embedding it in a `.cls`. Third-party Python packages are an operator-run
  `irispip install` prerequisite, never something an install hook performs.

## Editing ObjectScript files

- Compile after a meaningful edit and read the error text; a clean local file is not evidence
  that the class compiles.
- Use the IRIS MCP Server Suite for loading and compiling ObjectScript Classes

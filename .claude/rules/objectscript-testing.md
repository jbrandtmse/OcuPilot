# ObjectScript Testing (`%UnitTest`)

## Assertion macros

`%UnitTest.TestCase` provides these — note the **three** dollar signs:

- `$$$AssertEquals(actual, expected, description)`
- `$$$AssertNotEquals(actual, expected, description)`
- `$$$AssertTrue(condition, description)`
- `$$$AssertStatusOK(status, description)`
- `$$$AssertStatusNotOK(status, description)`

These **do not exist**: `$$$AssertFalse` (use `$$$AssertTrue('condition, ...)`) and
`$$$AssertCondition` (use `$$$AssertTrue`).

Assertions are macros, not methods: `Do $$$AssertEquals(1, 1, "test")` is correct;
`Do ..AssertEquals(1, 1, "test")` is not. Macro calls cannot span multiple lines.

## Test class structure

```objectscript
Class MyPackage.MyTest Extends %UnitTest.TestCase
{

/// Test methods must start with "Test".
Method TestSomething()
{
    Do $$$AssertTrue(1=1, "Basic test")
    Quit
}

Method OnBeforeOneTest() As %Status { Quit $$$OK }

Method OnAfterOneTest() As %Status { Quit $$$OK }

}
```

Keep a test class to roughly 500 lines; split larger suites into several classes.

## `%OnNew` must accept and forward `initvalue`

`%UnitTest.TestCase` passes an `initvalue` argument to the constructor. A subclass that
overrides `%OnNew` without it fails at runtime with
`<UNDEFINED> ... %OnNew+1^%UnitTest.TestCase.1 initvalue`.

```objectscript
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..MyProperty = ""
    Quit $$$OK
}
```

`%OnNew` must not be marked `Private` (ERROR #5477). Initialize every property in `%OnNew`
so no method sees an `<UNDEFINED>`.

## Never name a property `Test*` on a test class

The compiler auto-generates datatype helpers for every property —
`<PropName>DisplayToLogical`, `<PropName>LogicalToDisplay`, `<PropName>Normalize`,
`<PropName>IsValid`. A property named `TestNsPrepared` therefore produces methods named
`TestNsPreparedDisplayToLogical` and friends, all of which the framework's method-discovery
loop matches as test methods. They have no test body, and they surface as phantom failures or
as an inflated test count.

Use any prefix that does not begin with `Test` for state on a test class — `Prepared*`,
`Setup*`, `Cached*`, `Stored*`, `Initial*`:

```objectscript
/// Prefix must not begin with "Test" — see .claude/rules/objectscript-testing.md
Property PreparedTestNs As %Boolean [ InitialExpression = 0 ];
```

## MultiDimensional properties take no datatype

```objectscript
Property MyData As %String [ MultiDimensional ];   ; wrong — compile error
Property MyData [ MultiDimensional ];              ; correct
```

## The `%UnitTest.Result` global is ground truth

The MCP test-runner envelope is best-effort. When a package-form run covers many classes, the
**tail entries of the per-class result list are truncated** in the returned JSON, and the
reported `total / pass / fail` can be lower than what IRIS actually recorded. Truncation has
hidden both count discrepancies and the identity of failing methods.

Two mitigations:

1. **Run per-class, not per-package, for any sweep whose result you intend to report.** Each
   single-class call fits inside the truncation budget; aggregate the totals yourself. The
   package form is fine for a quick probe during iteration.
2. **Verify the totals with a direct SQL probe before claiming a suite is green.**

`%UnitTest_Result.TestCase.ID` is a composite string `<runIdx>||<suiteName>||<className>`, so
`MAX(ID) GROUP BY Name` compares it **lexicographically** — `'9||…'` sorts above `'1044||…'`
and the picker silently selects a stale run. Extract the numeric run index, and compute the
per-class maximum through a join to `TestMethod` so that runs which recorded no methods
(partial or aborted runs) cannot be selected:

```sql
SELECT COUNT(*) AS Total,
       SUM(CASE WHEN tm.Status=1 THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN tm.Status=0 THEN 1 ELSE 0 END) AS Failed
FROM %UnitTest_Result.TestMethod tm
JOIN %UnitTest_Result.TestCase tc ON tm.TestCase = tc.ID
JOIN (
  SELECT %EXACT(tc2.Name) AS ClassName,
         MAX($PIECE(tc2.ID, '||', 1) + 0) AS MaxRunIdx
  FROM %UnitTest_Result.TestMethod tm2
  JOIN %UnitTest_Result.TestCase tc2 ON tm2.TestCase = tc2.ID
  WHERE %EXACT(tc2.Name) LIKE 'MyPackage.Test.%'
  GROUP BY %EXACT(tc2.Name)
) latest ON %EXACT(tc.Name) = latest.ClassName
        AND ($PIECE(tc.ID, '||', 1) + 0) = latest.MaxRunIdx
WHERE %EXACT(tc.Name) LIKE 'MyPackage.Test.%'
```

Swap the aggregate for `SELECT %EXACT(tm.Name) AS Method, tm.Status, %EXACT(tc.Name)` when you
need the per-method roster. Qualify `Status` as `tm.Status` — it is ambiguous across the join.

Walking the global directly (`^UnitTest.Result(<runIdx>, <suite>, <class>, <method>)`, highest
`runIdx` first) answers the same question when SQL is inconvenient.

### Never run two test classes at once

**Send one `iris_execute_tests` call, wait for it to return, then send the next. Never put two test
calls in the same message.** Tool calls in one message run concurrently, and this suite's classes share
one instance: several install and uninstall the same probe profile, database, applications and version
rows. On 2026-09-11 an agent sent 18 classes in one message. Runs 539–556 overlapped between 15:47:04 and
15:47:34, and a probe `Uninstall` in one class raced a probe `Install` in another. The race left the probe
database's directory deleted but still mounted: `SYS.Database` reads `Mounted` 1, SFN 14, with no
directory, no `IRIS.DAT` and no configuration entry. Dismount and delete both fail with
`<PROTECT>Dismount+6^SYS.Database.1`, and recreating the missing `%DB_*` resource does not change that.
From then on every probe install failed at `EnsureDatabase`, and seven classes could not run on the
development instance. No API call found so far clears such a mount. The same applies to the package form of the runner and
to anything that JOBs a test: one run in flight, ever.

### Three traps when reading results

- **The two sources use different units.** The MCP test runner's per-method `duration` is in
  **milliseconds**; the `%UnitTest_Result` global's `Duration` is in **seconds**. A runner value of
  `2262.603` is 2.26 seconds, not 37 minutes. Misreading it once produced a fictitious "20–40 minute
  `DeleteDatabase` hazard" that sent a code review off skipping a suite it should have re-run. Before
  quoting a duration, say which source it came from.
- **A single-method run becomes that class's "latest run".** The probe above picks the highest run index
  per class, so running one method after a full class run hides the other methods' results. Report a
  class as green only from a full class run.
- **A client-side timeout is not a failed run.** The runner can return `Error: Test execution timed out`
  while the run keeps going server-side and lands in the global minutes later. Do not re-submit — a second
  concurrent run of the same class races on shared fixtures and makes the latest-run attribution
  meaningless. Wait, then read the global.

## Practices

- Keep test methods focused and independent; clean up test data in `OnAfterOneTest`.
- Use descriptive assertion messages — the message is all you get on a failure.
- Compile before running; a stale class produces confusing results.
- Round-trip anything with a format or encoding (timestamps, Base64, JSON) rather than
  asserting only on the encode direction.

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

## Practices

- Keep test methods focused and independent; clean up test data in `OnAfterOneTest`.
- Use descriptive assertion messages — the message is all you get on a failure.
- Compile before running; a stale class produces confusing results.
- Round-trip anything with a format or encoding (timestamps, Base64, JSON) rather than
  asserting only on the encode direction.

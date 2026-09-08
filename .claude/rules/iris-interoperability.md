# IRIS Interoperability (Ensemble) Rules

## Signatures must match exactly

Business host callbacks are dispatched by the framework; a near-miss signature compiles and
is never called. Copy the signature from the superclass source before writing the body:

- `OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject, ByRef pHint As %String)`
- `OnMessage(pRequest As MyRequestClass, Output pResponse As MyResponseClass)`

Read `Ens.BusinessService`, `Ens.BusinessProcess` and `Ens.BusinessOperation` in
[irislib/](../../irislib/) before extending them.

## Message classes

Exchange data through custom classes extending `Ens.Request` / `Ens.Response`, not through
loose strings or `%DynamicObject` blobs passed as `%String`. Confirm the adapter each host
uses is the right one (`EnsLib.File.InboundAdapter`, `EnsLib.File.OutboundAdapter`, …) and that
argument datatypes match what the framework passes.

## `Parameter INVOCATION` — default to `InProc`

Every Business Process and Business Operation carries an explicit invocation mode:

```objectscript
Class MyApp.Example.Operation Extends Ens.BusinessOperation
{
    Parameter INVOCATION = "InProc";
}
```

`Queue` (the IRIS default) enqueues each request and processes it in a separate job — a
cross-process hop, a pool to size, and IPC overhead per call. `InProc` runs the target's
`OnMessage` synchronously in the caller's process. For synchronous BS → BP → BO flows,
`InProc` removes pure overhead at no functional cost, so it is the default here.

### The two cases where `Queue` is required

Both are about how callers dispatch, not about what the host does internally. A host that
makes outbound HTTP calls or runs slow work is still `InProc` if every caller uses
`SendRequestSync`.

1. **Target of `SendRequestAsync`.** Async semantics need the queue — with `InProc` the
   target would run synchronously in the caller's process, defeating the contract.
2. **Target of `SendRequestSyncMultiple`.** Parallel fan-out requires Queue-mode targets;
   `InProc` targets **serialize** in phase 2 and execute sequentially in submission order,
   defeating the point of the call. Such an operation also needs its pool sized to at least
   the widest fan-out.

Cross-namespace REST is **not** an exception. The caller blocks on `SendRequestSync` for the
same wall-clock duration whether the round trip happens in the caller's job or a separate
worker; `Queue` only adds pool sizing and queue infrastructure for no benefit.

### Pool size is not a class parameter

`Ens.Host` declares exactly three parameters — `INVOCATION`, `SETTINGS` and `ADAPTER`. A
`Parameter POOLSIZE` compiles happily and does **nothing**, which is worse than an error: the
class looks configured and the pool is not. Pool size is a production configuration setting
(`Ens.Config.Item.PoolSize`), set on the item in the production definition.

### Documenting a deviation

A class with `INVOCATION = "Queue"` and no doc comment naming the exception is a review flag:

```objectscript
/// Target of SendRequestSyncMultiple for parallel fan-out. Must be Queue —
/// InProc would serialize the parallel branches per Ens.Host.
Class MyApp.Example.FanOutOperation Extends Ens.BusinessOperation
{
    Parameter INVOCATION = "Queue";
}
```

## Zen portal pages: the `PAGENAME` compile trap

Any class extending `EnsPortal.Template.standardPage` must leave `Parameter PAGENAME` empty
and supply the name at runtime:

```objectscript
/// PAGENAME left blank to suppress the $$$Text(..#PAGENAME) codegen path;
/// the name is resolved at runtime by %OnGetPageName() instead.
Parameter PAGENAME = "";

Method %OnGetPageName() As %String
{
    Quit "My Form Display Name"
}
```

A non-empty `PAGENAME` makes the superclass emit `$$$Text(..#PAGENAME)` at compile time, which
writes into `^IRIS.Msg("Ensemble", ...)` to register the localizable string. That node is
ENSLIB-privileged; when the compiling process does not hold the privilege the compile fails
with `<PROTECT> ^IRIS.Msg` behind a cryptic `MPP5646` prefix. The runtime override sidesteps
the codegen path entirely.

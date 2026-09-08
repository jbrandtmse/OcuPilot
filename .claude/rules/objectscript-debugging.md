# ObjectScript Debugging

ObjectScript has no interactive debugger available to an agent. The working technique is to
capture a trace into a global and read the global back through the IRIS MCP tools.

## Debug-global pattern

```objectscript
; at the start of the run
Set ^ClineDebug = ""

; at each point of interest
Set ^ClineDebug = $Get(^ClineDebug) _ "entering Foo; pId=" _ pId _ "; "
```

Read the accumulated trace with the `iris_global_get` MCP tool on `^ClineDebug`. Console
output is not reliably propagated back to the caller; the global always is.

**Always clean up debug globals when finished** (`iris_global_kill`), and never leave
`Set ^ClineDebug = ...` statements in committed code.

## Prefer a toggled tracer over raw global writes

Once more than a couple of classes need tracing, centralize it in a small base class rather
than scattering raw global writes:

- `^ClineDebug` — the trace buffer.
- `^ClineDebugEnabled` — the on/off toggle, **defaulting to off**.

The base class exposes `SetDebug(pOn)`, `ClearDebug()`, `IsDebugEnabled()` and
`Trace(pMsg)`, where `Trace()` is a no-op that does not touch the buffer while debugging is
disabled. Classes that need instrumentation extend it and call `..Trace("...")`
unconditionally; the toggle decides whether anything is written.

```objectscript
Do ##class(MyApp.Util.Debug).SetDebug(1)
Do ##class(MyApp.Util.Debug).ClearDebug()
Set tSC = ##class(MyApp.Something).Run()
; read ^ClineDebug via iris_global_get
Do ##class(MyApp.Util.Debug).SetDebug(0)
Do ##class(MyApp.Util.Debug).ClearDebug()
```

Enabling tracing does not clear the buffer — clear it explicitly. Application code must not
invent its own parallel toggles or side channels.

## Executing code from an agent

- `iris_execute_command` handles only short, simple statements. For anything longer, write a
  helper **class method** and call it with `iris_execute_classmethod` — typed arguments,
  shorter responses, real error text.
- `iris_execute_classmethod` calls **class methods only**. To exercise an instance method,
  write a temporary class method that instantiates the class and calls it.
- Prefer a real unit test over ad-hoc command execution wherever the behavior is worth keeping.
- Delete temporary debug classes and helper methods when finished.
- Prefer the dedicated MCP tool over a generic command whenever one exists — `iris_sql_execute`
  for SQL probes, `iris_macro_info` for macro lookups, `iris_doc_search` / `iris_doc_get` for
  class introspection, the `iris-admin` and `iris-ops` tools for security, tasks and audit.
  Reserve `iris_execute_command` for one-off snippets no dedicated tool covers.

## Common error signatures

- `<INVALID OREF>` in collection code — an object was serialized (usually through
  `$ListBuild` or a global node) and is being used as though it were still an object.
- `$IsObject()` unexpectedly 0 in a test — the object was stored in a list or a global and lost
  its identity.
- A cascade of `$$` macro syntax errors — rewrite the whole file rather than patching each
  occurrence.
- `<CLASS DOES NOT EXIST>` only on the error path of a REST handler — `New $NAMESPACE` was used;
  see the namespace-switching section of [objectscript-basics.md](objectscript-basics.md).

When a debugging session drags on, simplify the architecture rather than instrumenting harder:
batching, nested collections and clever indirection are usually the thing that broke, and the
straightforward version is both correct and easier to keep correct.

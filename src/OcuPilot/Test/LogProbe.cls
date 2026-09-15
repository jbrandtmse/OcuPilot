/// <p>Test-only subclass of <class>OcuPilot.Kernel.Audit.Log</class> that captures the
/// four arguments <method>OcuPilot.Kernel.Audit.Log.Emit</method> hands to the console
/// write, instead of writing them to <code>messages.log</code>.</p>
/// <p>This exists because the one high-severity defect this tree has had so far — Flag
/// and Severity passed to the console call in the wrong order — lives at the
/// <b>call site</b>, not in the pure
/// <method>OcuPilot.Kernel.Audit.Log.ResolveSeverityAndFlag</method> lookup that
/// <class>OcuPilot.Test.Log</class> already pins. Re-introducing the swap at the call
/// site left the whole suite green, so the lookup test is not evidence for the call site.
/// Overriding the seam here is what makes the call site falsifiable.</p>
/// <p>Every emitting method reaches the seam through <code>..</code> dispatch
/// (<code>Error</code> → <code>Emit</code> → <code>WriteConsole</code>), so calling
/// <method>Error</method> on this subclass routes the real production code path into the
/// capture below without touching the production class.</p>
Class OcuPilot.Test.LogProbe Extends OcuPilot.Kernel.Audit.Log
{

/// <p>Captures into the process-private global <code>^||OcuPilotLogProbe</code> rather
/// than writing to the console log. Subscripts follow ObjectScript identifier rules (no
/// hyphens) per <code>.claude/rules/objectscript-basics.md</code>.</p>
ClassMethod WriteConsole(pMessage As %String, pFlag As %Integer, pSeverity As %Integer, pEvent As %String)
{
    Set ^||OcuPilotLogProbe("message") = pMessage
    Set ^||OcuPilotLogProbe("flag") = pFlag
    Set ^||OcuPilotLogProbe("severity") = pSeverity
    Set ^||OcuPilotLogProbe("event") = pEvent
}

/// <p>Discard anything a previous capture left behind.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLogProbe
}

/// <p>Read one captured field back. Returns <code>""</code> when nothing was captured,
/// which is itself a failure signal for a test that expected a write.</p>
/// @param pField One of "message", "flag", "severity", "event"
ClassMethod Captured(pField As %String) As %String
{
    Quit $Get(^||OcuPilotLogProbe(pField), "")
}

}

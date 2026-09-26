/// <p>Test-only subclass of <class>OcuPilot.Kernel.Audit.Event</class> that captures what a failed
/// emission reports, instead of writing it to the console log.</p>
/// <p><method>OcuPilot.Kernel.Audit.Event.Record</method> reaches its reporting seam through
/// <code>..</code> dispatch, so calling <method>Record</method> on this subclass runs the real
/// production path -- the real payload, the real redaction, the real
/// <code>$System.Security.Audit</code> call -- and routes only the failure report into the capture
/// below. That is what makes "the drop is reported" an assertion rather than an assumption: an
/// unregistered triple produces no row and no console line of its own, so without this seam the
/// only observable is the status.</p>
/// <p>The onward path from the seam to <code>messages.log</code> is
/// <class>OcuPilot.Kernel.Audit.Log</class>'s and is pinned by <class>OcuPilot.Test.Log</class>.</p>
Class OcuPilot.Test.EventProbe Extends OcuPilot.Kernel.Audit.Event
{

/// <p>Capture into the process-private global <code>^||OcuPilotEventProbe</code> rather than
/// logging. Subscripts follow ObjectScript identifier rules (no hyphens) per
/// <file>.claude/rules/objectscript-basics.md</file>.</p>
ClassMethod LogFailure(pVerb As %String, pType As %String, pId As %String, pStatus As %Status, pMessage As %String = {..#DROPPEDCONFIG})
{
    Set ^||OcuPilotEventProbe("calls") = $Get(^||OcuPilotEventProbe("calls"), 0) + 1
    Set ^||OcuPilotEventProbe("verb") = pVerb
    Set ^||OcuPilotEventProbe("entityType") = pType
    Set ^||OcuPilotEventProbe("id") = pId
    Set ^||OcuPilotEventProbe("reason") = $System.Status.GetErrorText(pStatus)
    Set ^||OcuPilotEventProbe("message") = pMessage
}

/// <p>Discard anything a previous capture left behind.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEventProbe
}

/// <p>Read one captured field back, or <code>""</code> when nothing was captured -- which is
/// itself a failure signal for a test that expected a report.</p>
/// @param pField One of "calls", "verb", "entityType", "id", "reason", "message"
ClassMethod Captured(pField As %String) As %String
{
    Quit $Get(^||OcuPilotEventProbe(pField), "")
}

}

/// <p>Test-only subclass of <class>OcuPilot.Api.Error</class> that captures the three
/// arguments <method>OcuPilot.Api.Error.RenderInternal</method> hands to the audit-log
/// seam, instead of calling <class>OcuPilot.Kernel.Audit.Log</class>.</p>
/// <p>Mirrors <class>OcuPilot.Test.LogProbe</class>'s pattern: <method>RenderInternal</method>
/// (inherited unchanged) reaches this class's override of the
/// <method>OcuPilot.Api.Error.LogError</method> seam through <code>..</code> dispatch, so
/// calling <method>RenderInternal</method> on this subclass routes the real production
/// code path into the capture below without touching the production class or the real
/// audit log.</p>
Class OcuPilot.Test.ErrorProbe Extends OcuPilot.Api.Error
{

/// <p>Captures into the process-private global <code>^||OcuPilotErrorProbe</code> rather
/// than calling <class>OcuPilot.Kernel.Audit.Log</class>. <var>pData</var> is captured as
/// its JSON serialization, not the <class>%DynamicObject</class> itself — a process-private
/// global does not preserve object identity (see
/// <code>.claude/rules/objectscript-basics.md</code>) — and re-parsed by
/// <method>Captured</method>'s caller.</p>
ClassMethod LogError(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Set ^||OcuPilotErrorProbe("subsystem") = pSubsystem
    Set ^||OcuPilotErrorProbe("message") = pMessage
    Set ^||OcuPilotErrorProbe("data") = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
}

/// <p>Discard anything a previous capture left behind.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotErrorProbe
}

/// <p>Read one captured field back. Returns <code>""</code> when nothing was captured,
/// which is itself a failure signal for a test that expected a write.</p>
/// @param pField One of "subsystem", "message", "data" ("data" is the captured pData's
/// JSON serialization, or "" when no detail object was supplied)
ClassMethod Captured(pField As %String) As %String
{
    Quit $Get(^||OcuPilotErrorProbe(pField), "")
}

}

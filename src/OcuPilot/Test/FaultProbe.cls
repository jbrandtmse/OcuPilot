/// <p>Test-only subclass of <class>OcuPilot.Kernel.Fault</class> that routes the raw vendor text
/// <method>OcuPilot.Kernel.Fault.LogRaw</method> emits into
/// <class>OcuPilot.Test.LogProbe</class>'s capture instead of <code>messages.log</code>.</p>
/// <p>Mirrors <class>OcuPilot.Test.ErrorProbe</class>'s pattern exactly: <method>LogRaw</method>
/// is inherited unchanged and reaches this class's override of the
/// <method>OcuPilot.Kernel.Fault.LogError</method> seam through <code>..</code> dispatch, so the
/// real production path runs and its argument is captured.</p>
/// <p>It forwards to <class>OcuPilot.Test.LogProbe</class> rather than capturing the arguments
/// itself, deliberately: the claim under test is "the raw text reaches the <b>emitted log
/// line</b>", and capturing at this seam alone would prove only that it reached the next method.
/// Forwarding runs the real <method>OcuPilot.Kernel.Audit.Log.Emit</method> — redaction
/// included — and the assertion is made against the line that would have been written.</p>
Class OcuPilot.Test.FaultProbe Extends OcuPilot.Kernel.Fault
{

/// <p>Route the log write through <class>OcuPilot.Test.LogProbe</class>, whose own override of
/// the console-write seam captures the formatted line.</p>
ClassMethod LogError(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Test.LogProbe).Error(pSubsystem, pMessage, pData)
}

}

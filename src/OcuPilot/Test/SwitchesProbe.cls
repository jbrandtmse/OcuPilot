/// <p>Test-only <class>OcuPilot.Api.Switches</class> subclass that replaces the handler's one
/// seam: the change record goes into <class>OcuPilot.Test.LogProbe</class>'s capture instead of
/// the console log.</p>
/// <p><b>The audit seam is deliberately NOT overridden</b>, for the reason
/// <class>OcuPilot.Test.DefinitionsProbe</class>'s header gives: the audit row is what an
/// in-process driver reads back.</p>
/// <p>The record the audit row is built from is emitted from inside the HTTP worker
/// process, where a process-private capture cannot reach it. Overriding the one call
/// <method>OcuPilot.Api.Switches.LogChange</method> writes through lets a test call the real
/// <method>LogChange</method> -- the real change-set computation, the real subsystem name -- and
/// read back exactly the line it produced.</p>
Class OcuPilot.Test.SwitchesProbe Extends OcuPilot.Api.Switches
{

ClassMethod LogInfo(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Test.LogProbe).Info(pSubsystem, pMessage, pData)
}

}

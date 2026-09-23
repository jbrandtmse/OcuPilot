/// <p>Subclass of <class>OcuPilot.Port.AdminPort</class> whose <method>Invoke</method> answers the
/// two reads <method>OcuPilot.Kernel.Audit.Event.ObserveMarking</method> makes from armed values,
/// so each arm of the marking rule runs without turning the instance's auditing off. Every other
/// call reaches the real port.</p>
/// <p>State lives in <code>^||OcuPilotMarkingPort</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.MarkingPort Extends OcuPilot.Port.AdminPort
{

/// <p>Arm the answers: <var>pAuditing</var> for <code>Security.Audit.Enabled</code> and
/// <var>pEvent</var> for <code>Security.Audit.Event</code>, each <code>"1"</code>,
/// <code>"0"</code> or <code>"fault"</code> (a 500 with an error status).</p>
ClassMethod Arm(pAuditing As %String, pEvent As %String)
{
    Kill ^||OcuPilotMarkingPort
    Set ^||OcuPilotMarkingPort("Security.Audit.Enabled") = pAuditing
    Set ^||OcuPilotMarkingPort("Security.Audit.Event") = pEvent
}

/// <p>Forget every armed answer and every recorded query.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMarkingPort
}

/// <p>The <code>source/type/name</code> the last <code>Security.Audit.Event</code> read was asked
/// for, or <code>""</code> when none was made.</p>
ClassMethod AskedEvent() As %String
{
    Quit $Get(^||OcuPilotMarkingPort("asked"))
}

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If '$Data(^||OcuPilotMarkingPort(pEndpoint), tArmed) || (pType '= "GET") {
        Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    }
    Set pResult = ""
    Set pFault = ""
    If pEndpoint = "Security.Audit.Event" {
        Set ^||OcuPilotMarkingPort("asked") = $Get(pQuery("source")) _ "/" _ $Get(pQuery("type")) _ "/" _ $Get(pQuery("name"))
    }
    If tArmed = "fault" {
        Set pHttpStatus = 500
        Set pFault = {"error": "server_error", "reason": "armed fault", "code": "INTERNAL"}
        Quit $$$ERROR($$$GeneralError, "armed fault")
    }
    Set pHttpStatus = 200
    Set pResult = {}
    Do pResult.%Set("Enabled", ''tArmed, "boolean")
    Quit $$$OK
}

}

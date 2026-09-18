/// <p>Subclass of <class>OcuPilot.Port.MgmntPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.MgmntPort</class> runs the port's real gate order, argument checks, status
/// mapping and row building against <class>OcuPilot.Test.MgmntImplFixture</class>.</p>
/// <p><method>ImplClass</method> always answers the fixture. <method>GateClass</method> answers the
/// real gate unless a test arms another (<class>OcuPilot.Test.ScreenGate</class>), and
/// <method>LogFault</method> always routes through <class>OcuPilot.Test.FaultProbe</class>, so vendor
/// text lands in <class>OcuPilot.Test.LogProbe</class>'s capture rather than
/// <file>messages.log</file>. State lives in <code>^||OcuPilotMgmntPortFixture</code>.</p>
Class OcuPilot.Test.MgmntPortFixture Extends OcuPilot.Port.MgmntPort
{

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real
/// gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotMgmntPortFixture("gate") = pClass
}

/// <p>Forget every override.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMgmntPortFixture
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotMgmntPortFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod ImplClass() As %String
{
    Quit "OcuPilot.Test.MgmntImplFixture"
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("mgmntport", pMessage, pStatus, pCode)
}

}

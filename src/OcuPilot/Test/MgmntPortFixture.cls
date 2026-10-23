/// <p>Subclass of <class>OcuPilot.Port.MgmntPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.MgmntPort</class> runs the port's real gate order, argument checks, status
/// mapping and row building against <class>OcuPilot.Test.MgmntImplFixture</class>.</p>
/// <p><method>ImplClass</method> always answers the fixture. <method>Namespaces</method> answers the roster a test arms
/// (<method>SetNamespaces</method>) and none otherwise. <method>GateClass</method> answers the
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

/// <p>Answer <method>Namespaces</method> with the roster <var>pNamespaces</var>, a <class>%List</class>. Until a test
/// arms one the roster is empty, so a delete's deployed check reads the namespace the call is for alone.</p>
ClassMethod SetNamespaces(pNamespaces As %List)
{
    Set ^||OcuPilotMgmntPortFixture("namespaces") = pNamespaces
}

/// <p>Make <method>Namespaces</method> answer an error status until <method>SetNamespaces</method> next arms a roster.</p>
ClassMethod FailNamespaces()
{
    Set ^||OcuPilotMgmntPortFixture("namespaces") = "fail"
}

ClassMethod Namespaces(Output pList As %List) As %Status
{
    Set pList = $Get(^||OcuPilotMgmntPortFixture("namespaces"), "")
    If pList = "fail" {
        Set pList = ""
        Quit $$$ERROR($$$GeneralError, "the namespace roster could not be read")
    }
    Quit $$$OK
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("mgmntport", pMessage, pStatus, pCode)
}

}

/// <p>Subclass of <class>OcuPilot.Port.DevToolPort</class> overriding only its seams, so
/// <class>OcuPilot.Test.DevToolRead</class> runs the port's real order of checks against the live instance:
/// <method>GateClass</method> answers an armed class, <method>HarvestPortClass</method> answers
/// <class>OcuPilot.Test.DevToolHarvestRecorder</class>, <method>AtelierPortClass</method> an armed class (the real one when
/// none is armed), <method>MaxDocuments</method> an armed number and <method>LogFault</method> writes to
/// <code>^||OcuPilotDevToolFixture</code>, where <method>LogCount</method> counts the lines.</p>
Class OcuPilot.Test.DevToolPortFixture Extends OcuPilot.Port.DevToolPort
{

/// <p>Forget every override and every logged line, and every call the recorder holds.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDevToolFixture
    Do ##class(OcuPilot.Test.DevToolHarvestRecorder).Clear()
}

/// <p>Answer <method>GateClass</method> with <var>pClass</var>; <code>""</code> restores the real gate.</p>
ClassMethod SetGateClass(pClass As %String)
{
    Set ^||OcuPilotDevToolFixture("gate") = pClass
}

/// <p>Answer <method>AtelierPortClass</method> with <var>pClass</var>; <code>""</code> restores the real port.</p>
ClassMethod SetAtelierClass(pClass As %String)
{
    Set ^||OcuPilotDevToolFixture("atelier") = pClass
}

/// <p>Answer <method>MaxDocuments</method> with <var>pMax</var>.</p>
ClassMethod SetMaxDocuments(pMax As %Integer)
{
    Set ^||OcuPilotDevToolFixture("max") = pMax
}

/// <p>How many lines <method>LogFault</method> was asked to write.</p>
ClassMethod LogCount() As %Integer
{
    Quit +$Get(^||OcuPilotDevToolFixture("log"))
}

ClassMethod GateClass() As %String
{
    Set tForced = $Get(^||OcuPilotDevToolFixture("gate"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod HarvestPortClass() As %String
{
    Quit "OcuPilot.Test.DevToolHarvestRecorder"
}

ClassMethod AtelierPortClass() As %String
{
    Set tForced = $Get(^||OcuPilotDevToolFixture("atelier"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod MaxDocuments() As %Integer
{
    If $Data(^||OcuPilotDevToolFixture("max")) Quit ^||OcuPilotDevToolFixture("max")
    Quit ##super()
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tIndex = $Increment(^||OcuPilotDevToolFixture("log"))
    Set ^||OcuPilotDevToolFixture("log", tIndex) = $ListBuild(pMessage, $System.Status.GetErrorText(pStatus), pCode)
}

}

/// <p>A test port for <class>OcuPilot.Test.LanguageServerEditor</class>:
/// <class>OcuPilot.Port.LanguageServerPort</class> with the admin port's seams answered from
/// <class>OcuPilot.Test.PortFixture</class>'s armed state -- the endpoint class and the resource and
/// pair checks -- and its fault log captured, so the language server port's own completion and gate run
/// against <class>OcuPilot.Test.LanguageServerEndpoint</class> and change nothing on the instance.
/// Every seam falls back to production when nothing is armed.</p>
/// <p>The armed state is read from the process-private global directly rather than through
/// <class>OcuPilot.Test.PortFixture</class>'s methods, because the port asks two of these seams in
/// <code>%SYS</code>, where that class does not resolve.</p>
Class OcuPilot.Test.LanguageServerSeamPort Extends OcuPilot.Port.LanguageServerPort
{

ClassMethod EndpointClass(pEndpoint As %String) As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("endpoint"), "")
    If tForced '= "" Quit tForced
    Quit ##super(pEndpoint)
}

ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    If $Data(^||OcuPilotPortFixture("holds")) Quit ^||OcuPilotPortFixture("holds")
    Quit ##super(pResource)
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Data(^||OcuPilotPortFixture("holdsPair")) Quit ^||OcuPilotPortFixture("holdsPair")
    Quit ##super(pPair)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("adminport", pMessage, pStatus, pCode)
}

}

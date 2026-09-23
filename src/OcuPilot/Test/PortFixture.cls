/// <p>Subclass of <class>OcuPilot.Port.AdminPort</class> overriding only its seams, so tests run
/// the port's real derivation, probe contract and invocation sequence against fixture classes and
/// armed answers. Nothing about the instance's own admin API, version row or security is changed.</p>
/// <p>Every seam falls back to <code>##super()</code> when nothing is armed, so an unconfigured
/// call behaves like production. <method>LogFault</method> is the exception: it always routes
/// through <class>OcuPilot.Test.FaultProbe</class>, so a test's vendor text lands in
/// <class>OcuPilot.Test.LogProbe</class>'s capture rather than <code>messages.log</code>.</p>
/// <p>State lives in <code>^||OcuPilotPortFixture</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.PortFixture Extends OcuPilot.Port.AdminPort
{

/// <p>The shipped roster plus the one probe pair this suite invokes:
/// <class>OcuPilot.Test.AdminPortAsync</class> drives the port's mutating-and-queued refusal
/// against <code>OcuPilotProbeAsyncWrite</code> with <code>PUT</code>, which is a pair no shipped
/// endpoint carries.</p>
/// <p><b>The probe pair is added here and never to the shipped parameter</b> (DW-1473): the
/// admitted set is what a confirmed write is allowed to issue against the instance, and a test
/// surface has no place in it. <class>OcuPilot.Test.ToolWrite</class> reads
/// <class>OcuPilot.Port.AdminPort</class>'s own copy, so this override cannot satisfy that
/// roster.</p>
Parameter MUTATINGTYPES = "WebApp.App/PUT,Security.User/PUT,Security.Audit.Enabled/PUT,Task.CRUD/RESUME,Process/SUSPEND,Process/RESUME,WebApp.App/DELETE,Security.OAuth2.Client.ClientConfiguration/DELETE,Security.OAuth2.ServerClients/DELETE,OcuPilotProbeAsyncWrite/PUT";

/// <p>Point the derivation at <var>pClass</var> instead of the vendor's routing class.
/// <code>""</code> restores the production value.</p>
ClassMethod SetAdminApiClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("api") = pClass
}

/// <p>Point the probe at <var>pClass</var> instead of the vendor's endpoint.
/// <code>""</code> restores the production value.</p>
ClassMethod SetProbeEndpointClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("probe") = pClass
}

/// <p>Resolve every endpoint name to <var>pClass</var>. <code>""</code> restores the
/// production resolution.</p>
ClassMethod SetEndpointClass(pClass As %String)
{
    Set ^||OcuPilotPortFixture("endpoint") = pClass
}

/// <p>Answer every resource check with <var>pHolds</var>.</p>
ClassMethod SetHoldsResource(pHolds As %Boolean)
{
    Set ^||OcuPilotPortFixture("holds") = pHolds
}

/// <p>Declare <var>pSet</var> (<code>&lt;pair&gt;|&lt;pair&gt;</code>) as the backing-query pair
/// set for every endpoint and request type. <code>""</code> restores the production table.</p>
ClassMethod SetQueryPairs(pSet As %String)
{
    Set ^||OcuPilotPortFixture("queryPairs") = pSet
}

/// <p>Answer every backing-query pair check with <var>pHolds</var>. Distinct from
/// <method>SetHoldsResource</method>, which arms the endpoint's own
/// <code>ResourcesOR()</code> gate: DW-274's whole point is that a caller can pass one and be
/// refused by the other.</p>
ClassMethod SetHoldsPair(pHolds As %Boolean)
{
    Set ^||OcuPilotPortFixture("holdsPair") = pHolds
}

/// <p>Bound the async wait at <var>pSeconds</var>.</p>
ClassMethod SetAsyncTimeout(pSeconds As %Numeric)
{
    Set ^||OcuPilotPortFixture("timeout") = pSeconds
}

/// <p>Answer every poll with the <code>AsyncResult</code> answer <var>pJson</var>, and delete no
/// row. Stored as JSON because a process-private global cannot hold an OREF.</p>
ClassMethod SetCannedAnswer(pJson As %String)
{
    Set ^||OcuPilotPortFixture("canned") = pJson
}

/// <p>Answer every poll as a refused read: HTTP <var>pHttp</var>, no answer, and an error status
/// carrying <var>pText</var>. Deletes no row. Takes precedence over
/// <method>SetCannedAnswer</method>.</p>
ClassMethod SetCannedPollRefusal(pHttp As %Integer, pText As %String)
{
    Set ^||OcuPilotPortFixture("pollHttp") = pHttp
    Set ^||OcuPilotPortFixture("pollText") = pText
}

/// <p>A recorded value: <code>name</code> (the endpoint's <code>Name</code> when
/// <code>Run()</code> was about to start), <code>taskName</code> (the last real poll's
/// <code>TaskName</code>), <code>forgot</code> (the GUID last passed to
/// <method>ForgetTask</method>) or <code>polls</code> (how many polls ran). <code>""</code> when
/// never recorded.</p>
ClassMethod Recorded(pKey As %String) As %String
{
    Quit $Get(^||OcuPilotPortFixture("recorded", pKey), "")
}

/// <p>Forget every override and record.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotPortFixture
}

ClassMethod AdminApiClass() As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("api"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

ClassMethod ProbeEndpointClass() As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("probe"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

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

ClassMethod QueryPairs(pEndpoint As %String, pType As %String) As %String
{
    Set tForced = $Get(^||OcuPilotPortFixture("queryPairs"), "")
    If tForced '= "" Quit tForced
    Quit ##super(pEndpoint, pType)
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Data(^||OcuPilotPortFixture("holdsPair")) Quit ^||OcuPilotPortFixture("holdsPair")
    Quit ##super(pPair)
}

ClassMethod AsyncTimeout() As %Numeric
{
    Set tForced = $Get(^||OcuPilotPortFixture("timeout"), "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

/// <p>Records the endpoint's <code>Name</code>; an endpoint without one records nothing.</p>
ClassMethod OnBeforeRun(pEndpoint As %RegisteredObject)
{
    Try {
        Set ^||OcuPilotPortFixture("recorded", "name") = $Property(pEndpoint, "Name")
    } Catch {
    }
}

ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set ^||OcuPilotPortFixture("recorded", "polls") = $Get(^||OcuPilotPortFixture("recorded", "polls"), 0) + 1
    If $Data(^||OcuPilotPortFixture("pollHttp")) {
        Set pAnswer = ""
        Set pHttpStatus = ^||OcuPilotPortFixture("pollHttp")
        Quit $$$ERROR($$$GeneralError, $Get(^||OcuPilotPortFixture("pollText"), ""))
    }
    Set tCanned = $Get(^||OcuPilotPortFixture("canned"), "")
    If tCanned '= "" {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tCanned)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tSC = ##super(pGuid, .pAnswer, .pHttpStatus)
    If $IsObject($Get(pAnswer)) Set ^||OcuPilotPortFixture("recorded", "taskName") = pAnswer.TaskName
    Quit tSC
}

ClassMethod ForgetTask(pGuid As %String)
{
    Set ^||OcuPilotPortFixture("recorded", "forgot") = pGuid
    If $Get(^||OcuPilotPortFixture("canned"), "") '= "" Quit
    If $Data(^||OcuPilotPortFixture("pollHttp")) Quit
    Do ##super(pGuid)
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw("adminport", pMessage, pStatus, pCode)
}

}

/// <p>The two turn rows that take minutes (AD-7, AD-31): a turn whose provider call outlasts the Web
/// Gateway's 60-second response timeout while the start and every poll answer at once, and a turn
/// nobody polls, abandoned when its lease lapses.</p>
/// <p><b>It creates an IRIS user and a role and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both <parameter>ARMINGVARIABLE</parameter>
/// and <parameter>PROVIDERVARIABLE</parameter> read 1.</b> It runs for well over three minutes; a
/// client-side timeout is not a failure. After every method no probe job is alive and no probe
/// turn, slot or stub node remains.</p>
Class OcuPilot.Test.TurnLong Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turnlong-probe";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnLong creates an IRIS user and a role and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnLong runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal($Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    Set ..PreparedDefinitionId = $Get(tId)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnLong teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>The stub holds its one call for 70 seconds. The start answers 202 within five seconds with the
/// client willing to wait 120, every poll answers within five, and the turn completes having run at
/// least 70 seconds -- on an instance whose gateway answers a request held that long with 504 at
/// 60.</p>
/// <p>Mutation: call <method>OcuPilot.Kernel.Agent.Job.Run</method> in
/// <method>OcuPilot.Api.Turn.HandleStart</method> instead of spawning the job -- the start is held
/// past the gateway timeout, no 202 arrives, and this goes red.</p>
Method TestATurnOutlivesTheGatewayResponseTimeout()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOrigNS = $NAMESPACE
    Do ##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tTimeout, .tSource)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tTimeout, 60, "the gateway's response timeout is the stock 60 seconds (" _ tSource _ ")")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 70, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))

    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tConvStatus, .tConvText)
    Set tBegan = $ZHorolog
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "long", tConvId), .tStatus, .tText, .tHeaders, 120)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    Do $$$AssertTrue(($ZHorolog - tBegan) < 5, "within five seconds: " _ ($ZHorolog - tBegan))
    If tStatus '= 202 Quit
    Set tId = ##class(%DynamicObject).%FromJSON(tText).turnId

    Set tSlowest = 0
    Set tState = ""
    Set tDeadline = $ZHorolog + 120
    While '##class(OcuPilot.Kernel.State.Turn).IsTerminal(tState) && ($ZHorolog < tDeadline) {
        Hang 5
        Set tAsked = $ZHorolog
        Do $ClassMethod(..#FIXTURE, "Call", "GET", "/turn/" _ tId _ "/progress", tUser, ..PreparedPassword, "", .tStatus, .tText, .tHeaders)
        If ($ZHorolog - tAsked) > tSlowest Set tSlowest = $ZHorolog - tAsked
        Do $$$AssertEquals(tStatus, 200, "a poll answers")
        If tStatus = 200 Set tView = ##class(%DynamicObject).%FromJSON(tText), tState = tView.state
    }
    Do $$$AssertTrue(tSlowest < 5, "every poll answered within five seconds, the slowest in " _ tSlowest)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    If tState '= "completed" Quit
    Set tRan = ##class(OcuPilot.Kernel.State.Turn).SecondsOf(tView.endedAt) - ##class(OcuPilot.Kernel.State.Turn).SecondsOf(tView.startedAt)
    Do $$$AssertTrue(tRan >= 70, "having run at least 70 seconds: " _ tRan)
}

/// <p>A turn nobody polls: the stub holds its first call 125 seconds and asks for a tool. Once the
/// stored turn has ended, one poll finds it abandoned for its lease, with no second provider
/// call.</p>
/// <p>Mutation: remove the lease comparison from <method>OcuPilot.Kernel.Agent.Loop.Boundary</method>
/// -- the turn makes its second call and completes, and this goes red.</p>
Method TestALapsedLeaseAbandonsTheTurn()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 125, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("probe.tool"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tConvStatus, .tConvText)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "unwatched", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    If tStatus '= 202 Quit
    Set tId = ##class(%DynamicObject).%FromJSON(tText).turnId

    Set tDeadline = $ZHorolog + 160
    While (##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "returned") = "") && ($ZHorolog < tDeadline) {
        Hang 1
    }
    Do $$$AssertNotEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "returned"), "", "the provider call returned")
    Do ##class(OcuPilot.Test.TurnFixture).AwaitTerminal(tId, 30)
    Do $ClassMethod(..#FIXTURE, "Call", "GET", "/turn/" _ tId _ "/progress", tUser, ..PreparedPassword, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the one poll answers")
    If tStatus '= 200 Quit
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tView.state _ "|" _ $Select($IsObject(tView.error): tView.error.code, 1: ""), "abandoned|TURN.ABANDONED.LEASE", "the turn was abandoned for its lease")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, "with no second provider call")
}

}

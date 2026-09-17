/// <p>DW-347, end to end over the wire: a <code>turnprobe</code> definition is created, its key
/// stored, Test connection passed, the definition enabled and made the default, and a turn posted --
/// and the key header the turn's provider call carried hashes to the key that was posted.</p>
/// <p><b>It spawns a turn job and moves the default marker, so <method>OnBeforeAllTests</method>
/// refuses to run unless <parameter>ARMINGVARIABLE</parameter> reads 1.</b> Only
/// <file>scripts/ci-throwaway.sh</file> sets it. Teardown removes the definition, its credential
/// entry, the turn and the stub nodes, and puts the default marker back where it was.</p>
Class OcuPilot.Test.TurnChain Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter TAG = "turnchain-probe";

Parameter NAME = "OcuPilotProbeAgentTurnChain";

Parameter CREDENTIAL = "OcuPilotProbeTurnChainCredential";

/// <p>A fabricated key of the shape the <code>turnprobe</code> row requires. It reaches no
/// provider.</p>
Parameter PROBEKEY = "sk-ant-ocupilotturnchain0000000000";

Property PreparedPrior As %String;

Property PreparedKey As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = ""
    Set ..PreparedKey = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnChain runs a turn job against the turnprobe provider row and moves the default agent definition, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPrior = ##class(OcuPilot.Test.TurnWireFixture).MarkedDefault()
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit tSC
    Set tOwner = ##class(OcuPilot.Test.Http).GetTestUsername()
    If ..PreparedKey '= "" {
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(..PreparedKey, tOwner, .tStopped)
        Do ##class(OcuPilot.Test.TurnFixture).AwaitTerminal(..PreparedKey, 30)
        Set tPid = ##class(OcuPilot.Test.TurnFixture).Field(..PreparedKey, "JobId")
        If (tPid '= "") && '##class(OcuPilot.Kernel.State.Turn).IsTerminal(##class(OcuPilot.Test.TurnFixture).Field(..PreparedKey, "State")) && $Data(^$JOB(tPid)) Do $SYSTEM.Process.Terminate(tPid)
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(..PreparedKey)
    }
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    If (..PreparedPrior '= "") && ##class(OcuPilot.Kernel.State.Agent).%ExistsId(..PreparedPrior) Do ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..PreparedPrior)
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Set tLeft = ""
    If tRemaining '= 0 Set tLeft = tLeft _ " definitions"
    If ##class(OcuPilot.Test.CredentialFixture).Exists(..#CREDENTIAL) Set tLeft = tLeft _ " credential"
    If (..PreparedKey '= "") && (##class(OcuPilot.Test.TurnFixture).Field(..PreparedKey, "State") '= "") Set tLeft = tLeft _ " turn"
    If ##class(OcuPilot.Test.TurnFixture).SlotOwner(tOwner) '= "" Set tLeft = tLeft _ " slot"
    If ##class(OcuPilot.Test.TurnProvider).Remains(..#TAG) Set tLeft = tLeft _ " stub"
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnChain teardown left:" _ tLeft)
    Quit tSC
}

/// <p>One request to the API as the suite's own account.</p>
Method Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, "/api/ocupilot" _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pText, .pHeaders, pBody, "application/json")
}

/// <p>Send <var>pMethod</var> <var>pPath</var> and assert it answered <var>pExpected</var> as JSON;
/// the parsed body, or <code>""</code>.</p>
Method Expect(pWhat As %String, pMethod As %String, pPath As %String, pBody As %String, pExpected As %Integer) As %DynamicObject
{
    Do ..Call(pMethod, pPath, pBody, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, pExpected, pWhat _ ": answers " _ pExpected _ " (" _ $Extract(tText, 1, 300) _ ")")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, pWhat _ ": as JSON")
    If tStatus '= pExpected Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tText)
}

/// <p>The stored key reaches the turn's provider call: the key header's recorded SHA-256 equals the
/// posted key's.</p>
/// <p>Mutation: record the SHA-256 of <code>""</code> in <method>OcuPilot.Test.TurnProvider.IssueHttpsPost</method>
/// -- this goes red.</p>
Method TestAKeyStoredOverTheWireReachesTheTurnsProviderCall()
{
    Set tCreated = ..Expect("create", "POST", "/agent/definitions", "{""name"":""" _ ..#NAME _ """,""provider"":""turnprobe"",""model"":""" _ ..#TAG _ """,""credType"":""creds"",""credentialName"":""" _ ..#CREDENTIAL _ """}", 201)
    If '$IsObject(tCreated) Quit
    Set tId = tCreated.id
    Do ..Expect("store", "POST", "/agent/definitions/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), 200)
    Set tTested = ..Expect("test", "POST", "/agent/definitions/" _ tId _ "/test", "", 200)
    If $IsObject(tTested) Do $$$AssertEquals(tTested.connectionVerified, 1, "Test connection verifies the stored definition")
    Do ..Expect("enable", "PUT", "/agent/definitions/" _ tId, "{""enabled"":true}", 200)
    Do ..Expect("default", "POST", "/agent/definitions/" _ tId _ "/default", "", 200)

    Set tConvCreated = ..Expect("conversation", "POST", "/conversation", "", 201)
    Set tConvId = $Select($IsObject(tConvCreated): tConvCreated.conversationId, 1: "")
    Set tCallsBefore = ##class(OcuPilot.Test.TurnProvider).Calls(..#TAG)
    Set tStarted = ..Expect("turn", "POST", "/turn", "{""message"":""chain"",""conversationId"":""" _ tConvId _ """}", 202)
    If '$IsObject(tStarted) Quit
    Set ..PreparedKey = tStarted.turnId
    Set tState = ##class(OcuPilot.Test.TurnWireFixture).AwaitEnd(..PreparedKey, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), 30, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Set tCall = ##class(OcuPilot.Test.TurnProvider).Calls(..#TAG)
    Do $$$AssertEquals(tCall, tCallsBefore + 1, "after one provider call of its own")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, tCall, "keySha"), ##class(OcuPilot.Test.TurnProvider).Sha(..#PROBEKEY), "and that call's key header hashes to the key posted")
}

}

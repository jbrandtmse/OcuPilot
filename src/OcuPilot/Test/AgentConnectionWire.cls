/// <p>Story 10.5 over the wire (AD-42): <code>POST /agent/definitions/:id/test</code> against a
/// <code>turnprobe</code> definition whose provider holds its call past the Web Gateway's
/// <code>Server_Response_Timeout</code> answers OcuPilot's own 504 envelope before the gateway
/// would, records nothing verified even after the call returns, and a later test that answers
/// verifies the definition so it can be enabled.</p>
/// <p><b>It runs as the suite's own account against the armed <code>turnprobe</code> row, so
/// <method>OnBeforeAllTests</method> refuses to run unless <parameter>PROVIDERVARIABLE</parameter>
/// reads 1.</b> It needs the stock gateway timeout of 60 seconds, which it asserts first, and runs
/// for about two minutes. Teardown removes the definition, its credential entry and the stub
/// nodes.</p>
Class OcuPilot.Test.AgentConnectionWire Extends %UnitTest.TestCase
{

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter TAG = "acw-probe";

Parameter NAME = "OcuPilotProbeAgentConnectionWire";

Parameter CREDENTIAL = "OcuPilotProbeConnectionWireCredential";

/// <p>A fabricated key of the shape the <code>turnprobe</code> row requires. It reaches no
/// provider.</p>
Parameter PROBEKEY = "sk-ant-ocupilotwireprobe00000000000";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionWire tests a definition against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 Quit $$$OK
    Do ##class(OcuPilot.Test.AgentConnectionBound).AwaitReturned(..#TAG, 30)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Set tLeft = ""
    If tRemaining '= 0 Set tLeft = tLeft _ " definitions"
    If ##class(OcuPilot.Test.CredentialFixture).Exists(..#CREDENTIAL) Set tLeft = tLeft _ " credential"
    If ##class(OcuPilot.Test.TurnProvider).Remains(..#TAG) Set tLeft = tLeft _ " stub"
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionWire teardown left:" _ tLeft)
    Quit tSC
}

/// <p>One request to the API as the suite's own account, waiting at most <var>pTimeout</var>
/// seconds for the answer.</p>
Method Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders, pTimeout As %Integer = 0) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, "/api/ocupilot" _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pText, .pHeaders, pBody, "application/json", , pTimeout)
}

/// <p>Send <var>pMethod</var> <var>pPath</var> and assert it answered <var>pExpected</var> as JSON;
/// the parsed body, or <code>""</code>.</p>
Method Expect(pWhat As %String, pMethod As %String, pPath As %String, pBody As %String, pExpected As %Integer, pTimeout As %Integer = 0) As %DynamicObject
{
    Do ..Call(pMethod, pPath, pBody, .tStatus, .tText, .tHeaders, pTimeout)
    Do $$$AssertEquals(tStatus, pExpected, pWhat _ ": answers " _ pExpected _ " (" _ $Extract(tText, 1, 300) _ ")")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, pWhat _ ": as JSON")
    If tStatus '= pExpected Quit ""
    Set tParsed = ""
    Try {
        Set tParsed = ##class(%DynamicObject).%FromJSON(tText)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), pWhat _ ": the body parses")
    }
    Quit tParsed
}

/// <p>With the stock gateway timeout, a provider holding its call for 70 seconds is answered
/// <code>PROVIDER.TESTTIMEOUT</code> after 45 to 58 seconds -- the gateway would have cut the
/// request at 60 with an empty 504 -- and the definition reads unverified once the call has
/// returned. The next test, which answers at once, verifies it, and it can then be enabled.</p>
/// <p>Both calls carry the stored key, which the child's own adapter resolved.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Call</method> wait for the result
/// with no deadline -- red, the gateway's own 504 arriving at 60 seconds with no envelope.
/// Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.ValuesJson</method> leave out
/// <code>credentialName</code> -- red on the key the calls carried.</p>
Method TestATestAnswersBeforeTheGatewayDoes()
{
    Do ##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tTimeout, .tSource)
    Do $$$AssertEquals(tTimeout, 60, "the gateway's response timeout is the stock 60 seconds (" _ tSource _ ")")
    If tTimeout '= 60 Quit
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 70, ##class(OcuPilot.Test.TurnProvider).TextReply("late"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("prompt"))

    Set tCreated = ..Expect("create", "POST", "/agent/definitions", "{""name"":""" _ ..#NAME _ """,""provider"":""turnprobe"",""model"":""" _ ..#TAG _ """,""credType"":""creds"",""credentialName"":""" _ ..#CREDENTIAL _ """}", 201)
    If '$IsObject(tCreated) Quit
    Set tId = tCreated.id
    Do ..Expect("store", "POST", "/agent/definitions/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), 200)

    Set tBegan = $ZHorolog
    Set tRefused = ..Expect("test past the bound", "POST", "/agent/definitions/" _ tId _ "/test", "", 504, 120)
    Set tElapsed = $ZHorolog - tBegan
    Do $$$AssertTrue((tElapsed >= 45) && (tElapsed <= 58), "answered after 45 to 58 seconds, before the gateway's 60: " _ tElapsed)
    If $IsObject(tRefused) {
        Do $$$AssertEquals(tRefused.code, "PROVIDER.TESTTIMEOUT", "in OcuPilot's own envelope: " _ tRefused.%ToJSON())
        Do $$$AssertEquals(tRefused.error, "unavailable", "on the unavailable slug")
        Do $$$AssertTrue($IsObject(tRefused.detail) && (tRefused.detail.providerLabel = "Turn probe"), "naming the provider's label in its detail")
        If $IsObject(tRefused.detail) Do $$$AssertTrue((tRefused.detail.waitedSeconds >= 45) && (tRefused.detail.waitedSeconds <= 58), "and the seconds it waited: " _ tRefused.detail.waitedSeconds)
    }

    Do $$$AssertTrue(##class(OcuPilot.Test.AgentConnectionBound).AwaitReturned(..#TAG, 40), "the provider call returned, late")
    Hang 0.5
    Set tRead = ..Expect("read after the late answer", "GET", "/agent/definitions/" _ tId, "", 200)
    If $IsObject(tRead) Do $$$AssertEquals(tRead.connectionVerified, 0, "the late answer verified nothing")

    Set tTested = ..Expect("test that answers", "POST", "/agent/definitions/" _ tId _ "/test", "", 200, 60)
    If $IsObject(tTested) {
        Do $$$AssertEquals(tTested.connectionVerified, 1, "a test that answers verifies the definition")
        Do $$$AssertEquals(tTested.reply, "prompt", "with its own call's reply")
    }
    For tCall = 1, 2 {
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, tCall, "keySha"), ##class(OcuPilot.Test.TurnProvider).Sha(..#PROBEKEY), "the stored key reached test call " _ tCall _ " through the child")
    }
    Do ..Expect("enable", "PUT", "/agent/definitions/" _ tId, "{""enabled"":true}", 200)
}

}

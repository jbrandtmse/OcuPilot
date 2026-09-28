/// <p>Story 10.5's wall-clock bound on Test connection (AD-42): the bound's arithmetic and its
/// source, the timeout envelope a provider that has not answered earns, the key a request body
/// carries crossing into the child, and a late answer that can verify nothing.</p>
/// <p><b>The provider legs drive <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> in
/// process through <class>OcuPilot.Test.AgentConnectionProbe</class></b>, whose bound is a switch;
/// the call itself runs in the shipped child job against the armed <code>turnprobe</code> row, so
/// <method>OnBeforeAllTests</method> refuses to run unless <parameter>PROVIDERVARIABLE</parameter>
/// reads 1. It stores one credential entry and one definition, removed in
/// <method>OnAfterAllTests</method>; every method waits for its children's provider calls to
/// return before the next begins.</p>
Class OcuPilot.Test.AgentConnectionBound Extends %UnitTest.TestCase
{

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter PROBE = "OcuPilot.Test.AgentConnectionProbe";

Parameter NAME = "OcuPilotProbeAgentConnectionBound";

Parameter CREDENTIAL = "OcuPilotProbeConnectionBoundCredential";

Parameter ENDPOINTURL = "https://192.0.2.10/v1/messages";

/// <p>The stored key, fabricated in the shape the <code>turnprobe</code> row's prefix requires. It
/// reaches no provider.</p>
Parameter STOREDKEY = "sk-ant-ocupilotboundprobe0000000000";

/// <p>A second fabricated key, sent in a request body.</p>
Parameter BODYKEY = "sk-ant-ocupilotboundprobebody000000";

/// <p>Every stub script tag a method here names.</p>
Parameter TAGS = "acb-hang,acb-local,acb-status,acb-body,acb-stale-a,acb-stale-b,acb-later,acb-unspawned,acb-unstored,acb-shape,acb-limited,acb-long";

/// <p>The label the <code>turnprobe</code> row carries, which a timeout reason names.</p>
Parameter LABEL = "Turn probe";

Property PreparedDefinitionId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionBound spawns Test connection children against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Do ..ForgetTags()
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    Set tSC = ##class(OcuPilot.Kernel.Secret.Ladder).Store(..#CREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#STOREDKEY), "apiKey")
    If $$$ISERR(tSC) Quit tSC
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#NAME
    Set tRow.Provider = "turnprobe"
    Set tRow.Model = "acb-hang"
    Set tRow.EndpointUrl = ..#ENDPOINTURL
    Set tRow.CredType = "creds"
    Set tRow.CredentialName = ..#CREDENTIAL
    Set tRow.MaxTokens = 1024
    Set tRow.MaxIterationsPerTurn = 10
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tRow.%Id()
    Set tRow = ""
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 Quit $$$OK
    Do ..ForgetTags()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    Set tLeft = ""
    If tRemaining '= 0 Set tLeft = tLeft _ " definitions"
    If ##class(OcuPilot.Test.CredentialFixture).Exists(..#CREDENTIAL) Set tLeft = tLeft _ " credential"
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionBound teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Forget")
    Do ##class(OcuPilot.Test.AgentConnectionInline).Forget()
    Do ##class(OcuPilot.Test.AgentConnectionUnspawned).Forget()
    Do ..ForgetTags()
    Quit ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 0, 0)
}

Method OnAfterOneTest() As %Status
{
    For tI = 1:1:$Length(..#TAGS, ",") {
        Set tTag = $Piece(..#TAGS, ",", tI)
        Do $$$AssertTrue(..AwaitReturned(tTag, 15), "every provider call scripted under " _ tTag _ " returned before teardown")
    }
    Do ..ForgetTags()
    Do $ClassMethod(..#PROBE, "Forget")
    Do ##class(OcuPilot.Test.AgentConnectionInline).Forget()
    Do ##class(OcuPilot.Test.AgentConnectionUnspawned).Forget()
    Quit $$$OK
}

/// <p>Remove every stub script this class names.</p>
Method ForgetTags()
{
    For tI = 1:1:$Length(..#TAGS, ",") {
        Do ##class(OcuPilot.Test.TurnProvider).Forget($Piece(..#TAGS, ",", tI))
    }
}

/// <p>Wait up to <var>pSeconds</var> for every call <var>pTag</var>'s script has begun to record
/// <code>returned</code>; whether they all did.</p>
ClassMethod AwaitReturned(pTag As %String, pSeconds As %Integer) As %Boolean
{
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Set tPending = 0
        For tCall = 1:1:##class(OcuPilot.Test.TurnProvider).Calls(pTag) {
            If ##class(OcuPilot.Test.TurnProvider).Recorded(pTag, tCall, "returned") = "" Set tPending = 1
        }
        If 'tPending Quit
        If $ZHorolog > tDeadline Quit
        Hang 0.25
    }
    Quit 'tPending
}

/// <p>Wait up to <var>pSeconds</var> for <var>pTag</var>'s script to record call
/// <var>pCall</var> at all.</p>
ClassMethod AwaitCall(pTag As %String, pCall As %Integer, pSeconds As %Integer) As %Boolean
{
    Set tDeadline = $ZHorolog + pSeconds
    While (##class(OcuPilot.Test.TurnProvider).Calls(pTag) < pCall) && ($ZHorolog < tDeadline) {
        Hang 0.25
    }
    Quit ##class(OcuPilot.Test.TurnProvider).Calls(pTag) >= pCall
}

/// <p>One Test connection outcome for definition <var>pId</var> through
/// <parameter>PROBE</parameter>, from the inputs <method>OcuPilot.Api.Definitions.HandleTest</method>
/// hands <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>; <var>pElapsed</var> is the
/// wall-clock seconds it took.</p>
ClassMethod Outcome(pId As %String, pBody As %DynamicObject, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pElapsed As %Numeric) As %Status
{
    Set pElapsed = 0
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$ERROR($$$GeneralError, "No agent definition with id " _ pId)
    Do $ClassMethod(..#PROBE, "ValuesFromRow", tRow, .tStored)
    Set tVersion = +tRow.RowVersion
    Set tRow = ""
    Kill tValues
    Merge tValues = tStored
    Do $ClassMethod(..#PROBE, "MergeBody", pBody, .tValues, .tPresent)
    Set tValues("connectionVerified") = $Get(tStored("connectionVerified"))
    Set tValues("enabled") = $Get(tStored("enabled"))
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
    Set tBegan = $ZHorolog
    Do $ClassMethod(..#PROBE, "ConnectionOutcome", pId, .tValues, .tStored, .pAnswer, .pHttpStatus, .pFault, pBody, tVersion)
    Set pElapsed = $ZHorolog - tBegan
    Quit $$$OK
}

/// <p><var>pFault</var>'s <var>pPath</var> member, or <code>""</code> when there is no fault.</p>
ClassMethod FaultAt(pFault As %RawString, pPath As %String) As %String
{
    If '$IsObject(pFault) Quit ""
    If pPath = "code" Quit pFault.code
    If pPath = "reason" Quit pFault.reason
    If '$IsObject(pFault.detail) Quit ""
    Quit pFault.detail.%Get(pPath)
}

/// <p>A body naming the stub script <var>pTag</var> through the model, which is not a security
/// field, so the test stays as stored.</p>
ClassMethod BodyFor(pTag As %String) As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set("model", pTag, "string")
    Quit tBody
}

/// <p>The bound is the gateway's timeout less <code>min(10, g\2)</code>, at least 1, and an
/// unusable value is read as the stock 60.</p>
/// <p>Mutation: <parameter>OcuPilot.Kernel.Provider.TestCall.MARGINSECONDS</parameter> 0 -- red on
/// every row but <code>1:1</code>.</p>
Method TestTheBoundArithmetic()
{
    Set tClass = "OcuPilot.Kernel.Provider.TestCall"
    For tRow = "60:50", "20:10", "10:5", "300:290", "2:1", "1:1" {
        Do $$$AssertEquals($ClassMethod(tClass, "BoundSeconds", $Piece(tRow, ":", 1)), $Piece(tRow, ":", 2), "a gateway timeout of " _ $Piece(tRow, ":", 1) _ " bounds the test at " _ $Piece(tRow, ":", 2))
    }
    For tUnusable = "", "sixty", "0", "-5" {
        Do $$$AssertEquals($ClassMethod(tClass, "BoundSeconds", tUnusable), 50, "an unusable gateway value '" _ tUnusable _ "' is read as 60, bounding at 50")
    }
}

/// <p>The bound follows the value the gateway read answers: nothing is read as 60, and 20 is 20.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.GatewaySeconds</method> answer 60
/// always -- red on the 20 leg.</p>
Method TestTheGatewayReadSetsTheBound()
{
    Set tClass = "OcuPilot.Test.AgentConnectionInline"
    Do ##class(OcuPilot.Test.AgentConnectionInline).SetGateway("")
    Do $$$AssertEquals($ClassMethod(tClass, "GatewaySeconds", .tSource), 60, "a read that answers nothing is the stock 60")
    Do $$$AssertEquals(tSource, "unread", "and says it was not read")
    Do ##class(OcuPilot.Test.AgentConnectionInline).SetGateway("ninety")
    Do $$$AssertEquals($ClassMethod(tClass, "GatewaySeconds", .tSource), 60, "a read that answers a non-number is the stock 60 too")
    Do ##class(OcuPilot.Test.AgentConnectionInline).SetGateway(20)
    Set tSeconds = $ClassMethod(tClass, "GatewaySeconds", .tSource)
    Do $$$AssertEquals(tSeconds, 20, "a read that answers 20 is 20")
    Do $$$AssertEquals(tSource, "probe", "from the source the read named")
    Do $$$AssertEquals($ClassMethod(tClass, "BoundSeconds", tSeconds), 10, "which bounds the test at 10")
}

/// <p>A provider that has not answered by the bound: the request answers
/// <code>PROVIDER.TESTTIMEOUT</code> at the bound, not at the provider's pace, with the reason
/// resolved and the detail the client reads -- and the definition stays unverified after the
/// child's call returns.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Call</method> wait for the result
/// with no deadline -- red on the elapsed time and the code. Mutation: record the verification in
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> when the call timed out -- red on
/// the flags read after the child returned.</p>
Method TestAnUnansweredTestAnswersAtItsBound()
{
    Set tTag = "acb-hang"
    Do $ClassMethod(..#PROBE, "SetBound", 2)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 6, ##class(OcuPilot.Test.TurnProvider).TextReply("late"))
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "PROVIDER.TESTTIMEOUT", "a provider that has not answered earns the test timeout")
    Do $$$AssertTrue('$IsObject($Get(tAnswer)), "and no answer")
    Do $$$AssertEquals(tHttpStatus, 504, "as 504")
    Do $$$AssertTrue(tElapsed >= 2, "after the bound had passed: " _ tElapsed)
    Do $$$AssertTrue(tElapsed < 4, "and well before the provider's six seconds: " _ tElapsed)
    Set tExpected = $Replace($Replace(##class(OcuPilot.Kernel.Provider.Base).#REASONTESTTIMEOUT, "<provider>", ..#LABEL), "<n>", 2)
    Do $$$AssertEquals(..FaultAt(tFault, "reason"), tExpected, "with the published reason, both placeholders resolved")
    Do $$$AssertEquals(..FaultAt(tFault, "waitedSeconds"), 2, "detail.waitedSeconds is the seconds waited")
    Do $$$AssertEquals(..FaultAt(tFault, "providerLabel"), ..#LABEL, "detail.providerLabel is the catalog label")
    Do $$$AssertEquals(..FaultAt(tFault, "keySource"), "stored", "detail.keySource says which key was tried")
    Do $$$AssertEquals(..FaultAt(tFault, "testedAsStored"), 1, "and detail.testedAsStored that the values were the stored ones")
    Do $$$AssertTrue(..AwaitCall(tTag, 1, 5), "the child made its provider call")
    Do $$$AssertTrue(..AwaitReturned(tTag, 15), "and the call returned, late")
    Hang 0.5
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(..PreparedDefinitionId), "0|0", "the late answer verified nothing")
}

/// <p>A definition marked local gets the local reason, which names no provider.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.TimeoutFault</method> select the
/// non-local code whatever <var>pMarkedLocal</var> says -- red on the code and the reason.</p>
Method TestALocalDefinitionGetsTheLocalReason()
{
    Set tTag = "acb-local"
    Do $ClassMethod(..#PROBE, "SetBound", 2)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 4, ##class(OcuPilot.Test.TurnProvider).TextReply("late"))
    Set tBody = ..BodyFor(tTag)
    Do tBody.%Set("markedLocal", 1, "boolean")
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, tBody, .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "PROVIDER.TESTTIMEOUTLOCAL", "a local definition earns the local timeout")
    Do $$$AssertEquals(tHttpStatus, 504, "as 504")
    Set tExpected = $Replace(##class(OcuPilot.Kernel.Provider.Base).#REASONTESTTIMEOUTLOCAL, "<n>", 2)
    Do $$$AssertEquals(..FaultAt(tFault, "reason"), tExpected, "with the local reason resolved")
    Do $$$AssertTrue(..AwaitReturned(tTag, 15), "the child's call returned before teardown")
}

/// <p>A per-read timeout the child meets before the bound is answered the same way.</p>
/// <p>Mutation: drop the <code>PROVIDER.TIMEOUT</code> arm of
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>'s mapping -- red, the port's own
/// code arriving instead.</p>
Method TestAPerReadTimeoutIsTheTestTimeout()
{
    Set tTag = "acb-status"
    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 0, "", 0)
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "PROVIDER.TESTTIMEOUT", "the port's transport timeout becomes the test timeout")
    Do $$$AssertEquals(tHttpStatus, 504, "as 504")
    Set tWaited = ..FaultAt(tFault, "waitedSeconds")
    Do $$$AssertTrue((tWaited '= "") && (tWaited <= (tElapsed + 1)), "naming the seconds actually waited, not the bound: " _ tWaited _ " of " _ tElapsed)
}

/// <p>A key the request body carries reaches the child's provider call.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Child</method> skip the key's
/// <code>%Set</code> -- red, the call faulting for a missing key with no header recorded.</p>
Method TestABodyKeyCrossesByMessage()
{
    Set tTag = "acb-body"
    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("body key"))
    Set tBody = ..BodyFor(tTag)
    Do tBody.%Set("apiKey", ..#BODYKEY, "string")
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, tBody, .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "", "and answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.keySource, "body", "carrying the body's key")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(tTag, 1, "keySha"), ##class(OcuPilot.Test.TurnProvider).Sha(..#BODYKEY), "the key header the child's call carried hashes to the body's key")
}

/// <p>A child the request gave up on answers late, into the next test's wait in the same process:
/// that answer is discarded, and the next test reads its own.</p>
/// <p>Mutation: drop the nonce comparison from
/// <method>OcuPilot.Kernel.Provider.TestCall.Await</method> -- red, the second test reading the
/// first one's reply.</p>
Method TestALateAnswerNeverReachesTheNextTest()
{
    Do $ClassMethod(..#PROBE, "SetBound", 1)
    Do ##class(OcuPilot.Test.TurnProvider).Script("acb-stale-a", 2, ##class(OcuPilot.Test.TurnProvider).TextReply("reply-a"))
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor("acb-stale-a"), .tFirst, .tFirstStatus, .tFirstFault, .tElapsed), "the first test runs")
    Do $$$AssertEquals(..FaultAt(tFirstFault, "code"), "PROVIDER.TESTTIMEOUT", "and times out")

    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do ##class(OcuPilot.Test.TurnProvider).Script("acb-stale-b", 3, ##class(OcuPilot.Test.TurnProvider).TextReply("reply-b"))
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor("acb-stale-b"), .tSecond, .tSecondStatus, .tSecondFault, .tElapsed), "the second test runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded("acb-stale-a", 1, "returned") '= "", 1, "the first child answered while the second test waited")
    Do $$$AssertEquals(..FaultAt(tSecondFault, "code"), "", "the second test answers")
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertEquals(tSecond.reply, "reply-b", "with its own reply, not the first one's")
}

/// <p>A test that timed out is followed by one that answers: that one verifies the definition.</p>
/// <p>Mutation: skip the verification write in
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> -- red on the flags.</p>
Method TestALaterPassingTestVerifies()
{
    Set tTag = "acb-later"
    Do $ClassMethod(..#PROBE, "SetBound", 1)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 3, ##class(OcuPilot.Test.TurnProvider).TextReply("slow"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("fast"))
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tFirst, .tFirstStatus, .tFirstFault, .tElapsed), "the first test runs")
    Do $$$AssertEquals(..FaultAt(tFirstFault, "code"), "PROVIDER.TESTTIMEOUT", "and times out")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(..PreparedDefinitionId), "0|0", "leaving the definition unverified")

    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tSecond, .tSecondStatus, .tSecondFault, .tElapsed), "the next test runs")
    Do $$$AssertEquals(..FaultAt(tSecondFault, "code"), "", "and answers")
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertEquals(tSecond.reply, "fast", "from its own call")
    Do $$$AssertEquals(tSecond.connectionVerified, 1, "reading verified")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(..PreparedDefinitionId), "0|1", "and the stored row is verified, so it can be enabled")
}

/// <p>A spawn that is not accepted answers 502 <code>PROVIDER.TRANSPORT</code> at once, with no
/// provider call made and nothing timed out. What <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>
/// handed the spawn for the child's <code>JOB</code> -- here with a key in the request body -- holds
/// the test's budget and where the key comes from, and neither the key nor the body.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Call</method> carry on when
/// <method>OcuPilot.Kernel.Provider.TestCall.Spawn</method> answers 0 -- red, the call waiting out its
/// bound and answering the test timeout instead. Mutation: have
/// <method>OcuPilot.Kernel.Provider.TestCall.ValuesJson</method> write <code>keyBody</code> as its
/// JSON -- red on the key.</p>
Method TestASpawnThatFailsIsATransportFault()
{
    Set tTag = "acb-unspawned"
    Do $ClassMethod(..#PROBE, "SetBound", 3)
    Do $ClassMethod(..#PROBE, "SetCall", "OcuPilot.Test.AgentConnectionUnspawned")
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("never"))
    Set tBody = ..BodyFor(tTag)
    Do tBody.%Set("apiKey", ..#BODYKEY, "string")
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, tBody, .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "PROVIDER.TRANSPORT", "a spawn that is not accepted is a transport fault")
    Do $$$AssertEquals(tHttpStatus, 502, "as 502")
    Do $$$AssertTrue('$IsObject($Get(tAnswer)), "and no answer")
    Do $$$AssertTrue(tElapsed < 2, "answered at once, not at the bound: " _ tElapsed)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(tTag), 0, "no provider call was made")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(..PreparedDefinitionId), "0|0", "and nothing was verified")

    Set tHanded = ##class(OcuPilot.Test.AgentConnectionUnspawned).Handed("values")
    Do $$$AssertTrue(tHanded '= "", "the spawn was handed the call's values")
    If tHanded = "" Quit
    Do $$$AssertEquals(tHanded [ ..#BODYKEY, 0, "the child's JOB argument holds no key: " _ tHanded)
    Do $$$AssertEquals(tHanded [ "keyBody", 0, "and no request body")
    Set tValues = ##class(%DynamicObject).%FromJSON(tHanded)
    Do $$$AssertEquals(tValues.keySource, "body", "while it says where the key comes from")
    Do $$$AssertEquals(tValues.maxTokens, ##class(OcuPilot.Api.Definitions).#TESTMAXTOKENS, "and carries the test's token cap")
    Do $$$AssertEquals(tValues.maxAttempts, 1, "and its single attempt")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnectionUnspawned).Handed("needsKey"), 1, "the key is due by message")
}

/// <p>A test of values the row does not hold -- here a key the body carries -- that waits its
/// bound is recorded as a security change naming the key it carried and the timeout code, as any
/// other faulted test of unstored values is.</p>
/// <p>Mutation: have <method>OcuPilot.Api.Definitions.ConnectionOutcome</method> map the timeout
/// after the fault branch has recorded -- red, the record naming no code.</p>
Method TestAnUnansweredTestOfUnstoredValuesIsRecorded()
{
    Set tTag = "acb-unstored"
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $ClassMethod(..#PROBE, "SetBound", 2)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 4, ##class(OcuPilot.Test.TurnProvider).TextReply("late"))
    Set tBody = ..BodyFor(tTag)
    Do tBody.%Set("apiKey", ..#BODYKEY, "string")
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, tBody, .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "PROVIDER.TESTTIMEOUT", "and waits its bound")
    Do $$$AssertEquals(..FaultAt(tFault, "testedAsStored"), 0, "on values the row does not hold")
    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, ..PreparedDefinitionId, "test", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the test: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ """effects"":{""keySource"":""body"",""faultCode"":""PROVIDER.TESTTIMEOUT""}", "naming the key it carried and the timeout code: " _ tData)
    Do $$$AssertEquals(tData [ ..#BODYKEY, 0, "and not the key itself")
    Do $$$AssertTrue(..AwaitReturned(tTag, 15), "the child's call returned before teardown")
}

/// <p>The bound the shipped handler computes follows the gateway read through the call class it
/// uses: a read of 20 bounds at 10 and a read of 300 at 290, and on this instance the shipped read
/// answers the value the installer reads, from a named source.</p>
/// <p>Mutation: have <method>OcuPilot.Api.Definitions.TestBoundSeconds</method> answer
/// <code>BoundSeconds("")</code> -- red on 10 and 290.</p>
Method TestTheShippedBoundFollowsTheGatewayRead()
{
    Do $ClassMethod(..#PROBE, "SetBound", "")
    Do $ClassMethod(..#PROBE, "SetCall", "OcuPilot.Test.AgentConnectionInline")
    Do ##class(OcuPilot.Test.AgentConnectionInline).SetGateway(20)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "TestBoundSeconds"), 10, "a gateway read of 20 bounds the handler's test at 10")
    Do ##class(OcuPilot.Test.AgentConnectionInline).SetGateway(300)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "TestBoundSeconds"), 290, "and raising it to 300 raises the bound to 290")
    Do ##class(OcuPilot.Test.AgentConnectionInline).Forget()

    Do ##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tTimeout, .tSource)
    Set tSeconds = ##class(OcuPilot.Kernel.Provider.TestCall).GatewaySeconds(.tShippedSource)
    Do $$$AssertEquals(tSeconds, tTimeout, "the shipped read answers what the installer reads (" _ tSource _ ")")
    Do $$$AssertTrue((tShippedSource '= "unread") && (tShippedSource = tSource), "from the source it names: " _ tShippedSource)
    Do $$$AssertEquals(##class(OcuPilot.Api.Definitions).TestBoundSeconds(), ##class(OcuPilot.Kernel.Provider.TestCall).BoundSeconds(tTimeout), "and the shipped handler bounds its test from it")
}

/// <p>The child makes the request Test connection asks for, as its caller: one message, the
/// test prompt, no tools and no system prompt, under the caller's user and roles.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Child</method> add a role before
/// its call -- red on the roles.</p>
Method TestTheChildSendsTheTestRequestAsItsCaller()
{
    Set tTag = "acb-shape"
    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("shape"))
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "", "and answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(tTag), 1, "with one provider call")
    Set tMessages = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(tTag, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 1, "carrying one message: " _ tMessages.%ToJSON())
    Do $$$AssertTrue(tMessages.%ToJSON() [ ##class(OcuPilot.Api.Definitions).#TESTPROMPT, "the test prompt: " _ tMessages.%ToJSON())
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(tTag, 1, "tools"), "", "no tools")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(tTag, 1, "systemPresent"), 0, "and no system prompt")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(tTag, 1, "user"), $Username, "made as the caller's user")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(tTag, 1, "roles"), $Roles, "with the caller's roles and no more")
}

/// <p>The child makes one attempt: a provider that answers 429 is asked once.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Child</method> drop
/// <code>maxAttempts</code> from the values it rebuilds -- red, the instance's retries asking
/// again.</p>
Method TestTheChildMakesOneAttempt()
{
    Set tTag = "acb-limited"
    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 0, "{""type"":""error"",""error"":{""type"":""rate_limit_error"",""message"":""slow down""}}", 429, "1")
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertTrue($IsObject($Get(tFault)), "and faults")
    Do $$$AssertTrue(..AwaitReturned(tTag, 15), "the child's calls returned")
    Hang 1.5
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(tTag), 1, "after exactly one provider call")
}

/// <p>The child's answer carries the reply past what Test connection shows and the call's latency,
/// so the answer still says the reply was cut and how long the provider took.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Child</method> cut the text at
/// <parameter>OcuPilot.Api.Definitions.TESTREPLYMAX</parameter> and drop <code>latencyMs</code> --
/// red on <code>replyTruncated</code> and on the latency.</p>
Method TestTheChildCarriesTheLongReplyAndItsLatency()
{
    Set tTag = "acb-long"
    Set tMax = ##class(OcuPilot.Api.Definitions).#TESTREPLYMAX
    Set tLong = $Translate($Justify("", tMax * 2), " ", "x")
    Do $ClassMethod(..#PROBE, "SetBound", 10)
    Do ##class(OcuPilot.Test.TurnProvider).Script(tTag, 1, ##class(OcuPilot.Test.TurnProvider).TextReply(tLong))
    Do $$$AssertStatusOK(..Outcome(..PreparedDefinitionId, ..BodyFor(tTag), .tAnswer, .tHttpStatus, .tFault, .tElapsed), "the test runs")
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "", "and answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals($Length(tAnswer.reply), tMax, "the reply is cut to the declared bound: " _ $Length(tAnswer.reply))
    Do $$$AssertEquals(tAnswer.replyTruncated, 1, "and the answer says it was cut")
    Do $$$AssertTrue(tAnswer.latencyMs >= 1000, "the latency is the child's call, the provider's second included: " _ tAnswer.latencyMs)
}

/// <p>A child that fails signals it, and the request answers 502 <code>PROVIDER.TRANSPORT</code> at
/// once rather than waiting its bound and blaming the provider.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.Provider.TestCall.Child</method>'s <code>Catch</code>
/// signal nothing -- red, the call waiting out its bound as a timeout.</p>
Method TestAChildThatFailsIsATransportFault()
{
    Kill tValues, tMessages
    Set tBegan = $ZHorolog
    Do ##class(OcuPilot.Kernel.Provider.TestCall).Call("OcuPilot.Test.AgentConnectionNoSuchPort", .tValues, .tMessages, 5, .tResponse, .tHttpStatus, .tFault, .tWaited, .tTimedOut)
    Set tElapsed = $ZHorolog - tBegan
    Do $$$AssertEquals(..FaultAt(tFault, "code"), "PROVIDER.TRANSPORT", "a child whose call throws is a transport fault")
    Do $$$AssertEquals(tHttpStatus, 502, "as 502")
    Do $$$AssertEquals(tTimedOut, 0, "not a timeout")
    Do $$$AssertTrue(tElapsed < 3, "answered once the child failed, not at the bound: " _ tElapsed)
}

}

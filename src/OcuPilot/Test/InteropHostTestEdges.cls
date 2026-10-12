/// <p>Pins the edges of Story 20.6's host test that <class>OcuPilot.Test.InteropHostTest</class> and
/// <class>OcuPilot.Test.InteropHostTestRefusals</class> leave open (AD-6, AD-15, AD-35, AD-39, AD-62): an item of a production that is
/// not the running one is refused as not running, though the running production holds an item of the same name, so a test is never
/// sent to the wrong production's host; a test that is still waiting leaves the vendor's answer node and is audited without an answer;
/// a failed test is audited without the error's text; the agent's confirmed send answers the session its messages are listed under in
/// the item's Messages tab; and a value the agent sent for a credential-named field, or for a member under a credential-named
/// object, is redacted from the ledger row and the step of the call that was refused.</p>
/// <p>It borrows the helpers of <class>OcuPilot.Test.InteropHostTest</class>. <b>What it needs from the environment:</b> the same as
/// that class, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and <b>runs a probe production
/// in <code>USER</code></b> and removes everything it made after the last test. One class per run.</p>
Class OcuPilot.Test.InteropHostTestEdges Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter HOST = "OcuPilot.Test.InteropHostTest";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter FIXTURE = "OcuPilot.Test.InteropTestFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemTestSend";

Parameter LEDGER = "OcuPilot.Test.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter SCREEN = "/screens/interop.itemtest";

/// <p>The route the agent's calls are made from.</p>
Parameter ROUTE = "interoperability/productions/items/test";

Parameter NAMESPACE = "USER";

/// <p>A value the agent sends for a credential-named member, and a value it sends beside ordinary ones.</p>
Parameter SENT = "ocu-sent-secret-206c";

Parameter SHOWN = "ocu-shown-text-206c";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostTestEdges compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring up a throwaway container with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Create")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    Set tRemove = $ClassMethod(..#FIXTURE, "Remove")
    If $$$ISOK(tSC) Set tSC = tRemove
    Set tProbe = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = tProbe
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostTestEdges left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ..Reset()
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

/// <p>Nothing armed, no marker, and testing enabled in the stored production, whatever the last test did.</p>
ClassMethod Reset()
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#FIXTURE, "ClearMarker")
    Do $ClassMethod(..#FIXTURE, "EnableTesting", 1)
}

/// <p>The saved requests, the message headers and the request class's creation marker, as one text.</p>
ClassMethod Footprint() As %String
{
    Quit $ClassMethod(..#FIXTURE, "Counts") _ "/" _ $ClassMethod(..#FIXTURE, "Marker")
}

/// <p>What the vendor keeps for the test session <var>pSession</var> of the testing service in <code>USER</code>: the top node, which
/// reads <code>Waiting</code>, <code>Done</code> or <code>Error</code>, and <code>""</code> when there is none.</p>
ClassMethod NodeState(pSession As %String) As %String
{
    Quit $Get(^IRIS.Temp.EnsRuntimeAppData(..#NAMESPACE, $Parameter(..#FIXTURE, "TESTSERVICE"), pSession))
}

/// <p>A person's Test action on the item <var>pName</var> of the production <var>pProduction</var>, as <code>status code</code>,
/// the answer in <var>pAnswer</var>.</p>
ClassMethod SendTo(pProduction As %String, pName As %String, pClass As %String, pFields As %DynamicObject, Output pAnswer) As %String
{
    Set tBody = {"action": "test", "values": {}}
    Do tBody.%Set("id", pProduction _ $Char(1) _ pName, "string")
    Do tBody.values.%Set("requestClass", pClass, "string")
    Do tBody.values.%Set("fields", pFields.%ToJSON(), "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>AC3: the Test of an item of a production that is not the one running is refused 409 <code>INTEROP.PRODUCTION.NOTRUNNING</code>
/// from the person's action and the agent's mint, though the running production holds an item of the same name, which would
/// otherwise take the request; nothing is saved, created or sent, and the running production's own item of that name is still tested.</p>
/// <p>Mutation (Rule 19): make the running test in <method>OcuPilot.Port.InteropPort.ReadTestTarget</method> ask whether any
/// production runs instead of whether this one does -- the request reaches the running production's operation and this goes red.</p>
Method TestAnItemOfAProductionThatIsNotTheRunningOneIsRefusedAsNotRunning()
{
    Set tOther = $Parameter(..#PROBE, "OTHER")
    Set tName = $Parameter(..#HOST, "PLAINNAME")
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Set tBefore = ..Footprint()
    Set tText = ..SendTo(tOther, tName, "Ens.Request", {}, .tAnswer)
    Do $$$AssertEquals(tText, "409 " _ ##class(OcuPilot.Api.InteropError).#NOTRUNNING, "the person's Test is refused as not running: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tArgs = $ClassMethod(..#HOST, "ArgsFor", tName, "Ens.Request", {})
    Do tArgs.%Set("Production", tOther, "string")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#NOTRUNNING, "so is the agent's mint")
    Do $$$AssertTrue('$IsObject($Get(tProposal)), "and it mints nothing")
    Do $$$AssertEquals(..Footprint(), tBefore, "no request was saved, no header added, no request created")
    Set tText = $ClassMethod(..#HOST, "Send", tName, "Ens.Request", {}, .tOwn)
    Do $$$AssertEquals(tText, "200 ", "while the running production's own item of that name is tested: " _ $Select($IsObject(tOwn): tOwn.%ToJSON(), 1: ""))
}

/// <p>AC4: a test that is still waiting after the wait answers <code>waiting</code> and leaves the vendor's answer node for the
/// vendor's own cleanup (the node still reads <code>Waiting</code> while the target hangs), and OcuPilot records the test with the
/// status and the session and no answer.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AwaitTestHere</method> kill the node of a session that is still
/// waiting -- the node leg goes red.</p>
Method TestAWaitingTestLeavesTheAnswerNodeAndIsAudited()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetHang", 5), "the plain operation hangs five seconds on a message")
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Do $ClassMethod(..#HOST, "HoldPairs")
    Do $ClassMethod(..#SEAM, "ShortenTestWait", 1)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $ClassMethod(..#HOST, "ItemId", $Parameter(..#HOST, "PLAINNAME"))
    Set tQuery("requestClass") = "Ens.Request"
    Set tQuery("fields") = "{}"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "ItemTest", "SENDTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the send answers: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.status, "waiting", "it answers waiting")
    Set tSession = tResult.sessionId
    Do $$$AssertEquals(..NodeState(tSession), "Waiting", "and the vendor's answer node for session " _ tSession _ " is left, still waiting")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """sessionId"":""" _ tSession _ """"), 1, "one audit row records the test")
    Do $$$AssertTrue((tData [ """status"":""waiting""") && (tData '[ """lines"""), "with its status and no answer: " _ tData)
}

/// <p>AC2, AC8: a target that fails the request is audited with the status <code>error</code> and the session, and the error's text,
/// which the person is shown, is in no audit row.</p>
/// <p>Mutation (Rule 19): add the error's text to the audit effects in <method>OcuPilot.Port.InteropPort.PerformTest</method> -- this
/// goes red.</p>
Method TestAFailedTestIsAuditedWithoutTheErrorsText()
{
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = $ClassMethod(..#HOST, "Send", $Parameter(..#FIXTURE, "ECHONAME"), $Parameter(..#FIXTURE, "REQUESTCLASS"), {"Text": "fail"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    If '$IsObject(tOutput) Quit
    Do $$$AssertTrue(tOutput.lines.%Get(0) [ "echo failed", "the person is shown the error's text")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """sessionId"":""" _ tOutput.sessionId _ """"), 1, "one audit row records the test")
    Do $$$AssertTrue((tData [ """status"":""error""") && (tData '[ "echo failed") && (tData '[ """lines"""), "with its status and not the error's text: " _ tData)
}

/// <p>AC2: the agent's send, confirmed over HTTP, answers the session id the testing service gave it, and the item's Messages tab lists
/// messages under that session, as it does for the person's send, so the card's session id leads to the test's trace.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Port.InteropPort.PerformTest</method> answer a session id other than the one it sent
/// under -- the Messages leg goes red.</p>
Method TestTheAgentsSessionLeadsToTheItemsMessages()
{
    Set tName = $Parameter(..#FIXTURE, "ECHONAME")
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, $ClassMethod(..#HOST, "ArgsFor", tName, $Parameter(..#FIXTURE, "REQUESTCLASS"), {"Text": "agent session"}), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tMintHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the call mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tRaw), 1, 300))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    If '$IsObject($Get(tAnswer)) || '$IsObject(tAnswer.%Get("output")) Quit
    Set tSession = tAnswer.output.sessionId
    Do $$$AssertTrue(tSession > 0, "the output names a session: " _ tSession)
    Kill tQuery
    Set tQuery("item") = $ClassMethod(..#HOST, "ItemId", tName)
    Set tMessages = $ClassMethod(..#READ, "Rows", "ItemMessages", .tQuery, .tHttp, .tReadFault)
    Do $$$AssertEquals(tHttp, 200, "the item's Messages tab answers")
    Do $$$AssertTrue($ClassMethod(..#READ, "CountWhere", tMessages, "SessionId", tSession) > 0, "and lists messages of session " _ tSession)
}

/// <p>The send call the agent makes for the echo item, as a model's tool-use block, with request class <var>pRequestClass</var> and
/// the fields <var>pFields</var>.</p>
ClassMethod Use(pRequestClass As %String, pFields As %DynamicObject) As %DynamicObject
{
    Set tInput = $ClassMethod(..#HOST, "ArgsFor", $Parameter(..#FIXTURE, "ECHONAME"), pRequestClass, pFields)
    Do tInput.%Set("rationale", "probe", "string")
    Do tInput.%Set("expectedImpact", "probe", "string")
    Set tUse = {"id": "toolu_hosttest"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("interop.itemtest.send"), "string")
    Do tUse.%Set("input", tInput)
    Quit tUse
}

/// <p>AD-35: dispatched through the agent's tool loop, a call whose fields name a credential, or a member under a credential-named
/// object, is refused, and neither its ledger row nor its step carries the value the agent sent, which reads as the redaction mark
/// while the item's name is kept; the fields of a refused call that names no credential are kept in both, so the redaction is the
/// credential's doing and not every call's. The member under a credential-named object is one the name pattern alone does not
/// see, so it is the tool's own declaration that redacts it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropItemTestSend.CallSecretNames</method> test the last segment of a
/// member's path alone -- the <code>Credential.Value</code> row goes red; make it answer none -- that row and its step go red.</p>
Method TestAValueTheAgentSentForACredentialIsRedactedInTheLedgerRowAndTheStep()
{
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tClass = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tBefore = ..Footprint()
    For tCase = $ListBuild(tClass, "{""Text"":""x"",""Password"":""" _ ..#SENT _ """}", 1, "a credential-named field"), $ListBuild(tClass, "{""Text"":""x"",""Credential.Value"":""" _ ..#SENT _ """}", 1, "a member under a credential-named object"), $ListBuild("Ens.Request", "{""Text"":""" _ ..#SHOWN _ """}", 0, "ordinary fields") {
        Set tLabel = $List(tCase, 4)
        Set tTurn = $ClassMethod(..#LEDGER, "NewTurnKey")
        Set tUses = []
        Do tUses.%Push(..Use($List(tCase, 1), ##class(%DynamicObject).%FromJSON($List(tCase, 2))))
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, ..#ROUTE)
        Do $$$AssertStatusOK(tSC, tLabel _ ": the dispatcher answers the call")
        Do $$$AssertEquals(tResults.%Size() _ "|" _ tResults.%Get(0).%Get("is_error"), "1|1", tLabel _ ": the call is refused: " _ tResults.%ToJSON())
        Set tText = $ClassMethod(..#LEDGER, "RowText", tTurn)
        Set tStepArgs = $Select(tDetails.%Size() = 1: tDetails.%Get(0).arguments, 1: "")
        Do $$$AssertTrue(tText '= "", tLabel _ ": the row was stored: " _ tText)
        If $List(tCase, 3) {
            Do $$$AssertEquals(tText [ ..#SENT, 0, tLabel _ ": no column of the ledger row carries the value sent: " _ tText)
            Do $$$AssertEquals(tStepArgs [ ..#SENT, 0, tLabel _ ": and the step's arguments do not: " _ tStepArgs)
            Do $$$AssertTrue((tText [ "[redacted]") && (tStepArgs [ "[redacted]"), tLabel _ ": the value reads as redacted in both")
            Do $$$AssertTrue((tText [ $Parameter(..#FIXTURE, "ECHONAME")) && (tStepArgs [ $Parameter(..#FIXTURE, "ECHONAME")), tLabel _ ": while the item's name is kept")
        } Else {
            Do $$$AssertTrue((tText [ ..#SHOWN) && (tStepArgs [ ..#SHOWN), tLabel _ ": a refused call that names no credential keeps its fields in the row and the step")
        }
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals(..Footprint(), tBefore, "no refused call saved a request, added a message or created one")
}

}

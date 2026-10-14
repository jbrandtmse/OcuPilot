/// <p>Pins Story 20.23's queue actions end to end against a probe production in <code>USER</code> (AD-6, AD-10, AD-14, AD-15, AD-34,
/// AD-48, AD-51, AD-53, AD-58, AD-59, AD-62): on a production whose operation is hung on one message with two more waiting, the
/// agent's abort of one message minted and confirmed over HTTP, the person's abort of one from Queue messages and, for an item's
/// Queue tab row, through that same route, an abort of a message to a business process of pool size 0 in the shared
/// <code>Ens.Actor</code> queue, an abort of a whole queue that aborts exactly the entries its read enumerated and leaves the message
/// a job is working on, the stale digest and the message sent after the review that each abort nothing, and the refusals of an empty
/// queue and of targets that are gone. Each write leaves one OcuPilot audit row naming the action, the target and the namespace and
/// no message content, and the copy-out script of each is rendered.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), hangs its operation for ten minutes and removes everything it
/// made after the last test. One class per run.</p>
Class OcuPilot.Test.InteropQueueActions Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

/// <p>Story 20.3's control test, whose HTTP and mint helpers this class shares.</p>
Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

/// <p>Story 20.4's read test, whose arming of the probe (an operation hung on one message and two more waiting) this class shares.</p>
Parameter READ = "OcuPilot.Test.InteropHostRead";

/// <p>Story 20.4's edge test, whose queued entries for a business process of pool size 0 this class shares.</p>
Parameter EDGES = "OcuPilot.Test.InteropHostEdges";

Parameter NAMESPACE = "USER";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter SVCNAME = "OcuPilotProbeSvc";

Parameter PROCA = "OcuPilotProbeProcA";

Parameter PROCB = "OcuPilotProbeProcB";

Parameter PROCCLASS = "EnsLib.MsgRouter.RoutingEngine";

Parameter ACTOR = "Ens.Actor";

Parameter MESSAGETOOL = "OcuPilot.Screen.Tool.InteropQueueMessageAbort";

Parameter QUEUETOOL = "OcuPilot.Screen.Tool.InteropQueueAbort";

Parameter MESSAGESCREEN = "/screens/interop.queuemessages";

Parameter QUEUESCREEN = "/screens/interop.queues";

/// <p>The message status the vendor stores for an aborted message.</p>
Parameter ABORTED = 7;

/// <p>The three message ids the probe was sent, oldest first, comma-separated: the first is the one the hung operation holds.</p>
Property PreparedIds As %String;

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedIds = ""
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropQueueActions compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, its messages and its proposals; a failing status when any of it survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropQueueActions left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

/// <p>The governance policy is put back, the proposals removed and the probe stopped, whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Set ..PreparedIds = ""
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

/// <p>Bring the probe to the state every test but the actor-queue one assumes: its operation hung on the first of three messages and
/// the other two waiting in its queue (<method>OcuPilot.Test.InteropHostRead.ArmProbe</method>).</p>
Method Arm() As %Status
{
    Set ..PreparedIds = ""
    Set tSC = $ClassMethod(..#READ, "ArmProbe", .tIds)
    If $$$ISOK(tSC) Set ..PreparedIds = tIds
    Quit tSC
}

/// <p>Turn the governance key <var>pKey</var> on for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method EnableKey(pKey As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is turned on")
}

/// <p>The entries waiting in the queue <var>pQueue</var> in <code>USER</code>, <code>priority:index:id</code>, comma-separated in queue
/// order; <var>pOnly</var> as <code>id</code>s alone when 1.</p>
ClassMethod Entries(pQueue As %String, pOnly As %Boolean = 0) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%ResultSet).%New("Ens.Queue:EnumerateItem")
        Do tResult.Execute(pQueue)
        While tResult.Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $Select(pOnly: tResult.GetData(3), 1: tResult.GetData(1) _ ":" _ tResult.GetData(2) _ ":" _ tResult.GetData(3))
        }
        Do tResult.Close()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tText = "unread " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The stored status of message header <var>pId</var> in <code>USER</code>, <code>""</code> when there is none.</p>
ClassMethod HeaderStatus(pId As %String) As %String
{
    Set tStatus = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT Status FROM Ens.MessageHeader WHERE ID = ?", pId)
        If tResult.%Next() Set tStatus = tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tStatus
}

/// <p>How many OcuPilot <code>ConfigChange</code> audit rows since <var>pSince</var> name the entity <var>pType</var> with id
/// <var>pId</var> and the verb <var>pVerb</var>; the last such row's data in <var>pData</var>.</p>
ClassMethod AuditRows(pSince As %String, pType As %String, pId As %String, pVerb As %String, Output pData As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", """type"":""" _ pType _ """,""scope"":""instance"",""id"":""" _ pId _ """", .pData, """verb"":""" _ pVerb _ """")
}

/// <p>A write by the port itself through <class>OcuPilot.Test.InteropItemSeam</class>, as the running account: the HTTP status and the
/// wire fault's code, <code>"200 "</code> for an answer; the answer in <var>pResult</var>.</p>
ClassMethod Port(pEndpoint As %String, pType As %String, pId As %String, Output pResult, pDigest As %String = "", pHasDigest As %Boolean = 0) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pHasDigest Set tQuery("digest") = pDigest
    Set pResult = ""
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, pType, .tQuery, "", .pResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>The agent's mint of <var>pTool</var> for <var>pArgs</var> as the HTTP account, then its confirm over HTTP: the card's one row
/// (<var>pRow</var>, as JSON), the consequence code and destructiveness, the single envelope the confirm answers, its change action,
/// marker and read-back, and its ledger row. The confirm's answer is in <var>pAnswer</var> and the turn in <var>pTurn</var>.</p>
Method Through(pTool As %String, pArgs As %DynamicObject, pRow As %String, pConsequence As %String, pTargetType As %String, pTargetId As %String, Output pAnswer, Output pTurn As %String)
{
    Set tName = $Parameter(pTool, "TOOLNAME")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), pRow, tName _ ": its card shows one row, from " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, pTargetType _ "|USER|" _ pTargetId, tName _ ": the target")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), pConsequence _ "|1", tName _ ": its consequence code, and it is destructive")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .pAnswer)
    Do $$$AssertEquals(tStatus, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(pAnswer) && ($Length(tRaw, "}{") = 1), tName _ ": the confirm answers exactly one envelope")
    If '$IsObject(pAnswer) Quit
    Do $$$AssertEquals(pAnswer.%Get("auditMarked") _ "|" _ pAnswer.action _ "|" _ pAnswer.readBack.verdict, "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, tName _ ": updated, marked (AD-15), and the read-back sent nothing")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", pTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
}

/// <p>AC1, AC5: the agent's abort of one waiting message, minted and confirmed over HTTP while its governance key is on, takes that
/// entry off the queue and marks its header Aborted; the queue's other waiting message and the message the operation holds stay;
/// the card shows the message's status moving from Queued to Aborted and is destructive; and the write leaves one OcuPilot audit row
/// naming the abort, the message and the namespace, and no message content.</p>
/// <p>Mutation (Rule 19): skip <code>AbortItem</code> in <method>OcuPilot.Port.InteropPort.PerformAbortMessage</method> -- the entry,
/// header and audit legs go red.</p>
Method TestTheAgentsAbortOfOneMessageTakesItOffTheQueue()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tHeld = $Piece(..PreparedIds, ",", 1)
    Set tFirst = $Piece(..PreparedIds, ",", 2)
    Set tSecond = $Piece(..PreparedIds, ",", 3)
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), tFirst _ "," _ tSecond, "the two waiting messages are queued")
    Do ..EnableKey("interop.queuemessages.abort")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Through(..#MESSAGETOOL, {"MessageId": (tFirst)}, "[{""field"":""Status"",""before"":""Queued"",""after"":""Aborted""}]", "INTEROP.MESSAGE.ABORT", "interop-message", tFirst, .tAnswer, .tTurn)
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), tSecond, "the aborted entry left the queue and the other stays")
    Do $$$AssertEquals(..HeaderStatus(tFirst) _ "|" _ (..HeaderStatus(tSecond) '= ..#ABORTED) _ "|" _ (..HeaderStatus(tHeld) '= ..#ABORTED), ..#ABORTED _ "|1|1", "its header reads Aborted, and the waiting and the held messages do not")
    Set tRows = ..AuditRows(tSince, "interop-message", tFirst, "abort", .tData)
    Do $$$AssertEquals(tRows, 1, "one OcuPilot audit row names the abort of the message")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData '[ ..#SVCNAME) && (tData '[ "Ens.Request"), "naming the namespace and carrying no message content: " _ tData)
    Do $$$AssertEquals(..AuditRows(tSince, "interop-message", tSecond, "abort", .tOther), 0, "and none names a message left on the queue")
}

/// <p>AC1: the person's Abort on Queue messages, and on the Queue tab of the item whose queue it is, which posts to the same route, answers
/// 200 with the <code>updated</code> event for the message, a read-back that sent nothing and no body, and aborts the entry; each
/// leaves one audit row, and no OcuPilot marker is emitted for a person (AD-53). Governance does not gate a person's own action.</p>
/// <p>Mutation (Rule 19): drop <code>AuditRuntime</code> from <method>OcuPilot.Port.InteropPort.PerformAbortMessage</method> -- the audit
/// legs go red.</p>
Method TestThePersonsAbortFromQueueMessagesAndFromTheItemsQueueTab()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tFirst = $Piece(..PreparedIds, ",", 2)
    Set tSecond = $Piece(..PreparedIds, ",", 3)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBody = {"action": "abort"}
    Do tBody.%Set("id", tFirst, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#MESSAGESCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Abort on Queue messages answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, "updated|interop-message|USER|" _ tFirst _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "publishing the updated event for the message")
    }
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), tSecond, "the entry left the queue and the other stays")
    Do $$$AssertEquals(..HeaderStatus(tFirst), ..#ABORTED, "its header reads Aborted")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-message", tFirst, "abort", .tData), 1, "one audit row names the abort")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tFirst, .tMarker), 0, "and no agent marker is emitted for a person's action")

    ; The Queue tab of the item lists the remaining message, and its Abort posts to the same route.
    Set tRows = $ClassMethod(..#READ, "ProbeRows", "ItemQueue", .tHttp, .tFault)
    Set tListed = ""
    If $IsObject(tRows) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tListed = tListed _ $Select(tListed = "": "", 1: ",") _ tRow.MessageId
        }
    }
    Do $$$AssertEquals(tListed, tSecond, "the item's Queue tab lists the message that is left")
    Set tBody = {"action": "abort"}
    Do tBody.%Set("id", tSecond, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#MESSAGESCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the Queue tab's row posted to the same route answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..Entries(..#OPNAME, 1) _ "|" _ ..HeaderStatus(tSecond), "|" _ ..#ABORTED, "the queue is empty and the header reads Aborted")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-message", tSecond, "abort", .tData), 1, "one audit row names the second abort")
}

/// <p>AC1: a message to a business process of pool size 0 waits in the shared <code>Ens.Actor</code> queue, and the abort finds it there
/// through its header's own <code>TargetQueueName</code>: the read names <code>Ens.Actor</code>, the abort takes that entry and no other,
/// and the other process's entry stays. With the production Troubled, so no actor job takes an entry.</p>
/// <p>Mutation (Rule 19): make the <code>ENTRY</code> read scan the queue of the message's target item instead of its header's
/// <code>TargetQueueName</code> -- this goes red.</p>
Method TestAnAbortFindsAMessageToAPoolSizeZeroProcessInTheActorQueue()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "and put back as declared")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTroubled"), "then left Troubled, where no job takes an actor entry")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#PROCA, ..#PROCCLASS, 0, 0), "a business process of pool size 0 is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#PROCB, ..#PROCCLASS, 0, 0), "and a second")
    Set tA = $ClassMethod(..#EDGES, "QueueEntry", ..#PROCA)
    Set tB = $ClassMethod(..#EDGES, "QueueEntry", ..#PROCB)
    Try {
        Do $$$AssertTrue((tA > 0) && (tB > 0), "two entries are queued in the shared queue")
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tCode = ..Port("QueueItems", "ENTRY", tA, .tRow)
        Do $$$AssertEquals(tCode _ "|" _ $Select($IsObject(tRow): tRow.Queue _ "|" _ tRow.Target _ "|" _ tRow.Status, 1: ""), "200 |" _ ..#ACTOR _ "|" _ ..#PROCA _ "|Queued", "the entry read finds it in the shared queue, addressed to the process")
        Set tCode = ..Port("QueueItems", "ABORTMESSAGE", tA, .tDone)
        Do $$$AssertEquals(tCode, "200 ", "the abort is admitted: " _ $Select($IsObject(tDone): tDone.%ToJSON(), 1: ""))
        Do $$$AssertEquals(..HeaderStatus(tA) _ "|" _ (..HeaderStatus(tB) '= ..#ABORTED), ..#ABORTED _ "|1", "the first header reads Aborted and the second does not")
        Do $$$AssertEquals(..Port("QueueItems", "ENTRY", tB, .tOther), "200 ", "the other process's entry is still queued")
        Do $$$AssertEquals(..Entries(..#ACTOR, 1), tB, "the shared queue holds that one alone")
        Do $$$AssertEquals(..AuditRows(tSince, "interop-message", tA, "abort", .tData), 1, "and one audit row names the abort")
        Do $$$AssertTrue(tData [ """queue"":""Ens.Actor""", "naming the queue the message was in: " _ tData)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the actor-queue leg raised")
    }
    Do $ClassMethod(..#EDGES, "RemoveEntries", tA _ "," _ tB)
    Do $$$AssertEquals(..Entries(..#ACTOR, 1), "", "the entries and headers are removed")
}

/// <p>AC2, AC5: the agent's abort of the probe operation's queue, minted and confirmed over HTTP, aborts exactly the entries its read
/// enumerated and leaves the message the operation is working on. A message sent after the mint changes the queue, so the confirm
/// closes the proposal target-changed with nothing aborted; a fresh mint and confirm then abort all three waiting messages. One audit
/// row names the abort of the queue with its counts.</p>
/// <p>Mutation (Rule 19): none here for the loop itself; <method>TestAQueueAbortLeavesAMessageThatJoinsWhileItRuns</method> pins it.</p>
Method TestTheAgentsQueueAbortTakesExactlyTheEntriesItsReadEnumerated()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tHeld = $Piece(..PreparedIds, ",", 1)
    Do ..EnableKey("interop.queues.abort")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#QUEUETOOL, {"Name": (..#OPNAME)}, tUser, .tStale, .tHttp, .tFault, .tStaleTurn)
    Do $$$AssertStatusOK(tSC, "the abort of the queue mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tStale)) Quit
    Do $$$AssertEquals(tStale.changed.%ToJSON(), "[{""field"":""Count"",""before"":""2"",""after"":""0""}]", "its card shows the two waiting messages going")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Send"), "a message is sent after the mint")
    For tTry = 1:1:20 {
        If $Length(..Entries(..#OPNAME, 1), ",") = 3 Quit
        Hang 0.5
    }
    Do $$$AssertEquals($Length(..Entries(..#OPNAME, 1), ","), 3, "and waits in the queue beside the other two")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tStale.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 409, "the confirm is refused, the queue having changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed")
    Do $$$AssertEquals($Length(..Entries(..#OPNAME, 1), ","), 3, "and no entry was aborted")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tStaleTurn)

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tWaiting = ..Entries(..#OPNAME, 1)
    Do ..Through(..#QUEUETOOL, {"Name": (..#OPNAME)}, "[{""field"":""Count"",""before"":""3"",""after"":""0""}]", "INTEROP.QUEUE.ABORT", "interop-queue", ..#OPNAME, .tDone, .tTurn)
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), "", "the queue is empty")
    Set tAllAborted = 1
    For tI = 1:1:$Length(tWaiting, ",") {
        If ..HeaderStatus($Piece(tWaiting, ",", tI)) '= ..#ABORTED Set tAllAborted = 0
    }
    Do $$$AssertEquals(tAllAborted _ "|" _ (..HeaderStatus(tHeld) '= ..#ABORTED), "1|1", "every enumerated message reads Aborted and the message the operation holds does not")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-queue", ..#OPNAME, "abortall", .tData), 1, "one audit row names the abort of the queue")
    Do $$$AssertTrue((tData [ """aborted"":3") && (tData [ """skipped"":0") && (tData [ """namespace"":""USER""") && (tData '[ ..#SVCNAME), "with its counts and the namespace, and no message content: " _ tData)
}

/// <p>AC2: a message that joins the queue while its abort runs is not aborted: the port aborts the entries its read enumerated, one at a time,
/// so the message sent after the first of them stays queued and reads Queued, and the two enumerated entries read Aborted.</p>
/// <p>Mutation (Rule 19): call <code>Ens.Queue.AbortQueue</code> in place of the per-entry <code>AbortItem</code> loop in
/// <method>OcuPilot.Port.InteropPort.PerformAbortQueue</method> -- the loop never runs, so no message is sent after an abort and the sent
/// leg goes red.</p>
Method TestAQueueAbortLeavesAMessageThatJoinsWhileItRuns()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tWaiting = ..Entries(..#OPNAME, 1)
    Do ..HoldQueuePairs()
    Do $ClassMethod(..#SEAM, "SendAfterNextAbort")
    Set tCode = ..PortAs("Queues", "ABORTQUEUE", ..#OPNAME)
    Do $$$AssertEquals(tCode, "200 ", "the queue abort is admitted")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Sent"), 1, "a message joined the queue after the first entry was aborted")
    Set tLeft = ..Entries(..#OPNAME, 1)
    Do $$$AssertTrue((tLeft '= "") && ($Length(tLeft, ",") = 1) && '$ListFind($ListFromString(tWaiting), tLeft), "one entry is left, and it is not one the read enumerated: " _ tLeft)
    Do $$$AssertEquals(..HeaderStatus($Piece(tWaiting, ",", 1)) _ "|" _ ..HeaderStatus($Piece(tWaiting, ",", 2)), ..#ABORTED _ "|" _ ..#ABORTED, "the two enumerated messages read Aborted")
    Do $$$AssertTrue(tLeft '= "" && (..HeaderStatus(tLeft) '= ..#ABORTED), "and the message that joined does not")
}

/// <p>AC2: the person's Abort all on Queues answers 200 with the <code>updated</code> event for the queue, aborts the waiting messages
/// and leaves the held one, and leaves one audit row; a direct port call carrying a digest the queue no longer gives answers 409
/// <code>INTEROP.QUEUE.CHANGED</code> with every entry still there, and a call carrying the current digest aborts them.</p>
/// <p>Mutation (Rule 19): skip the digest comparison in <method>OcuPilot.Port.InteropPort.PerformAbortQueue</method> -- the stale-digest leg
/// goes red.</p>
Method TestAStaleDigestAbortsNothingAndThePersonsAbortAllTakesTheWaitingMessages()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tHeld = $Piece(..PreparedIds, ",", 1)
    Set tWaiting = ..Entries(..#OPNAME, 1)
    Set tCode = ..Port("Queues", "QUEUE", ..#OPNAME, .tRead)
    Do $$$AssertEquals(tCode, "200 ", "the queue reads")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.Entries _ "|" _ tRead.Count _ "|" _ $Length(tRead.Digest), "2|2|64", "two entries, and a SHA-256 digest of them")
    Set tCode = ..Port("Queues", "ABORTQUEUE", ..#OPNAME, .tResult, "0000", 1)
    Do $$$AssertEquals(tCode, "409 INTEROP.QUEUE.CHANGED", "a digest the entries do not give is refused")
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), tWaiting, "and every entry is still there")
    Set tCode = ..Port("Queues", "ABORTQUEUE", ..#OPNAME, .tCurrent, tRead.Digest, 1)
    Do $$$AssertEquals(tCode, "200 ", "a call carrying the digest the queue gives aborts: " _ $Select($IsObject(tCurrent): tCurrent.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tCurrent): tCurrent.Aborted _ "|" _ tCurrent.Skipped _ "|" _ tCurrent.Count, 1: ""), "2|0|2", "two aborted, none skipped")
    Do $$$AssertStatusOK(..Arm(), "the probe is armed again")
    Set tHeld = $Piece(..PreparedIds, ",", 1)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBody = {"action": "abort"}
    Do tBody.%Set("id", ..#OPNAME, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#QUEUESCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Abort all on Queues answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, "updated|interop-queue|" _ ..#OPNAME _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "publishing the updated event for the queue")
    }
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), "", "the queue is empty")
    Do $$$AssertEquals(..HeaderStatus(tHeld) '= ..#ABORTED, 1, "and the message the operation holds is not aborted")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-queue", ..#OPNAME, "abortall", .tData), 1, "one audit row names the abort of the queue")
}

/// <p>AC1, AC2: an entry the vendor refuses to abort is judged by whether it is still queued. An abort of a queue in which one entry was
/// taken by another process counts that entry <code>Skipped</code>, aborts the other and answers 200; an abort in which the vendor refuses
/// every entry that stays queued fails the call and aborts nothing. Both go through <class>OcuPilot.Test.InteropItemSeam</class>.</p>
/// <p>Mutation (Rule 19): invert the <code>$Data(tStillQueued(...))</code> test in <method>OcuPilot.Port.InteropPort.PerformAbortQueue</method>
/// (the port and its descendants recompiled) -- both legs go red.</p>
Method TestAnAbortAllCountsAnEntryThatLeftTheQueueAndFailsOnOneStillQueued()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Do ..HoldQueuePairs()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $ClassMethod(..#SEAM, "AbortItemGoneOnce")
    Set tCode = ..PortAs("Queues", "ABORTQUEUE", ..#OPNAME)
    Do $$$AssertEquals(tCode, "200 ", "an abort in which another process took one entry first is admitted")
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), "", "and leaves the queue empty")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-queue", ..#OPNAME, "abortall", .tData), 1, "one audit row names the abort")
    Do $$$AssertTrue((tData [ """aborted"":1") && (tData [ """skipped"":1"), "counting one entry aborted and one skipped: " _ tData)

    Do $$$AssertStatusOK(..Arm(), "the probe is armed again")
    Set tWaiting = ..Entries(..#OPNAME)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "AbortItemRefused")
    Set tCode = ..PortAs("Queues", "ABORTQUEUE", ..#OPNAME)
    Do $$$AssertEquals(tCode, "500 INTERNAL", "an abort in which the vendor refuses entries that are still queued fails the call")
    Do $$$AssertEquals(..Entries(..#OPNAME), tWaiting, "and the entries are all still queued")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-queue", ..#OPNAME, "abortall", .tNone), 0, "and no audit row names an abort")
}

/// <p>AC1: an abort of one message whose vendor call fails is 404 <code>PORT.NOTFOUND</code> when the entry has left the queue meanwhile,
/// and 500 <code>INTERNAL</code> when the entry is still queued; neither leaves an audit row.</p>
/// <p>Mutation (Rule 19): drop the re-read that answers 404 from <method>OcuPilot.Port.InteropPort.PerformAbortMessage</method> (the port and
/// its descendants recompiled) -- the first leg goes red.</p>
Method TestAnAbortOfOneMessageWhoseVendorCallFailsIsJudgedByTheEntry()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tWaiting = ..Entries(..#OPNAME, 1)
    Set tFirst = $Piece(tWaiting, ",", 1)
    Set tSecond = $Piece(tWaiting, ",", 2)
    Do ..HoldQueuePairs()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $ClassMethod(..#SEAM, "AbortItemGoneOnce")
    Do $$$AssertEquals(..PortAs("QueueItems", "ABORTMESSAGE", tFirst), "404 PORT.NOTFOUND", "an entry another process took first is not found")
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "AbortItemRefused")
    Do $$$AssertEquals(..PortAs("QueueItems", "ABORTMESSAGE", tSecond), "500 INTERNAL", "an entry the vendor refuses while it is still queued fails the call")
    Do $$$AssertEquals(..Entries(..#OPNAME, 1), tSecond, "and that entry is still queued")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-message", tFirst, "abort", .tOne) + ..AuditRows(tSince, "interop-message", tSecond, "abort", .tTwo), 0, "and neither call left an audit row")
}

/// <p>Declare the pairs of a principal who reads and aborts queue messages, for <method>PortAs</method>.</p>
ClassMethod HoldQueuePairs()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Queues", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Queues", "WRITE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p>AC2: an empty queue is refused 409 <code>INTEROP.QUEUE.EMPTY</code> by the port, at the mint and on the person's route, before any
/// vendor call; an unknown queue, a message id no header holds, a header whose message is no longer queued and an id that is no number
/// are each 404 <code>PORT.NOTFOUND</code>, unlogged; and none leaves a change or an audit row.</p>
/// <p>Mutation (Rule 19): drop <code>QUEUEEMPTY</code> from <method>OcuPilot.Port.InteropPort.RuntimeRefusal</method> -- the empty-queue legs go
/// red.</p>
Method TestAnEmptyQueueAndAGoneTargetAreRefusedWithNothingChanged()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tHeld = $Piece(..PreparedIds, ",", 1)
    Set tAborted = $Piece(..PreparedIds, ",", 2)
    Do ..HoldQueuePairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..PortAs("Queues", "ABORTQUEUE", ..#OPNAME)
    Do $$$AssertEquals(tCode, "200 ", "the first abort of the queue is admitted")
    Do $ClassMethod(..#SEAM, "Arm")
    Set tCode = ..PortAs("Queues", "ABORTQUEUE", ..#OPNAME)
    Do $$$AssertEquals(tCode, "409 INTEROP.QUEUE.EMPTY", "an abort of the now empty queue is refused")
    Set tCode = ..PortAs("Queues", "QUEUE", ..#OPNAME, "ABORTQUEUE")
    Do $$$AssertEquals(tCode, "409 INTEROP.QUEUE.EMPTY", "and so is the read composed for it, which is what the mint answers")
    Set tBody = {"action": "abort"}
    Do tBody.%Set("id", ..#OPNAME, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#QUEUESCREEN _ "/action", tBody, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ "|" _ tAnswer.%Get("reason"), 1: ""), "409 INTEROP.QUEUE.EMPTY|" _ ##class(OcuPilot.Api.InteropError).#REASONQUEUEEMPTY, "the person's route answers the published sentence")
    Do $$$AssertEquals(..PortAs("Queues", "ABORTQUEUE", "OcuPilotProbeNoSuchQueue"), "404 PORT.NOTFOUND", "an unknown queue is not found")
    Do $$$AssertEquals(..PortAs("QueueItems", "ABORTMESSAGE", "999999999"), "404 PORT.NOTFOUND", "a message id no header holds is not found")
    Do $$$AssertEquals(..PortAs("QueueItems", "ABORTMESSAGE", tAborted), "404 PORT.NOTFOUND", "so is a message that no longer waits in its queue")
    Do $$$AssertEquals(..PortAs("QueueItems", "ABORTMESSAGE", tHeld), "404 PORT.NOTFOUND", "so is the message the operation holds, which is in no queue")
    Do $$$AssertEquals(..PortAs("QueueItems", "ENTRY", "not-a-number"), "404 PORT.NOTFOUND", "and an id that is no number")
    Do $$$AssertEquals(..PortAs("QueueItems", "ABORTMESSAGE", ""), "400 PORT.VALIDATION", "a call naming no message is refused for it")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "no refusal or absence was logged as a fault")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-queue", ..#OPNAME, "abortall", .tData), 1, "one audit row names the abort of the queue, the first, and the refused calls left none")
    Do $$$AssertEquals(..AuditRows(tSince, "interop-message", tAborted, "abort", .tOne) + ..AuditRows(tSince, "interop-message", tHeld, "abort", .tTwo) + ..AuditRows(tSince, "interop-queue", "OcuPilotProbeNoSuchQueue", "abortall", .tThree), 0, "and none names a message or a queue that was refused")
}

/// <p>The call through <class>OcuPilot.Test.InteropItemSeam</class>, which keeps the lines the port logs and evaluates its pairs through
/// <class>OcuPilot.Test.ScreenGate</class>, as <code>status code</code>; <method>HoldQueuePairs</method> declares the set held. With
/// <var>pAction</var> the read is composed for that action.</p>
ClassMethod PortAs(pEndpoint As %String, pType As %String, pId As %String, pAction As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    If pId '= "" Set tQuery("id") = pId
    If pAction '= "" Set tQuery("action") = pAction
    Set tSC = $ClassMethod(..#SEAM, "Invoke", pEndpoint, pType, .tQuery, "", .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>AD-59: the copy-out draft of the message abort and of the queue abort each renders one ObjectScript step that switches to the
/// namespace the proposal read and calls the vendor's own method for the reviewed values, closes the proposal as a draft and changes
/// nothing: the entry is still queued, and no script names <code>AbortQueue</code>.</p>
/// <p>Mutation (Rule 19): render <code>AbortQueue</code> in place of the <code>EnumerateItem</code> loop in
/// <method>OcuPilot.Port.InteropPort.RuntimeSnippet</method> -- the queue row goes red.</p>
Method TestEachAbortsDraftRendersItsScriptAndChangesNothing()
{
    Do $$$AssertStatusOK(..Arm(), "the probe holds one message and has two waiting")
    Set tWaiting = ..Entries(..#OPNAME)
    Set tFirst = $Piece(..PreparedIds, ",", 2)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    For tCase = $ListBuild(..#MESSAGETOOL, "Ens.Queue).AbortItem(""" _ ..#OPNAME _ """, """ _ $Piece($Piece(tWaiting, ",", 1), ":", 1) _ """, """ _ $Piece($Piece(tWaiting, ",", 1), ":", 2) _ """)"), $ListBuild(..#QUEUETOOL, "Ens.Queue:EnumerateItem") {
        Set tTool = $List(tCase, 1)
        Set tArgs = $Select(tTool = ..#MESSAGETOOL: {"MessageId": (tFirst)}, 1: {"Name": (..#OPNAME)})
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", tTool, tArgs, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, tUser, "https://draft.example:52773", .tDraft, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ ": the draft is taken: " _ $Get(tCode))
        If '$IsObject($Get(tDraft)) Continue
        Set tText = tDraft.draft.steps.%Get(0).text
        Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", $Parameter(tTool, "TOOLNAME") _ ": an ObjectScript draft that closes the proposal")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ $List(tCase, 2)) && (tText '[ "AbortQueue"), $Parameter(tTool, "TOOLNAME") _ ": " _ tText)
    }
    Do $$$AssertEquals(..Entries(..#OPNAME), tWaiting, "no draft changed the queue")
}

}

/// <p>Pins Story 20.23's abort and suspend of a job's retried message end to end against a probe production in <code>USER</code>
/// (AD-6, AD-14, AD-15, AD-34, AD-51, AD-53, AD-62): on a production whose retrying operation (<code>RetryInterval</code> 2,
/// <code>FailureTimeout</code> 300) keeps failing one message, the agent's abort and suspend minted and confirmed over HTTP and the
/// person's, from the Jobs list's route, each leave the message Aborted or Suspended within two retry intervals and consume the
/// request; an abort or suspend of a job that is not retrying, or whose process has ended, is refused before any vendor call and leaves
/// no request for the job; a pid no job of the running production holds is 404, unlogged, and a namespace with no running production
/// is 409. Each write leaves one OcuPilot audit row naming the action, the job and the namespace.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), terminates one of its jobs and removes everything it made after
/// the last test. One class per run.</p>
Class OcuPilot.Test.InteropJobActions Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

/// <p>Story 20.23's queue test, whose header and audit readers this class shares.</p>
Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter RETRYNAME = "OcuPilotProbeRetry";

Parameter ABORTTOOL = "OcuPilot.Screen.Tool.InteropJobAbort";

Parameter SUSPENDTOOL = "OcuPilot.Screen.Tool.InteropJobSuspend";

Parameter SCREEN = "/screens/interop.jobs";

/// <p>The stored statuses of an aborted and of a suspended message.</p>
Parameter ABORTED = 7;

Parameter SUSPENDED = 5;

/// <p>The retry interval the probe's operation is given, in seconds; the message's abort or suspend is taken when its current wait
/// ends, so within two intervals.</p>
Parameter INTERVAL = 2;

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean;

/// <p>The process id of the idle process a test started, 0 when none; <method>OnAfterOneTest</method> ends it.</p>
Property PreparedIdle As %Integer;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Set ..PreparedIdle = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropJobActions compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, its messages and its proposals; a failing status when any of it survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropJobActions left probe state in USER")
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
    If ..PreparedIdle {
        Do $System.Process.Terminate(..PreparedIdle)
        Set ..PreparedIdle = 0
    }
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Do $$$AssertEquals(..RequestNodes(), 0, "and no job request is left in the instance")
    Quit $$$OK
}

/// <p>Whether the instance holds any job request node (<code>^Ens.JobRequest</code>), read in <code>USER</code>: 0 when none.</p>
ClassMethod RequestNodes() As %Integer
{
    Set tData = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tData = ''$Data(^Ens.JobRequest)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tData
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

/// <p>The row of the host <var>pHost</var>'s job in the Jobs list the port answers, <code>""</code> when it lists none; the first when
/// it lists several.</p>
ClassMethod JobOf(pHost As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Jobs", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If '$IsObject($Get(tRows)) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Host = pHost Quit
    }
    If $IsObject($Get(tRow)) && (tRow.Host = pHost) Quit tRow
    Quit ""
}

/// <p>Bring the probe to the state every retry test assumes: its retrying operation (<code>RetryInterval</code>
/// <parameter>INTERVAL</parameter>) running, sent one message it fails, and its job reading <code>Retry</code> with that message.</p>
Method ArmRetry() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddRetryItem", ..#RETRYNAME, ..#INTERVAL, 300)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Hang 3
    Quit ..SendAndWait()
}

/// <p>Send the retrying operation one message and wait, fifteen seconds at most, until its job reads <code>Retry</code> with it.</p>
Method SendAndWait() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Send", ..#RETRYNAME)
    If $$$ISERR(tSC) Quit tSC
    For tTry = 1:1:30 {
        Set tRow = ..JobOf(..#RETRYNAME)
        If $IsObject(tRow) && (tRow.Status = "Retry") && (tRow.ActiveMessage '= "") Quit
        Hang 0.5
    }
    Set tRow = ..JobOf(..#RETRYNAME)
    If '$IsObject(tRow) || (tRow.Status '= "Retry") Quit $$$ERROR($$$GeneralError, "the retrying operation's job did not read Retry")
    Quit $$$OK
}

/// <p>Wait, ten seconds at most, until message header <var>pId</var> reads <var>pStatus</var>; the seconds it took, <code>-1</code> when
/// it never did.</p>
ClassMethod WaitStatus(pId As %String, pStatus As %Integer) As %Numeric
{
    Set tStart = $ZHorolog
    For tTry = 1:1:40 {
        If $ClassMethod(..#QUEUES, "HeaderStatus", pId) = pStatus Quit
        Hang 0.25
    }
    If $ClassMethod(..#QUEUES, "HeaderStatus", pId) '= pStatus Quit -1
    Quit $ZHorolog - tStart
}

/// <p>The agent's mint of <var>pTool</var> for the job <var>pJob</var> as the HTTP account, then its confirm over HTTP: the card's one row,
/// the consequence code and destructiveness, the single envelope the confirm answers, its change action, marker and read-back, and its
/// ledger row. The turn is in <var>pTurn</var>.</p>
Method Through(pTool As %String, pJob As %String, pRow As %String, pConsequence As %String, pDestructive As %Boolean, Output pTurn As %String)
{
    Set tName = $Parameter(pTool, "TOOLNAME")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, {"Job": (pJob)}, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), pRow, tName _ ": its card shows one row, from " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-job|USER|" _ pJob, tName _ ": the target is the job, by its process id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), pConsequence _ "|" _ pDestructive, tName _ ": its consequence code and destructiveness")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), tName _ ": the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, tName _ ": updated, marked (AD-15), and the read-back sent nothing")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", pTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
}

/// <p>The person's row action <var>pAction</var> on the job <var>pJob</var> through the Jobs list's route: the status, and the answer in
/// <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pJob As %String, Output pAnswer) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pJob, "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus
}

/// <p>AC3, AC5: the agent's abort of the message a job keeps retrying, minted and confirmed over HTTP while its governance key is on,
/// leaves the message Aborted within two retry intervals and consumes the request; the card shows the active message moving to Aborted
/// and is destructive; and one OcuPilot audit row names the abort, the job and the namespace, and no message content.</p>
/// <p>Mutation (Rule 19): skip <code>AbortOperation</code> in <method>OcuPilot.Port.InteropPort.VendorJob</method> -- the message never reads
/// Aborted and this goes red; drop <code>AuditRuntime</code> from <method>OcuPilot.Port.InteropPort.PerformJobAction</method> -- the audit leg goes
/// red.</p>
Method TestTheAgentsAbortOfARetriedMessageLeavesItAborted()
{
    Do $$$AssertStatusOK(..ArmRetry(), "the retrying operation's job reads Retry with a message")
    Set tRow = ..JobOf(..#RETRYNAME)
    Set tJob = tRow.Job
    Set tMessage = tRow.ActiveMessage
    Do ..EnableKey("interop.jobs.abort")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Through(..#ABORTTOOL, tJob, "[{""field"":""ActiveMessage"",""before"":""" _ tMessage _ """,""after"":""Aborted""}]", "INTEROP.JOB.ABORT", 1, .tTurn)
    Set tTook = ..WaitStatus(tMessage, ..#ABORTED)
    Do $$$AssertTrue((tTook >= 0) && (tTook <= (2 * ..#INTERVAL) + 1), "the message reads Aborted within two retry intervals: " _ tTook _ " s")
    Do $$$AssertEquals(..RequestNodes(), 0, "and the job took the request")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "abort", .tData), 1, "one OcuPilot audit row names the abort of the job")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ """host"":""" _ ..#RETRYNAME _ """") && (tData '[ "Ens.Request"), "naming the namespace and the host, and no message content: " _ tData)
}

/// <p>AC3: the agent's suspend of the message a job keeps retrying, confirmed over HTTP with its key at the baseline's value (on),
/// leaves the message Suspended within two retry intervals; the card is not destructive; and one audit row names the suspend.</p>
/// <p>Mutation (Rule 19): call <code>AbortOperation</code> for the suspend in <method>OcuPilot.Port.InteropPort.VendorJob</method> -- the message
/// reads Aborted and this goes red.</p>
Method TestTheAgentsSuspendOfARetriedMessageLeavesItSuspended()
{
    Do $$$AssertStatusOK(..ArmRetry(), "the retrying operation's job reads Retry with a message")
    Set tRow = ..JobOf(..#RETRYNAME)
    Set tJob = tRow.Job
    Set tMessage = tRow.ActiveMessage
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Through(..#SUSPENDTOOL, tJob, "[{""field"":""ActiveMessage"",""before"":""" _ tMessage _ """,""after"":""Suspended""}]", "INTEROP.JOB.SUSPEND", 0, .tTurn)
    Set tTook = ..WaitStatus(tMessage, ..#SUSPENDED)
    Do $$$AssertTrue((tTook >= 0) && (tTook <= (2 * ..#INTERVAL) + 1), "the message reads Suspended within two retry intervals: " _ tTook _ " s")
    Do $$$AssertEquals(..RequestNodes(), 0, "and the job took the request")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "suspend", .tData), 1, "one audit row names the suspend of the job")
}

/// <p>AC3: the person's Suspend message, then Abort message, on the Jobs list's route (an item's Jobs tab posts to the same route) each
/// answer 200 with the <code>updated</code> event for the job and a read-back that sent nothing, leave the message Suspended and then
/// Aborted, and leave one audit row each; no agent marker is emitted for a person, and governance does not gate a person's action.</p>
/// <p>Mutation (Rule 19): drop <code>AuditRuntime</code> from <method>OcuPilot.Port.InteropPort.PerformJobAction</method> -- the audit legs go
/// red.</p>
Method TestThePersonsSuspendAndAbortFromTheJobsRoute()
{
    Do $$$AssertStatusOK(..ArmRetry(), "the retrying operation's job reads Retry with a message")
    Set tRow = ..JobOf(..#RETRYNAME)
    Set tJob = tRow.Job
    Set tMessage = tRow.ActiveMessage
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act("suspend", tJob, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Suspend message answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, "updated|interop-job|USER|" _ tJob _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "publishing the updated event for the job")
    }
    Do $$$AssertTrue(..WaitStatus(tMessage, ..#SUSPENDED) >= 0, "the message reads Suspended")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "suspend", .tData), 1, "one audit row names the suspend")
    ; The job moves on; a second message fails and is retried, and the person aborts it.
    Do $$$AssertStatusOK(..SendAndWait(), "the job retries a second message")
    Set tRow = ..JobOf(..#RETRYNAME)
    Set tNext = tRow.ActiveMessage
    Do $$$AssertNotEquals(tNext, tMessage, "which is another message")
    Set tStatus = ..Act("abort", tRow.Job, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Abort message answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue(..WaitStatus(tNext, ..#ABORTED) >= 0, "the message reads Aborted")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tRow.Job, "abort", .tData), 1, "one audit row names the abort")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tJob, .tMarker), 0, "and no agent marker is emitted for a person's action")
    Do $$$AssertEquals(..RequestNodes(), 0, "and no request is left")
}

/// <p>AC3: an abort or suspend of a job that is not retrying a message -- the idle operation's job -- is refused 409
/// <code>INTEROP.JOB.NOTRETRYING</code> by the port, at the mint and on the person's route, before any vendor call, so no job request is
/// left for it; the refusals leave no audit row and are not logged.</p>
/// <p>Mutation (Rule 19): drop <code>NOTRETRYING</code> from <method>OcuPilot.Port.InteropPort.RuntimeRefusal</method> -- the idle-job legs go red,
/// a request node appearing.</p>
Method TestAnAbortOrSuspendOfAnIdleJobIsRefusedAndLeavesNoRequest()
{
    Do $$$AssertStatusOK(..ArmRetry(), "the production runs, its retrying operation retrying a message")
    Set tIdle = ..JobOf(..#OPNAME)
    Do $$$AssertTrue($IsObject(tIdle) && (tIdle.Status '= "Retry"), "the plain operation's job is idle")
    If '$IsObject(tIdle) Quit
    Do ..HoldJobPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tType = "ABORTJOB", "SUSPENDJOB" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = tIdle.Job
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "409 INTEROP.JOB.NOTRETRYING|" _ ##class(OcuPilot.Api.InteropError).#REASONJOBNOTRETRYING, tType _ " of the idle job is refused for it")
        Do $$$AssertEquals(..RequestNodes(), 0, tType _ " left no request for the job")
        Set tQuery("action") = tType
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "JOB", .tQuery, "", .tRead, .tReadHttp, .tReadFault)
        Do $$$AssertEquals(+$Get(tReadHttp) _ " " _ $Select($IsObject($Get(tReadFault)): tReadFault.%Get("code"), 1: ""), "409 INTEROP.JOB.NOTRETRYING", "so is the read composed for " _ tType _ ", which is what the mint answers")
    }
    Do $$$AssertEquals(..Act("abort", tIdle.Job, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 INTEROP.JOB.NOTRETRYING", "the person's Abort message is refused the same way")
    Do $$$AssertEquals(..Act("suspend", tIdle.Job, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 INTEROP.JOB.NOTRETRYING", "and so is Suspend message")
    Do $$$AssertEquals(..RequestNodes(), 0, "no request is left for any job")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdle.Job, "abort", .tData) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdle.Job, "suspend", .tMore), 0, "and no audit row names the idle job")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "nothing was logged as a fault")
    Set tStill = ..JobOf(..#RETRYNAME)
    Do $$$AssertTrue($IsObject(tStill) && (tStill.Status = "Retry"), "and the retrying job still retries its message")
}

/// <p>AC3: an abort or suspend of a job whose process has ended -- the plain operation's job, terminated, which the Jobs read keeps
/// listing as <code>Dead</code> under the vendor's ghost id -- is refused 409 <code>INTEROP.JOB.DEAD</code> before any vendor call, and
/// leaves no request for it.</p>
/// <p>Mutation (Rule 19): drop <code>DEAD</code> from <method>OcuPilot.Port.InteropPort.RuntimeRefusal</method> -- the dead-job legs go red.</p>
Method TestAnAbortOrSuspendOfAJobWhoseProcessEndedIsRefusedAndLeavesNoRequest()
{
    Do $$$AssertStatusOK(..ArmRetry(), "the production runs")
    Set tDead = ..TerminatedJob(..#OPNAME)
    Do $$$AssertNotEquals(tDead, "", "the plain operation's job was terminated and reads Dead")
    If tDead = "" Quit
    Do ..HoldJobPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    For tType = "ABORTJOB", "SUSPENDJOB" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = tDead
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "409 INTEROP.JOB.DEAD|" _ ##class(OcuPilot.Api.InteropError).#REASONJOBDEAD, tType _ " of the dead job is refused for it")
        Do $$$AssertEquals(..RequestNodes(), 0, tType _ " left no request for the job")
    }
    Do $$$AssertEquals(..Act("abort", tDead, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 INTEROP.JOB.DEAD", "the person's Abort message is refused the same way")
    Do $$$AssertEquals(..RequestNodes(), 0, "and leaves no request")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "nothing was logged as a fault")
}

/// <p>Terminate the process of host <var>pHost</var>'s job and answer the id the Jobs read lists it under once it reads <code>Dead</code>,
/// waiting ten seconds at most; <code>""</code> when it never did. The vendor renames a dead job's id a second after its process ends,
/// and the row then stays for as long as the production runs.</p>
ClassMethod TerminatedJob(pHost As %String) As %String
{
    Set tRow = ..JobOf(pHost)
    If '$IsObject(tRow) Quit ""
    Set tOriginal = tRow.Job
    Do $System.Process.Terminate(tOriginal)
    For tTry = 1:1:40 {
        Hang 0.25
        Set tRow = ..JobOf(pHost)
        If $IsObject(tRow) && tRow.Dead && (tRow.Job '= tOriginal) Quit
    }
    If $IsObject(tRow) && tRow.Dead Quit tRow.Job
    Quit ""
}

/// <p>Declare the pairs of a principal who reads and acts on jobs, for the calls through <class>OcuPilot.Test.InteropItemSeam</class>.</p>
ClassMethod HoldJobPairs()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Jobs", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Jobs", "WRITE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageSuspend", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p>AC3, AC4: a pid that no job of the running production holds is 404 <code>PORT.NOTFOUND</code>, unlogged, for the read and for each
/// of the three job writes, and the person's route says the same; a namespace with no running production is 409
/// <code>INTEROP.PRODUCTION.NOTRUNNING</code> for the same calls; none leaves a request or an audit row.</p>
/// <p>Mutation (Rule 19): make the <code>JOB</code> read answer a pid it did not find as a row of its own -- the 404 legs go red.</p>
Method TestAPidNoJobHoldsIsNotFoundAndAStoppedProductionIsNotRunning()
{
    Do ..HoldJobPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "no production runs in USER")
    For tType = "JOB", "ABORTJOB", "SUSPENDJOB", "STOPJOB" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "999999"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 INTEROP.PRODUCTION.NOTRUNNING", tType _ " with no production running")
    }
    Do $$$AssertEquals(..Act("abort", "999999", .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 INTEROP.PRODUCTION.NOTRUNNING", "the person's route says the same")
    Do $$$AssertStatusOK(..ArmRetry(), "a production runs")
    For tType = "JOB", "ABORTJOB", "SUSPENDJOB", "STOPJOB" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "999999"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", tType _ " of a pid no job holds")
    }
    Do $$$AssertEquals(..Act("stop", "999999", .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "the person's route says the same")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "ABORTJOB", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 PORT.VALIDATION", "a call naming no job is refused for it")
    Do $$$AssertEquals(..RequestNodes(), 0, "no request is left")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "nothing was logged as a fault")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", "999999", "abort", .tData), 0, "and no audit row names the pid")
}

/// <p>A process that does nothing for two minutes, started by <method>TestALiveProcessThatIsNoJobOfTheProductionIsNotFound</method> as a
/// live process that no production holds; the test ends it.</p>
ClassMethod Idle()
{
    Hang 120
}

/// <p>AC3, AC4: a live process that is no job of the running production -- an idle process the test starts -- is 404
/// <code>PORT.NOTFOUND</code> for the read and for the abort, the suspend and the stop, at the port and on the person's route. The port
/// finds a job among the running production's hosts and never in the process table, so a system process or OcuPilot's own is not reached
/// (AD-10): the process is still alive afterwards, no request was set for it, no audit row names it, and nothing was logged as a fault.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Port.InteropPort.ReadJob</method> answer a live process id that no host holds as a job of its
/// own, in place of 404 (the port and its descendants recompiled) -- the legs go red.</p>
Method TestALiveProcessThatIsNoJobOfTheProductionIsNotFound()
{
    Do $$$AssertStatusOK(..ArmRetry(), "the production runs")
    Job ##class(OcuPilot.Test.InteropJobActions).Idle()
    Set ..PreparedIdle = $ZChild
    Set tIdle = ..PreparedIdle
    For tTry = 1:1:20 {
        If tIdle && $Data(^$JOB(tIdle)) Quit
        Hang 0.25
    }
    Do $$$AssertTrue(tIdle && $Data(^$JOB(tIdle)), "an idle process that is no job of the production is running")
    If 'tIdle Quit
    Do ..HoldJobPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tType = "JOB", "ABORTJOB", "SUSPENDJOB", "STOPJOB" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = tIdle
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", tType _ " of a live process that is no job of the production is not found")
    }
    For tAction = "abort", "suspend", "stop" {
        Do $$$AssertEquals(..Act(tAction, tIdle, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "the person's " _ tAction _ " says the same")
    }
    Do $$$AssertTrue($Data(^$JOB(tIdle)) > 0, "the process is still alive")
    Do $$$AssertEquals(..RequestNodes(), 0, "no request was set for it")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdle, "abort", .tOne) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdle, "suspend", .tTwo) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdle, "stop", .tThree), 0, "and no audit row names it")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "nothing was logged as a fault")
}

}

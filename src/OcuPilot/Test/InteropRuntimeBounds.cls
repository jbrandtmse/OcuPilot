/// <p>Pins what bounds Story 20.23's queue and job actions against a probe production in <code>USER</code> (AD-34, AD-48, AD-51, AD-62):
/// an abort of a queue takes at most the entries its read enumerates and refuses the digest of any other set, so a queue holding more
/// than <parameter>OcuPilot.Port.InteropPort.ABORTMAX</parameter> keeps the rest (<class>OcuPilot.Test.InteropCapSeam</class> lowers the
/// limit to one); a stop waits the production's own update timeout when that is shorter than the cap; and the agent's mint is refused,
/// with nothing stored and no vendor call, for an empty queue, a target that is gone, a job that is not retrying and a job whose process
/// has ended -- the same refusals the person's route gives.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, an interoperability-enabled <code>USER</code>
/// namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), hangs its operation for ten minutes, stops and terminates its jobs
/// and removes everything it made after the last test. One class per run.</p>
Class OcuPilot.Test.InteropRuntimeBounds Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter CAPSEAM = "OcuPilot.Test.InteropCapSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

/// <p>Story 20.23's queue, job and stop tests, whose readers and arming this class shares.</p>
Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter JOBS = "OcuPilot.Test.InteropJobActions";

Parameter STOPS = "OcuPilot.Test.InteropJobStop";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter RETRYNAME = "OcuPilotProbeRetry";

/// <p>The message status the vendor stores for an aborted message.</p>
Parameter ABORTED = 7;

/// <p>The cap a stop is given in the timeout leg, above the ten seconds a stock production waits.</p>
Parameter WIDECAP = 30;

/// <p>The governance policy found before a test turned a key on, restored after it.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropRuntimeBounds compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropRuntimeBounds left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#SEAM, "Restore")
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

/// <p>The stop wait, the fake gate and the governance policy are put back, the proposals removed and the probe stopped, whether the
/// test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#SEAM, "Restore")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
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

/// <p>A call of the port class <var>pClass</var> (the shipped port's seam, or the one with the lower limit) on <var>pEndpoint</var> and
/// <var>pType</var> for <var>pId</var>, as <code>status code</code>; <var>pHasDigest</var> sends <var>pDigest</var> as the digest the
/// queue abort was reviewed with. The answer is in <var>pResult</var>.</p>
ClassMethod PortWith(pClass As %String, pEndpoint As %String, pType As %String, pId As %String, Output pResult, pDigest As %String = "", pHasDigest As %Boolean = 0) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    If pHasDigest Set tQuery($Parameter(..#PORT, "DIGESTKEY")) = pDigest
    Set pResult = ""
    Set tSC = $ClassMethod(pClass, "Invoke", pEndpoint, pType, .tQuery, "", .pResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>AC2: an abort of a queue holding more than the limit takes the entries its read enumerated and keeps the rest. With the limit at
/// one, the queue of two waiting messages reads <code>Entries</code> 1 of <code>Count</code> 2; its digest stands for the one entry, so the
/// digest of the full set is refused <code>INTEROP.QUEUE.CHANGED</code> with both entries still queued; the digest of the enumerated
/// entry aborts the first-queued message alone, answers its counts, leaves the second queued and the held message untouched, and leaves
/// one audit row naming one aborted.</p>
/// <p>Mutation (Rule 19): enumerate the queue's entries in <method>OcuPilot.Port.InteropPort.ReadQueue</method> without the limit -- the
/// first leg reads two entries and this goes red.</p>
Method TestAnAbortOfAQueueHoldingMoreThanTheLimitKeepsTheRest()
{
    Do $$$AssertStatusOK($ClassMethod(..#READ, "ArmProbe", .tIds), "the probe holds one message and has two waiting")
    Set tHeld = $Piece(tIds, ",", 1)
    Set tFirst = $Piece(tIds, ",", 2)
    Set tSecond = $Piece(tIds, ",", 3)
    Do $ClassMethod(..#QUEUES, "HoldQueuePairs")
    Do $$$AssertEquals(..PortWith(..#SEAM, "Queues", "QUEUE", ..#OPNAME, .tFull), "200 ", "the queue reads through the shipped limit")
    Do $$$AssertEquals(..PortWith(..#CAPSEAM, "Queues", "QUEUE", ..#OPNAME, .tCapped), "200 ", "and through the lowered one")
    If '$IsObject(tFull) || '$IsObject(tCapped) Quit
    Do $$$AssertEquals(tFull.Entries _ "|" _ tFull.Count, "2|2", "the shipped limit enumerates both waiting messages")
    Do $$$AssertEquals(tCapped.Entries _ "|" _ tCapped.Count, "1|2", "the lowered limit enumerates one of the two the queue holds")
    Do $$$AssertTrue((tCapped.Digest '= tFull.Digest) && ($Length(tCapped.Digest) = 64), "and its digest stands for that one entry, not both")
    Do $$$AssertEquals(..PortWith(..#CAPSEAM, "Queues", "ABORTQUEUE", ..#OPNAME, .tRefused, tFull.Digest, 1), "409 " _ $Parameter("OcuPilot.Api.InteropError", "QUEUECHANGED"), "the digest of the full set is refused by an abort that would take one")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "Entries", ..#OPNAME, 1), tFirst _ "," _ tSecond, "with both entries still queued")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..PortWith(..#CAPSEAM, "Queues", "ABORTQUEUE", ..#OPNAME, .tDone, tCapped.Digest, 1), "200 ", "the digest of the enumerated entry aborts: " _ $Select($IsObject(tDone): tDone.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tDone): tDone.Count _ "|" _ tDone.Aborted _ "|" _ tDone.Skipped, 1: ""), "1|1|0", "one enumerated, one aborted, none skipped")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "Entries", ..#OPNAME, 1), tSecond, "the second message is still queued")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "HeaderStatus", tFirst) _ "|" _ ($ClassMethod(..#QUEUES, "HeaderStatus", tSecond) '= ..#ABORTED) _ "|" _ ($ClassMethod(..#QUEUES, "HeaderStatus", tHeld) '= ..#ABORTED), ..#ABORTED _ "|1|1", "the first reads Aborted, and the second and the held message do not")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-queue", ..#OPNAME, "abortall", .tData), 1, "one audit row names the abort of the queue")
    Do $$$AssertTrue((tData [ """aborted"":1") && (tData [ """skipped"":0"), "counting one aborted: " _ tData)
}

/// <p>AC4, AC5: a stop passes the production's update timeout when that is shorter than the cap, not the cap itself. With the cap
/// raised to <parameter>WIDECAP</parameter> seconds and the stock production's timeout at ten, the stop of a job hung on a message waits
/// about the ten before it forces the job -- not the thirty -- and puts the job's message back on its queue.</p>
/// <p>Mutation (Rule 19): pass the cap in place of the lesser of the timeout and the cap in
/// <method>OcuPilot.Port.InteropPort.VendorJob</method> (the port and its descendants recompiled) -- the stop waits the cap and this goes
/// red.</p>
Method TestAStopWaitsTheProductionsTimeoutWhenItIsShorterThanTheCap()
{
    Do $$$AssertStatusOK($ClassMethod(..#READ, "ArmProbe", .tIds), "the probe's operation is hung on one message with two waiting")
    Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.ActiveMessage = $Piece(tIds, ",", 1)), "the operation's job holds the first message")
    If '$IsObject(tRow) Quit
    Do $ClassMethod(..#JOBS, "HoldJobPairs")
    Do $ClassMethod(..#SEAM, "Shorten", ..#WIDECAP)
    Set tStart = $ZHorolog
    Set tCode = ..PortWith(..#SEAM, "Jobs", "STOPJOB", tRow.Job, .tDone)
    Set tTook = $ZHorolog - tStart
    Do $ClassMethod(..#SEAM, "Restore")
    Do $$$AssertEquals(tCode, "200 ", "the stop is answered: " _ $Select($IsObject(tDone): tDone.%ToJSON(), 1: ""))
    Do $$$AssertTrue((tTook >= 8) && (tTook < 20), "it waited about the production's ten seconds, not the cap of " _ ..#WIDECAP _ ": " _ $FNumber(tTook, "", 2) _ " s")
    Do $$$AssertEquals($ClassMethod(..#READ, "QueueCount"), 3, "and the job's message is back on the queue beside the two waiting")
}

/// <p>Bring the probe to the state the mint legs assume: its retrying operation retrying one message
/// (<method>OcuPilot.Test.InteropJobActions.ArmRetry</method>) and its plain operation's job listed and alive. Answers <code>1</code>
/// when both hold.</p>
Method ArmRetry() As %Boolean
{
    If $$$ISERR($ClassMethod(..#JOBS, "ArmRetry")) Quit 0
    For tTry = 1:1:30 {
        Set tIdle = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
        If $IsObject(tIdle) && 'tIdle.Dead Quit
        Hang 0.5
    }
    Quit $IsObject(tIdle) && 'tIdle.Dead
}

/// <p>The agent's mint of <var>pTool</var> (a class name in <code>OcuPilot.Screen.Tool</code>) naming <var>pValue</var> as its argument
/// <var>pArgument</var>, as the HTTP account: <code>status code</code>, and <code>minted</code> after it when a proposal was stored.</p>
ClassMethod MintRefusal(pTool As %String, pArgument As %String, pValue As %String) As %String
{
    Set tArgs = {}
    Do tArgs.%Set(pArgument, pValue, "string")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", "OcuPilot.Screen.Tool." _ pTool, tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ $Select($IsObject($Get(tProposal)): " minted", 1: "")
}

/// <p>AC2, AC3, AC4: the agent is refused at the mint what the person's route refuses, with the port's own code and nothing stored: an
/// empty queue (<code>INTEROP.QUEUE.EMPTY</code>), an abort or a suspend of the idle job (<code>INTEROP.JOB.NOTRETRYING</code>), an abort,
/// a suspend and a stop of a job whose process has ended (<code>INTEROP.JOB.DEAD</code>), and a queue, a message and a job that do not
/// exist (<code>TOOL.ARGUMENTS</code>, the mint's answer for a target no read finds, where the route answers 404). No refusal reaches the vendor: no job request is left, the event log gets no <code>Stopping
/// job</code> line, no audit row names a target, and the retrying job still retries its message.</p>
/// <p>Mutation (Rule 19): stop <method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method> composing the action key at the mint -- the
/// mint reads the job unrefused and the refusal legs go red.</p>
Method TestTheMintRefusesWhatTheScreenRefuses()
{
    Do $$$AssertTrue(..ArmRetry(), "the production runs, its retrying operation retrying a message")
    Set tIdle = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tIdle) && (tIdle.Status '= "Retry"), "the plain operation's job is idle")
    If '$IsObject(tIdle) Quit
    Set tIdleJob = tIdle.Job
    For tKey = "interop.queues.abort", "interop.queuemessages.abort", "interop.jobs.abort" {
        Do ..EnableKey(tKey)
    }
    Set tMark = $ClassMethod(..#STOPS, "LastLogRow")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    ; tool | the argument it names | that argument's value | the refusal expected at the mint
    Set tCases = $ListBuild("InteropQueueAbort|Name|" _ ..#OPNAME _ "|409 INTEROP.QUEUE.EMPTY", "InteropQueueAbort|Name|OcuPilotProbeNoSuchQueue|400 TOOL.ARGUMENTS", "InteropQueueMessageAbort|MessageId|999999999|400 TOOL.ARGUMENTS",
        "InteropJobAbort|Job|" _ tIdleJob _ "|409 INTEROP.JOB.NOTRETRYING", "InteropJobSuspend|Job|" _ tIdleJob _ "|409 INTEROP.JOB.NOTRETRYING",
        "InteropJobAbort|Job|999999|400 TOOL.ARGUMENTS", "InteropJobSuspend|Job|999999|400 TOOL.ARGUMENTS", "InteropJobStop|Job|999999|400 TOOL.ARGUMENTS")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tGot = ..MintRefusal($Piece(tCase, "|", 1), $Piece(tCase, "|", 2), $Piece(tCase, "|", 3))
        Do $$$AssertEquals(tGot, $Piece(tCase, "|", 4), $Piece(tCase, "|", 1) _ " for " _ $Piece(tCase, "|", 2) _ " " _ $Piece(tCase, "|", 3) _ " is refused at the mint, and nothing is stored, not " _ tGot)
    }
    Set tDead = $ClassMethod(..#JOBS, "TerminatedJob", ..#OPNAME)
    Do $$$AssertNotEquals(tDead, "", "the plain operation's job was terminated and reads Dead")
    If tDead '= "" {
        For tTool = "InteropJobAbort", "InteropJobSuspend", "InteropJobStop" {
            Set tGot = ..MintRefusal(tTool, "Job", tDead)
            Do $$$AssertEquals(tGot, "409 INTEROP.JOB.DEAD", tTool _ " of the dead job is refused at the mint, and nothing is stored, not " _ tGot)
        }
    }
    Do $$$AssertEquals($ClassMethod(..#JOBS, "RequestNodes"), 0, "no refusal left a request for any job")
    Do $$$AssertEquals($ClassMethod(..#STOPS, "StoppingRows", tMark), 0, "and no Stopping job line reached the event log")
    Set tAudited = $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdleJob, "abort", .tOne) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tIdleJob, "suspend", .tTwo) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tDead, "stop", .tThree) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-queue", ..#OPNAME, "abortall", .tFour)
    Do $$$AssertEquals(tAudited, 0, "and no audit row names a target that was refused")
    Set tStill = $ClassMethod(..#JOBS, "JobOf", ..#RETRYNAME)
    Do $$$AssertTrue($IsObject(tStill) && (tStill.Status = "Retry"), "the retrying job still retries its message")
}

}

/// <p>Pins Story 20.23's job stop end to end against a probe production in <code>USER</code> (AD-6, AD-14, AD-15, AD-34, AD-51, AD-53,
/// AD-62): the agent's stop of the plain operation's job, minted and confirmed over HTTP, and the person's, end the job, leave its row
/// off the Jobs list and the production reading an update pending, and Story 20.2's confirmed Update starts a job again; a stop of a job
/// hung on a message, with the wait shortened to two seconds through <class>OcuPilot.Test.InteropGateSeam</class>, forces it, puts its
/// message back on its queue and leaves its host reading Error; a job whose process has ended and a pid no job holds are refused, with
/// no vendor call and so no <code>Stopping job</code> row in the event log; each stop leaves one OcuPilot audit row; and the dead-job
/// premise helper <class>OcuPilot.Test.InteropJobEnd</class> waits for a start's own update, ends a job the production replaced and
/// refuses a Troubled production by name.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>), hangs its operation for ten minutes, stops and terminates its
/// jobs and removes everything it made after the last test. One class per run.</p>
Class OcuPilot.Test.InteropJobStop Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

/// <p>Story 20.2's control test, whose Productions row action and state reader this class shares.</p>
Parameter PRODUCTIONS = "OcuPilot.Test.InteropControl";

/// <p>Story 20.23's queue and job tests, whose readers and arming this class shares.</p>
Parameter QUEUES = "OcuPilot.Test.InteropQueueActions";

Parameter JOBS = "OcuPilot.Test.InteropJobActions";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropJobStop";

Parameter SCREEN = "/screens/interop.jobs";

/// <p>The seconds a shortened stop waits before it forces the job.</p>
Parameter SHORTWAIT = 2;

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropJobStop compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropJobStop left probe state in USER")
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

/// <p>The stop wait, the fake gate and the governance policy are put back, the proposals removed and the probe stopped, whether the test
/// passed or failed.</p>
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

/// <p>Start the probe production through the port and wait for the plain operation's job.</p>
Method StartProbe() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    For tTry = 1:1:30 {
        Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
        If $IsObject(tRow) && 'tRow.Dead Quit
        Hang 0.5
    }
    Quit $$$OK
}

/// <p>How many event-log rows after row <var>pAfter</var> begin <code>Stopping job</code>, read in <code>USER</code>: the line the vendor's
/// <code>Stop</code> writes before it does anything, so a refusal before the vendor call leaves none.</p>
ClassMethod StoppingRows(pAfter As %Integer) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT COUNT(*) FROM Ens_Util.Log WHERE ID > ? AND Text %STARTSWITH 'Stopping job'", pAfter)
        If tResult.%Next() Set tCount = tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>Whether the Jobs list the port answers still lists the process id <var>pJob</var>.</p>
ClassMethod Listed(pJob As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Jobs", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tListed = 0
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.Job = pJob Set tListed = 1
        }
    }
    Quit tListed
}

/// <p>The agent's mint of the stop for the job <var>pJob</var> as the HTTP account, then its confirm over HTTP: the card's one row, the
/// consequence code, that it is not destructive, the single envelope the confirm answers, its <code>deleted</code> event, its marker, a
/// read-back that finds the job gone, and its ledger row.</p>
Method Through(pJob As %String, pRow As %String)
{
    Set tName = $Parameter(..#TOOL, "TOOLNAME")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Job": (pJob)}, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), pRow, tName _ ": its card shows the job's status going to Stopped, from " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-job|USER|" _ pJob, tName _ ": the target is the job, by its process id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.JOB.STOP|0", tName _ ": its consequence code, and it is not destructive")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), tName _ ": the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, "1|deleted|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, tName _ ": deleted, marked (AD-15), and the read-back finds the job gone")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Story 20.2's confirmed Update of the probe production, as a person on the Productions screen, and whether it started a live job for
/// the plain operation: the Update's status and code, then the job.</p>
Method UpdateStartsAJob() As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(##class(OcuPilot.Test.Http).GetTestUsername(), "completed", .tTurn)
    Set tText = $ClassMethod(..#PRODUCTIONS, "Act", "update", ..#PRODUCTION)
    For tTry = 1:1:20 {
        Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
        If $IsObject(tRow) && 'tRow.Dead Quit
        Hang 0.25
    }
    Quit tText _ "|" _ $Select($IsObject(tRow) && 'tRow.Dead: "job", 1: "none") _ "|" _ $ClassMethod(..#PRODUCTIONS, "State")
}

/// <p>The newest event-log row's id in <code>USER</code>, 0 when there is none.</p>
ClassMethod LastLogRow() As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT MAX(ID) FROM Ens_Util.Log")
        If tResult.%Next() Set tId = +tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tId
}

/// <p>Declare the pairs of a principal who reads and stops jobs, for the calls through <class>OcuPilot.Test.InteropGateSeam</class>'s
/// fake gate.</p>
ClassMethod HoldPairs()
{
    Do $ClassMethod(..#JOBS, "HoldJobPairs")
}

/// <p>AC4, AC5: the agent's stop of the plain operation's idle job, minted and confirmed over HTTP with its governance key at the baseline's
/// value (on), ends the job -- its row leaves the Jobs list -- and leaves the production reading an update pending, which Story 20.2's
/// confirmed Update applies by starting a job again. The card shows the job's status moving to Stopped and is not destructive; the confirm
/// answers one envelope, <code>deleted</code>, marked, with a read-back that finds the job gone; the vendor logged one
/// <code>Stopping job</code> line; and one OcuPilot audit row names the stop, the job, the namespace and the host.</p>
/// <p>Mutation (Rule 19): skip the <code>Stop</code> call in <method>OcuPilot.Port.InteropPort.VendorJob</method> -- the job-row leg here goes red;
/// drop <code>AuditRuntime</code> from the stop branch of <method>OcuPilot.Port.InteropPort.PerformJobAction</method> -- the audit leg goes red.</p>
Method TestTheAgentsStopEndsTheJobAndTheUpdateStartsItAgain()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs")
    Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tRow) && 'tRow.Dead, "the plain operation has a live job")
    If '$IsObject(tRow) Quit
    Set tJob = tRow.Job
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tMark = ..LastLogRow()
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "nothing is pending")
    Do ..Through(tJob, "[{""field"":""Status"",""before"":""" _ tRow.Status _ """,""after"":""Stopped""}]")
    Do $$$AssertEquals(..Listed(tJob), 0, "the job's row left the Jobs list")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|1", "and the production reads an update pending")
    Do $$$AssertEquals(..StoppingRows(tMark), 1, "the vendor logged one Stopping job line")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "stop", .tData), 1, "one OcuPilot audit row names the stop of the job")
    Do $$$AssertTrue((tData [ """namespace"":""USER""") && (tData [ """host"":""" _ ..#OPNAME _ """"), "naming the namespace and the host: " _ tData)
    Do $$$AssertEquals(..UpdateStartsAJob(), "200 |job|Running|0", "Story 20.2's confirmed Update starts a job again and the production reads up to date")
}

/// <p>AC4: the person's Stop job on the Jobs list's route (an item's Jobs tab posts to the same route) answers 200 with the
/// <code>deleted</code> event for the job and a read-back that finds it gone, ends the job, and leaves one audit row; no agent marker is
/// emitted for a person, and governance does not gate a person's action.</p>
/// <p>Mutation (Rule 19): drop <code>AuditRuntime</code> from the stop branch of <method>OcuPilot.Port.InteropPort.PerformJobAction</method> -- the audit
/// leg goes red.</p>
Method TestThePersonsStopFromTheJobsRoute()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs")
    Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tRow) && 'tRow.Dead, "the plain operation has a live job")
    If '$IsObject(tRow) Quit
    Set tJob = tRow.Job
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = $ClassMethod(..#JOBS, "Act", "stop", tJob, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "Stop job answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, "deleted|interop-job|USER|" _ tJob _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTFOUND, "publishing the deleted event for the job")
    }
    Do $$$AssertEquals(..Listed(tJob), 0, "the job's row left the Jobs list")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|1", "and the production reads an update pending")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "stop", .tData), 1, "one audit row names the stop")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", tJob, .tMarker), 0, "and no agent marker is emitted for a person's action")
}

/// <p>AC4, AC5: a job hung on a message does not stop within a shortened wait, so the stop forces it: the call passes the production's
/// timeout capped at <code>StopSeconds</code> (shortened to two seconds through the seam, and not the ten of a stock production), takes about
/// that long, puts the job's message back on its queue, leaves its host reading <code>Error</code> and the production reading an update
/// pending, and the confirmed Update starts a job again. The wall clock is recorded in the assertion text.</p>
/// <p>Mutation (Rule 19): pass <code>0</code> as the force argument of <code>Stop</code> in <method>OcuPilot.Port.InteropPort.VendorJob</method> -- the
/// vendor refuses the stop (<code>INTEROP.JOB.NOTSTOPPED</code>), the message is not put back, and this goes red; ignore
/// <code>StopSeconds()</code> there -- the wall-clock leg goes red.</p>
Method TestAStopOfAHungJobIsForcedAndPutsItsMessageBack()
{
    Do $$$AssertStatusOK($ClassMethod(..#READ, "ArmProbe", .tIds), "the probe's operation is hung on one message with two waiting")
    Set tHeld = $Piece(tIds, ",", 1)
    Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tRow) && (tRow.ActiveMessage = tHeld), "the operation's job holds the first message")
    If '$IsObject(tRow) Quit
    Set tJob = tRow.Job
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..HoldPairs()
    Do $ClassMethod(..#SEAM, "Shorten", ..#SHORTWAIT)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tJob
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "STOPJOB", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tTook = $ZHorolog - tStart
    Do $ClassMethod(..#SEAM, "Restore")
    Do $$$AssertEquals(+$Get(tHttp), 200, "the stop is answered: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertTrue((tTook >= (..#SHORTWAIT - 0.5)) && (tTook < 8), "it waited about the shortened " _ ..#SHORTWAIT _ " seconds, not the production's ten: " _ $FNumber(tTook, "", 2) _ " s")
    Do $$$AssertEquals($ClassMethod(..#READ, "QueueCount"), 3, "the job's message is back on the queue beside the two waiting")
    Do $$$AssertTrue($ListFind($ListFromString($ClassMethod(..#QUEUES, "Entries", ..#OPNAME, 1)), tHeld), "and it is the first message")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("maxRows") = 1000
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Monitor", "LIST", .tQuery, "", .tHosts, .tHostHttp, .tHostFault)
    Set tWord = ""
    If $IsObject($Get(tHosts)) {
        Set tIterator = tHosts.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tHost) {
            If tHost.Name = ..#OPNAME Set tWord = tHost.Status
        }
    }
    Do $$$AssertEquals(tWord, "Error", "the operation's host reads Error")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|1", "and the production reads an update pending")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "stop", .tData), 1, "one audit row names the stop")
    Do $$$AssertEquals(..UpdateStartsAJob(), "200 |job|Running|0", "the confirmed Update starts a job again")
}

/// <p>AC4: a stop the vendor refuses is answered in the port's own words: <code>&lt;Ens&gt;ErrJobNotStopped</code> is 409
/// <code>INTEROP.JOB.NOTSTOPPED</code>, and the request lock and the status lock the vendor takes on a job are 503
/// <code>PORT.UNAVAILABLE</code>. The vendor answers each only under load or a held lock, so the seam names the status in place of the vendor
/// call; no audit row is left for a stop the vendor refused.</p>
/// <p>Mutation (Rule 19): drop the <code>NOTSTOPPED</code> line from <method>OcuPilot.Port.InteropPort.JobStatused</method> -- the status falls
/// to <method>OcuPilot.Port.InteropPort.Statused</method>, which answers it as a busy production, and the first leg goes red; drop its lock line --
/// the two lock legs go red.</p>
Method TestAStopTheVendorRefusesIsAnsweredInThePortsOwnWords()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs")
    Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tRow) && 'tRow.Dead, "the plain operation has a live job")
    If '$IsObject(tRow) Quit
    Set tJob = tRow.Job
    Do ..HoldPairs()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCodes = $ListBuild("<Ens>ErrJobNotStopped", "<Ens>ErrCanNotAcquireJobLock", "<Ens>ErrJobStatusLocked")
    Set tWant = $ListBuild("409 INTEROP.JOB.NOTSTOPPED", "503 PORT.UNAVAILABLE", "503 PORT.UNAVAILABLE")
    For tI = 1:1:$ListLength(tCodes) {
        Do $ClassMethod(..#SEAM, "RefuseJobWith", $List(tCodes, tI))
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = tJob
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "STOPJOB", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), $List(tWant, tI), "the vendor's " _ $List(tCodes, tI) _ " is answered " _ $List(tWant, tI))
    }
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tJob, "stop", .tData), 0, "and no audit row names a stop the vendor refused")
}

/// <p>AC4: a stop of a job whose process has ended is refused 409 <code>INTEROP.JOB.DEAD</code>, and a stop of a pid no job of the running
/// production holds is 404 <code>PORT.NOTFOUND</code>, at the port, at the mint and on the person's route, each before the vendor is called,
/// so the event log gets no <code>Stopping job</code> line and no audit row is written; nothing is logged as a fault.</p>
/// <p>Mutation (Rule 19): drop <code>DEAD</code> from <method>OcuPilot.Port.InteropPort.RuntimeRefusal</method> -- the dead leg goes red, a Stopping job
/// row appearing; make the <code>JOB</code> read answer a pid it did not find -- the 404 leg goes red the same way.</p>
Method TestADeadOrAbsentJobIsRefusedBeforeTheVendorIsCalled()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs")
    Set tDead = $ClassMethod(..#JOBS, "TerminatedJob", ..#OPNAME, .tWhy)
    Do $$$AssertNotEquals(tDead, "", tWhy)
    If tDead = "" Quit
    Do ..HoldPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tMark = ..LastLogRow()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tDead
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "STOPJOB", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "409 INTEROP.JOB.DEAD|" _ ##class(OcuPilot.Api.InteropError).#REASONJOBDEAD, "a stop of the dead job is refused for it")
    Set tQuery("action") = "STOPJOB"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "JOB", .tQuery, "", .tRead, .tReadHttp, .tReadFault)
    Do $$$AssertEquals(+$Get(tReadHttp) _ " " _ $Select($IsObject($Get(tReadFault)): tReadFault.%Get("code"), 1: ""), "409 INTEROP.JOB.DEAD", "so is the read composed for a stop, which is what the mint answers")
    Do $$$AssertEquals($ClassMethod(..#JOBS, "Act", "stop", tDead, .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 INTEROP.JOB.DEAD", "and the person's Stop job")
    Set tQuery("id") = "999999"
    Kill tQuery("action")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Jobs", "STOPJOB", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "a stop of a pid no job holds is not found")
    Do $$$AssertEquals($ClassMethod(..#JOBS, "Act", "stop", "999999", .tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "and the person's Stop job")
    Do $$$AssertEquals(..StoppingRows(tMark), 0, "no Stopping job line reached the event log")
    Do $$$AssertEquals($ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", tDead, "stop", .tData) + $ClassMethod(..#QUEUES, "AuditRows", tSince, "interop-job", "999999", "stop", .tMore), 0, "and no audit row names either")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "nothing was logged as a fault")
}

/// <p>The seam <class>OcuPilot.Test.InteropJobEnd</class> calls with the process id of the job it just terminated: wait for that process
/// to end, change the plain operation's setting so that the update has work to do, update the probe production in <code>USER</code>, and
/// record the process id in <code>^||OcuPilotJobEndFirst</code> and, in <code>^||OcuPilotJobEndDropped</code>, 1 when the setting and
/// the update succeeded and the Jobs list then holds no row under that process id, 0 when it holds one, and the error text when either
/// call failed.</p>
ClassMethod UpdateOnceGone(pPid As %String)
{
    Set ^||OcuPilotJobEndFirst = pPid
    Set ^||OcuPilotJobEndDropped = 0
    For tTry = 1:1:200 {
        If '$Data(^$JOB(pPid)) Quit
        Hang 0.05
    }
    Set tSC = $ClassMethod(..#PROBE, "SetHang", 1)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If $$$ISOK(tSC) Set tSC = ##class(Ens.Director).UpdateProduction()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set ^||OcuPilotJobEndDropped = $System.Status.GetErrorText(tSC) Quit
    Set tCount = ##class(OcuPilot.Test.InteropJobEnd).HostRows(..#OPNAME, .tRows)
    Set ^||OcuPilotJobEndDropped = 1
    For tI = 1:1:tCount {
        If tRows(tI).Job = pPid Set ^||OcuPilotJobEndDropped = 0
    }
}

/// <p>A job whose row the production drops after its process ends, and that it replaces with a live job some moments later, is not the end
/// of the premise: <class>OcuPilot.Test.InteropJobEnd</class> terminates the replacement in its turn and answers a dead id, a later job's
/// and not the first job's ghost. The update runs once the first job's process is gone, through the helper's seam.</p>
/// <p>Mutation (Rule 19): set <class>OcuPilot.Test.InteropJobEnd</class>'s <parameter>ATTEMPTS</parameter> to 1 -- this test goes red,
/// the helper answering <code>""</code> and saying that a live job replaced the terminated one.</p>
Method TestAJobTheProductionReplacesIsEndedInItsTurn()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs")
    Kill ^||OcuPilotJobEndDropped, ^||OcuPilotJobEndFirst
    Set tDead = ##class(OcuPilot.Test.InteropJobEnd).Terminated(..#OPNAME, .tWhy, ..%ClassName(1) _ ":UpdateOnceGone")
    Set tFirst = $Get(^||OcuPilotJobEndFirst)
    Do $$$AssertEquals($Get(^||OcuPilotJobEndDropped), 1, "the update ran and dropped the terminated job's row")
    Kill ^||OcuPilotJobEndDropped, ^||OcuPilotJobEndFirst
    Do $$$AssertNotEquals(tDead, "", tWhy)
    Do $$$AssertTrue((tFirst '= "") && (tDead '= tFirst) && ($Extract(tDead, 1, $Length(tFirst) + 2) '= ("Z" _ tFirst _ "_")), "the dead id " _ tDead _ " is a later job's, not the first job " _ tFirst _ "'s")
}

/// <p>A start whose own update has not run is not acted on: the production is started while this process holds the vendor's runtime lock in
/// <code>USER</code>, which its schedule handler's update waits on, so no update is logged after the start, and
/// <class>OcuPilot.Test.InteropJobEnd</class> terminates nothing and refuses the premise by name after its wait.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Test.InteropJobEnd</class>'s <method>StartUpdated</method> answer 1 at once -- this test goes
/// red, the job being terminated and a dead id answered.</p>
Method TestAStartWhoseOwnUpdateHasNotRunIsNotActedOn()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ResetProduction"), "the probe production is as it was made")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Lock +^Ens.Runtime:5
    Set tLocked = $Test
    Set $NAMESPACE = tOrigNS
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tDead = ##class(OcuPilot.Test.InteropJobEnd).Terminated(..#OPNAME, .tWhy)
    Set tRow = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Set $NAMESPACE = ..#NAMESPACE
    If tLocked Lock -^Ens.Runtime
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tLocked, "this process held the runtime lock across the start")
    Do $$$AssertStatusOK(tSC, "the probe production starts")
    Do $$$AssertEquals(tDead, "", "no dead id is answered before the start's own update has run")
    Do $$$AssertTrue(tWhy [ "logged no update", "the premise is refused naming the missing update, not: " _ tWhy)
    Do $$$AssertTrue($IsObject(tRow) && 'tRow.Dead, "and the plain operation's job was not terminated")
}

/// <p>A production that reads Troubled and lists no live job of the host is refused as the premise, naming Troubled, at once.</p>
/// <p>Mutation (Rule 19): change <class>OcuPilot.Test.InteropJobEnd</class>'s <parameter>TROUBLED</parameter> to 5 -- this test goes red,
/// the sentence naming the state number after twenty seconds.</p>
Method TestATroubledProductionRefusesTheDeadJobPremiseByName()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeTroubled"), "the production reads Troubled")
    Set tStart = $ZHorolog
    Set tDead = ##class(OcuPilot.Test.InteropJobEnd).Terminated(..#OPNAME, .tWhy)
    Do $$$AssertEquals(tDead, "", "no dead id is answered for a Troubled production")
    Do $$$AssertTrue(tWhy [ "Troubled", "the premise is refused naming Troubled, not: " _ tWhy)
    Do $$$AssertTrue($ZHorolog - tStart < 10, "and at once, not after the wait")
}

}

/// <p>Pins Story 20.25's three item runtime writes end to end against a probe production in <code>USER</code> (AD-6, AD-7, AD-15,
/// AD-22, AD-51, AD-53, AD-58, AD-59, AD-62): the agent's stop, start and restart minted and confirmed over HTTP; the person's row
/// actions writing the same way; the item's Jobs tab reading no job after a stop and a job after a start; every refusal of the
/// matrix answered by its own code before any vendor call; a stop whose update the production cannot finish undone, and a start whose
/// update cannot finish left pending; and each tool's script.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and <b>runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>) and removes it after the last test. Auditing of
/// <code>%Ensemble/%Production/ModifyConfiguration</code> must be on, as the throwaway's is. One class per run.</p>
Class OcuPilot.Test.InteropItemRun Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

/// <p>Story 20.3's control test, whose mint, confirm, audit and reset helpers this class shares.</p>
Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PRODUCTIONS = "OcuPilot.Test.InteropControl";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter JOBS = "OcuPilot.Test.InteropJobActions";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter OPNAME = "OcuPilotProbeOp";

Parameter SVCNAME = "OcuPilotProbeSvc";

Parameter POOLZERONAME = "OcuPilotProbeProc0";

Parameter OFFNAME = "OcuPilotProbeOff";

Parameter NEWNAME = "OcuPilotProbeNew";

Parameter OPCLASS = "OcuPilotProbe.Interop.Op";

Parameter TOOLS = "OcuPilot.Screen.Tool.InteropItemStop,OcuPilot.Screen.Tool.InteropItemStart,OcuPilot.Screen.Tool.InteropItemRestart";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemRun compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemRun left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#SEAM, "Restore")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Quit $ClassMethod(..#CONTROL, "Reset")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#SEAM, "Restore")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "Reset"), "the probe production is left stopped with its items as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Declare the pairs of a principal who reads and acts on items' runtime, for the calls through
/// <class>OcuPilot.Test.InteropGateSeam</class>'s fake gate.</p>
ClassMethod HoldPairs()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ConfigItemRun", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p>Start the probe production through the port, with the items <var>pExtras</var> (a <code>%List</code> of
/// <code>$ListBuild(name, class, pool size, enabled)</code>) stored first, and wait for the plain operation's job.</p>
Method StartProbe(pExtras As %List = "") As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    For tI = 1:1:$ListLength(pExtras) {
        If $$$ISERR(tSC) Quit
        Set tItem = $List(pExtras, tI)
        Set tSC = $ClassMethod(..#PROBE, "AddItem", $List(tItem, 1), $List(tItem, 2), $List(tItem, 3), $List(tItem, 4))
    }
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Quit ..WaitJobs(1)
}

/// <p>Wait, ten seconds at most, until the plain operation's Jobs tab lists at least <var>pWant</var> jobs (0 waits until it lists
/// none); a failing status when it never does.</p>
ClassMethod WaitJobs(pWant As %Integer) As %Status
{
    For tTry = 1:1:20 {
        Set tCount = ..JobsTab()
        If $Select(pWant = 0: tCount = 0, 1: tCount >= pWant) Quit
        Hang 0.5
    }
    Quit $Select($Select(pWant = 0: tCount = 0, 1: tCount >= pWant): $$$OK, 1: $$$ERROR($$$GeneralError, "the Jobs tab lists " _ tCount _ " jobs, not " _ pWant))
}

/// <p>How many jobs the plain operation's Jobs tab lists, read through its screen; -1 when the read fails.</p>
ClassMethod JobsTab() As %Integer
{
    Kill tCriteria
    Set tCriteria("item") = $ClassMethod(..#CONTROL, "IdOf", ..#OPNAME)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.InteropItemJobTab", 1000, .tAnswer, .tHttp, .tFault, .tCriteria)
    Quit $Select((+$Get(tHttp) = 200) && $IsObject($Get(tAnswer)): tAnswer.rows.%Size(), 1: -1)
}

/// <p>The runtime facts of <var>pName</var> as the port's <code>ITEMRUN</code> reads them, <code>enabled stopped own jobs
/// needs</code> as <code>name=value</code> pairs; the refusal's code when the read is refused.</p>
ClassMethod Facts(pName As %String = {..#OPNAME}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", pName)
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Items", "ITEMRUN", .tQuery, "", .tRow, .tHttp, .tFault)
    If '$IsObject($Get(tRow)) Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    Quit "enabled=" _ +tRow.Enabled _ " stopped=" _ +tRow.TemporarilyStopped _ " own=" _ +tRow.OwnJobs _ " jobs=" _ tRow.Jobs _ " needs=" _ +tRow.NeedsUpdate
}

/// <p>One call of <var>pType</var> on the item <var>pName</var> through <class>OcuPilot.Test.InteropItemSeam</class>; its HTTP status and the
/// wire fault's code, <code>"200 "</code> for an answer.</p>
ClassMethod Port(pType As %String, pName As %String = {..#OPNAME}, pNamespace As %String = {..#NAMESPACE}, pProduction As %String = {..#PRODUCTION}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pProduction _ $Char(1) _ pName
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Items", pType, .tQuery, "", .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for the plain operation as the HTTP account and confirm it over HTTP: the card's one
/// <code>TemporarilyStopped</code> row (<var>pBefore</var> to <var>pAfter</var>), the consequence code, that it is not destructive, the
/// single envelope the confirm answers, its marker, its ledger row, and the vendor's audit rows since the mint, in <var>pAudit</var>.</p>
Method Through(pTool As %String, pBefore As %String, pAfter As %String, pConsequence As %String, Output pAudit As %String)
{
    Set tName = $Parameter(pTool, "TOOLNAME")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, $ClassMethod(..#CONTROL, "ArgsFor", ..#OPNAME), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, tName _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%ToJSON(), "[{""field"":""TemporarilyStopped"",""before"":""" _ pBefore _ """,""after"":""" _ pAfter _ """}]", tName _ ": its card shows the item's stopped flag, from " _ tProposal.changed.%ToJSON())
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "production-item|USER|" _ ..#PRODUCTION _ "~" _ ..#OPNAME, tName _ ": the target is the item, by its composite id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), pConsequence _ "|0", tName _ ": its consequence code, and it is not destructive")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, tName _ " confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), tName _ ": the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|updated", tName _ ": updated and marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, tName), 1, tName _ ": the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set pAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
}

/// <p>AC1, AC3, AC4: the agent's stop of the plain operation, minted and confirmed over HTTP, ends its jobs -- the item's Jobs tab lists
/// none, the flag reads set, the item stays enabled and the production reads up to date -- and its start then runs a job again; the card
/// shows the flag moving, neither is destructive, and the vendor's audit row of each names the item.</p>
/// <p>Mutation (Rule 19): skip the <code>UpdateCapped</code> call in the stop half of
/// <method>OcuPilot.Port.InteropPort.PerformItemRun</method> -- the stop's job leg goes red.</p>
Method TestTheAgentsStopAndStartConfirmOverHttp()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs with the operation's job")
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "the operation runs a job of its own and is not stopped")
    Do ..Through("OcuPilot.Screen.Tool.InteropItemStop", "false", "true", "INTEROP.ITEM.STOP", .tAudit)
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeOp of OcuPilotProbe.Interop.Production") && (tAudit [ "item temporary stop by"), "the vendor's audit row of the stop names the item: " _ tAudit)
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=1 own=0 jobs=0 needs=0", "the item is stopped, still enabled, with no job, and nothing is pending")
    Do $$$AssertEquals(..JobsTab(), 0, "its Jobs tab lists no job")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTIONS, "State"), "Running|0", "and the production reads up to date")
    Do ..Through("OcuPilot.Screen.Tool.InteropItemStart", "true", "false", "INTEROP.ITEM.START", .tAudit)
    Do $$$AssertTrue((tAudit [ "item OcuPilotProbeOp of OcuPilotProbe.Interop.Production") && (tAudit [ "restarted after temporary stop"), "the vendor's audit row of the start names the item: " _ tAudit)
    Do $$$AssertStatusOK(..WaitJobs(1), "its Jobs tab lists a job again")
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "and the flag is clear")
}

/// <p>AC1, AC4: the agent's restart of the plain operation ends its job and starts another: the flag reads clear, the job's process id
/// differs, the card shows the flag staying clear, and the vendor audits the stop and the start.</p>
/// <p>Mutation (Rule 19): omit the start half of <method>OcuPilot.Port.InteropPort.PerformItemRun</method> for a restart -- the flag and job
/// legs go red.</p>
Method TestTheAgentsRestartConfirmsOverHttp()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs with the operation's job")
    Set tBefore = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tBefore), "the operation has a job")
    If '$IsObject(tBefore) Quit
    Do ..Through("OcuPilot.Screen.Tool.InteropItemRestart", "false", "false", "INTEROP.ITEM.RESTART", .tAudit)
    Do $$$AssertTrue((tAudit [ "item temporary stop by") && (tAudit [ "restarted after temporary stop"), "the vendor audited the stop and the start: " _ tAudit)
    Do $$$AssertStatusOK(..WaitJobs(1), "the operation's Jobs tab lists a job again")
    Set tAfter = $ClassMethod(..#JOBS, "JobOf", ..#OPNAME)
    Do $$$AssertTrue($IsObject(tAfter) && (tAfter.Job '= tBefore.Job), "and it is another process than before")
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "the flag is clear and nothing is pending")
}

/// <p>AC1, AC4: the person's row actions Stop, Start and Restart on the Production items route answer 200 with the <code>updated</code>
/// event for the item and write as the agent's do; no agent marker is emitted for a person.</p>
/// <p>Mutation (Rule 19): drop <code>stop</code> from <parameter>OcuPilot.Screen.Tool.InteropItemStop.SCREENACTIONS</parameter> -- the
/// first leg goes red.</p>
Method TestThePersonsRowActionsStopStartAndRestart()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs with the operation's job")
    Set tId = $ClassMethod(..#CONTROL, "IdOf", ..#OPNAME)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tCase = $ListBuild("stop", "enabled=1 stopped=1 own=0 jobs=0 needs=0"), $ListBuild("start", "enabled=1 stopped=0 own=1 jobs=1 needs=0"), $ListBuild("restart", "enabled=1 stopped=0 own=1 jobs=1 needs=0") {
        Set tText = $ClassMethod(..#CONTROL, "Act", $List(tCase, 1), ..#OPNAME, .tAnswer)
        Do $$$AssertEquals(tText, "200 ", $List(tCase, 1) _ " answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ $Translate(tAnswer.target.id, $Char(1), "~"), 1: ""), "updated|production-item|" _ ..#PRODUCTION _ "~" _ ..#OPNAME, $List(tCase, 1) _ ": publishing the updated event for the item")
        If $List(tCase, 1) '= "stop" Do $$$AssertStatusOK(..WaitJobs(1), $List(tCase, 1) _ ": the Jobs tab lists a job")
        Do $$$AssertEquals(..Facts(), $List(tCase, 2), $List(tCase, 1) _ ": the item reads as the action leaves it")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#OPNAME, .tMarker), 0, "and no agent marker is emitted for a person's action")
}

/// <p>AC2: every refusal of the matrix is answered by its own code, 409 (404 for an unknown item or production), at the port and on the
/// read the mint composes, before any vendor call: no audit row is written, nothing is logged as a fault, and the flag and the job are as
/// they were. A production that is not running, a disabled item, a start of an item not stopped, a stop or restart of an item already
/// stopped or running no jobs of its own (an adapterless service and a pool-size-0 process), a name held twice and a namespace that does
/// not report interoperability are each shown.</p>
/// <p>Mutation (Rule 19): drop <code>NOTRUNNING</code> from <method>OcuPilot.Port.InteropPort.ItemRunRefusal</method> -- the stopped-production
/// leg goes red, the vendor's silent success reaching the audit; drop <code>NOTTEMPSTOPPED</code> -- the start-not-stopped leg goes red.</p>
Method TestEachRefusalIsMadeByNameBeforeAnyVendorCall()
{
    Do ..HoldPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tType = "STOPITEM", "STARTITEM", "RESTARTITEM" {
        Do $$$AssertEquals(..Port(tType), "409 INTEROP.PRODUCTION.NOTRUNNING", tType _ " of an item of a production that is not running is refused for it")
    }
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Audited", tSince), "", "the vendor's silent success on a stopped production was not reached: no audit row")
    Do $$$AssertStatusOK(..StartProbe($ListBuild($ListBuild(..#OFFNAME, ..#OPCLASS, 1, 0), $ListBuild(..#POOLZERONAME, "EnsLib.MsgRouter.RoutingEngine", 0, 1))), "the probe runs, with a disabled item and a pool-size-0 process stored")
    Do $$$AssertEquals(..Facts(..#POOLZERONAME), "enabled=1 stopped=0 own=0 jobs=0 needs=0", "the pool-size-0 process runs no job of its own")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tCase = $ListBuild("STOPITEM", ..#OFFNAME, "409 INTEROP.ITEM.NOTENABLED"), $ListBuild("STARTITEM", ..#OFFNAME, "409 INTEROP.ITEM.NOTENABLED"), $ListBuild("RESTARTITEM", ..#OFFNAME, "409 INTEROP.ITEM.NOTENABLED"), $ListBuild("STARTITEM", ..#OPNAME, "409 INTEROP.ITEM.NOTTEMPSTOPPED"), $ListBuild("STOPITEM", ..#SVCNAME, "409 INTEROP.ITEM.NOJOBS"), $ListBuild("RESTARTITEM", ..#SVCNAME, "409 INTEROP.ITEM.NOJOBS"), $ListBuild("STOPITEM", ..#POOLZERONAME, "409 INTEROP.ITEM.NOJOBS"), $ListBuild("RESTARTITEM", ..#POOLZERONAME, "409 INTEROP.ITEM.NOJOBS"), $ListBuild("STARTITEM", ..#SVCNAME, "409 INTEROP.ITEM.NOTTEMPSTOPPED"), $ListBuild("STOPITEM", "OcuPilotProbeNoSuch", "404 PORT.NOTFOUND"), $ListBuild("RESTARTITEM", "OcuPilotProbeNoSuch", "404 PORT.NOTFOUND") {
        Do $$$AssertEquals(..Port($List(tCase, 1), $List(tCase, 2)), $List(tCase, 3), $List(tCase, 1) _ " of " _ $List(tCase, 2))
    }
    Do $$$AssertEquals(..Port("STOPITEM", ..#OPNAME, ..#NAMESPACE, "OcuPilotProbe.No.Such"), "404 PORT.NOTFOUND", "an item of an unknown production is not found")
    Do $$$AssertEquals(..Port("STOPITEM", ..#OPNAME, "%SYS"), "409 INTEROP.NAMESPACE", "a namespace that does not report interoperability is refused for it")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", ..#SVCNAME)
    Set tQuery("action") = "STOPITEM"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Items", "ITEMRUN", .tQuery, "", .tRead, .tReadHttp, .tReadFault)
    Do $$$AssertEquals(+$Get(tReadHttp) _ " " _ $Select($IsObject($Get(tReadFault)): tReadFault.%Get("code"), 1: ""), "409 INTEROP.ITEM.NOJOBS", "the read composed for a stop, which is what the mint answers, refuses the same way")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Audited", tSince), "", "no vendor audit row was written for any refusal")
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "and the operation's flag and job are as they were")
    ; An item already stopped, then a name held twice.
    Do $$$AssertEquals(..Port("STOPITEM"), "200 ", "the operation is stopped")
    Do $$$AssertEquals(..Port("STOPITEM") _ "|" _ ..Port("RESTARTITEM"), "409 INTEROP.ITEM.TEMPSTOPPED|409 INTEROP.ITEM.TEMPSTOPPED", "a stop and a restart of an item already stopped are refused for it")
    Do $$$AssertEquals(..Port("STARTITEM"), "200 ", "and its start is admitted")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#OPNAME, ..#OPCLASS, 1, 1), "a second item of the operation's name is stored")
    For tType = "STOPITEM", "STARTITEM", "RESTARTITEM" {
        Do $$$AssertEquals(..Port(tType), "409 INTEROP.ITEM.AMBIGUOUS", tType _ " of a name held twice is refused for it")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "nothing was logged as a fault")
}

/// <p>AC1, AC2: a stop or a restart whose update the production cannot finish -- a job hung on a message past the wait, shortened to two
/// seconds through the seam -- is answered 409 <code>INTEROP.PRODUCTION.BUSY</code> and leaves nothing changed: the flag reads clear, the
/// job still runs and no update is pending; the vendor audits the flag set and cleared.</p>
/// <p>Mutation (Rule 19): skip the flag restore in <method>OcuPilot.Port.InteropPort.PerformItemRun</method> -- the flag leg goes red.</p>
Method TestAStopThePortCannotFinishIsUndone()
{
    Do ..HoldPairs()
    Do $$$AssertStatusOK($ClassMethod(..#READ, "ArmProbe", .tIds), "the probe's operation is hung on one message with two waiting")
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "the operation runs its hung job and nothing is pending")
    Do $ClassMethod(..#SEAM, "Shorten", 2)
    For tType = "STOPITEM", "RESTARTITEM" {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Do $$$AssertEquals(..Port(tType), "409 INTEROP.PRODUCTION.BUSY", tType _ " is refused as the production's work in progress did not finish")
        Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", tType _ " left the flag clear, the job running and nothing pending")
        Set tAudit = $ClassMethod(..#CONTROL, "Audited", tSince)
        Do $$$AssertTrue((tAudit [ "item temporary stop by") && (tAudit [ "restarted after temporary stop"), tType _ ": the vendor audited the flag set and cleared: " _ tAudit)
    }
}

/// <p>AC1: a start whose update the production does not finish -- the seam answers the vendor's refusal -- is answered 409
/// <code>INTEROP.ITEM.STARTPENDING</code>, leaves the flag clear, and, with another change waiting, the production still reads an update
/// pending, which the Productions screen's Update applies, starting both; the same refusal at a restart's second update leaves the item
/// stopped by its first half and the flag clear.</p>
/// <p>Mutation (Rule 19): answer <code>BUSY</code> for a failed start half in <method>OcuPilot.Port.InteropPort.PerformItemRun</method> -- both
/// legs go red.</p>
Method TestAStartThePortCannotFinishIsPending()
{
    Do ..HoldPairs()
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs with the operation's job")
    Do $$$AssertEquals(..Port("STOPITEM"), "200 ", "the operation is stopped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", ..#NEWNAME, ..#OPCLASS, 1, 1), "another change is left waiting for the production: an enabled item")
    Do $ClassMethod(..#SEAM, "RefuseUpdateWith", "<Ens>ErrProductionNotQuiescent", 1)
    Do $$$AssertEquals(..Port("STARTITEM"), "409 INTEROP.ITEM.STARTPENDING", "a start whose update is refused is pending")
    Do $ClassMethod(..#SEAM, "Disarm")
    Set tFacts = ..Facts()
    Do $$$AssertEquals(tFacts, "enabled=1 stopped=0 own=0 jobs=0 needs=1", "the flag is clear, no job runs yet and an update is pending: " _ tFacts)
    Set tText = $ClassMethod(..#PRODUCTIONS, "Act", "update", ..#PRODUCTION)
    Do $$$AssertEquals(tText, "200 ", "the Productions screen's Update answers 200: " _ tText)
    Do $$$AssertStatusOK(..WaitJobs(1), "and the item's job runs")
    Do $$$AssertEquals(..Facts(..#NEWNAME), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "beside the item the other change added")
    Do $ClassMethod(..#SEAM, "RefuseUpdateWith", "<Ens>ErrProductionNotQuiescent", 2)
    Set tText = ..Port("RESTARTITEM")
    Do $$$AssertEquals(tText, "409 INTEROP.ITEM.STARTPENDING", "a restart whose second update is refused is pending: " _ tText)
    Do $ClassMethod(..#SEAM, "Disarm")
    Set tFacts = ..Facts()
    Do $$$AssertTrue(tFacts [ "stopped=0 own=0 jobs=0", "its first half ended the job and the flag is clear: " _ tFacts)
}

/// <p>AC2: <method>OcuPilot.Port.InteropPort.ItemRunRefusal</method> judges in the matrix's order -- the production, the name, the item's
/// <code>Enabled</code>, then the flag and the item's own jobs for a stop or a restart, or the flag alone for a start -- and
/// <method>OcuPilot.Port.InteropPort.ItemRunCode</method> gives each token its code.</p>
/// <p>Mutation (Rule 19): swap the <code>TEMPSTOPPED</code> and <code>NOJOBS</code> lines -- a stopped item (which reads no job of its own)
/// is refused <code>NOJOBS</code>, and the order rows go red.</p>
Method TestTheRefusalsAreJudgedInTheMatrixOrder()
{
    For tCase = $ListBuild("STOPITEM", 1, 1, 1, 0, 1, ""), $ListBuild("STOPITEM", 1, 0, 1, 0, 1, "NOTRUNNING"), $ListBuild("STOPITEM", 2, 1, 1, 0, 1, "AMBIGUOUS"), $ListBuild("STOPITEM", 2, 0, 1, 0, 1, "NOTRUNNING"), $ListBuild("STOPITEM", 1, 1, 0, 0, 1, "NOTENABLED"), $ListBuild("STOPITEM", 1, 1, 1, 1, 1, "TEMPSTOPPED"), $ListBuild("STOPITEM", 1, 1, 1, 1, 0, "TEMPSTOPPED"), $ListBuild("STOPITEM", 1, 1, 1, 0, 0, "NOJOBS"), $ListBuild("STARTITEM", 1, 1, 1, 0, 1, "NOTTEMPSTOPPED"), $ListBuild("STARTITEM", 1, 1, 1, 1, 0, ""), $ListBuild("STARTITEM", 1, 1, 0, 1, 1, "NOTENABLED"), $ListBuild("RESTARTITEM", 1, 1, 1, 1, 1, "TEMPSTOPPED"), $ListBuild("RESTARTITEM", 1, 1, 1, 0, 0, "NOJOBS"), $ListBuild("RESTARTITEM", 1, 1, 1, 0, 1, "") {
        Set tGot = $ClassMethod(..#PORT, "ItemRunRefusal", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), $List(tCase, 5), $List(tCase, 6))
        Do $$$AssertEquals(tGot, $List(tCase, 7), $List(tCase, 1) _ " count " _ $List(tCase, 2) _ " running " _ $List(tCase, 3) _ " enabled " _ $List(tCase, 4) _ " stopped " _ $List(tCase, 5) _ " own jobs " _ $List(tCase, 6))
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "ItemRunCode", "NOTRUNNING") _ "|" _ $ClassMethod(..#PORT, "ItemRunCode", "NOJOBS") _ "|" _ $ClassMethod(..#PORT, "ItemRunCode", ""), "INTEROP.PRODUCTION.NOTRUNNING|INTEROP.ITEM.NOJOBS|", "each token has its code")
}

/// <p>AD-59: each tool's copy-out draft renders one ObjectScript step that switches to the namespace the proposal read and calls the vendor's
/// temporary stop and the production's update, closes the proposal as a draft and changes nothing; none names <code>CleanProduction</code>,
/// <code>EnableConfigItem</code> or an update inside the temporary stop.</p>
/// <p>Mutation (Rule 19): render a restart's script without its start -- the restart row goes red; render a start's script with the flag set (<code>1, 0</code>) -- the start rows go red.</p>
Method TestEachToolsDraftRendersItsScript()
{
    Do $$$AssertStatusOK(..StartProbe(), "the probe production runs with the operation's job")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tConfig = """" _ ..#PRODUCTION _ "||" _ ..#OPNAME _ """"
    For tCase = $ListBuild("InteropItemStop", 1, 1), $ListBuild("InteropItemRestart", 1, 2) {
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", tTool, $ClassMethod(..#CONTROL, "ArgsFor", ..#OPNAME), tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If '$IsObject($Get(tProposal)) Continue
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, tUser, "https://draft.example:52773", .tDraft, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, $Parameter(tTool, "TOOLNAME") _ ": the draft is taken: " _ $Get(tCode))
        If '$IsObject($Get(tDraft)) Continue
        Set tText = tDraft.draft.steps.%Get(0).text
        Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", $Parameter(tTool, "TOOLNAME") _ ": an ObjectScript draft that closes the proposal")
        Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ ("TempStopConfigItem(" _ tConfig _ ", 1, 0)")) && (tText [ "UpdateProduction(tTimeout, 0)") && (tText '[ "CleanProduction") && (tText '[ "EnableConfigItem") && (tText '[ "SaveToClass"), $Parameter(tTool, "TOOLNAME") _ ": " _ tText)
        Do $$$AssertEquals($Length(tText, "TempStopConfigItem(" _ tConfig _ ", 0, 0)") - 1, $List(tCase, 3), $Parameter(tTool, "TOOLNAME") _ ": the flag is cleared once by a refused stop's restore, and a second time by a restart's start")
    }
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "no draft changed the item")
    Do ..HoldPairs()
    Do $$$AssertEquals(..Port("STOPITEM"), "200 ", "the operation is stopped, so a start can be minted")
    Kill tProposal, tDraft, tFault
    Set tTool = "OcuPilot.Screen.Tool.InteropItemStart"
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", tTool, $ClassMethod(..#CONTROL, "ArgsFor", ..#OPNAME), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "interop.items.start mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tProposal)) {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take(tProposal.proposalId, tUser, "https://draft.example:52773", .tDraft, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, "interop.items.start: the draft is taken: " _ $Get(tCode))
        If $IsObject($Get(tDraft)) {
            Set tText = tDraft.draft.steps.%Get(0).text
            Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ ("TempStopConfigItem(" _ tConfig _ ", 0, 0)")) && (tText [ "UpdateProduction(tTimeout, 0)") && (tText '[ ("TempStopConfigItem(" _ tConfig _ ", 1, 0)")) && (tText '[ "CleanProduction") && (tText '[ "EnableConfigItem") && (tText '[ "SaveToClass"), "interop.items.start: " _ tText)
            Do $$$AssertEquals($Length(tText, "TempStopConfigItem(" _ tConfig _ ", 0, 0)") - 1, 1, "interop.items.start: the flag is cleared once")
        }
    }
    Do $$$AssertEquals(..Facts(), "enabled=1 stopped=1 own=0 jobs=0 needs=0", "the start draft left the item stopped")
}

}

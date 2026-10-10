/// <p>Pins Story 20.3's two corrections to Story 20.2's stop (AC6, AD-7, AD-12, AD-62) against a probe
/// production in <code>USER</code>: a stop the vendor answers as a success but that leaves the production
/// Suspended with messages still queued is 409 <code>INTEROP.PRODUCTION.SUSPENDED</code> (DW-2157), and a stop
/// whose jobs outlast the cap after the production quiesced is 409 <code>INTEROP.PRODUCTION.PARTSTOPPED</code>,
/// unlogged (DW-2162). Each is reached through the agent's confirm and the Productions row action; the
/// list reads the state the production was left in, a stop that ended Suspended stays applied and marked,
/// and the stop and restart consequences name a partial stop.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over
/// HTTP as <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and <b>runs a probe
/// production in <code>USER</code></b>, including an operation whose teardown waits longer than a stop does.
/// One class per run.</p>
Class OcuPilot.Test.InteropStopOutcome Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter CONTROL = "OcuPilot.Test.InteropControl";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter STOPTOOL = "OcuPilot.Screen.Tool.InteropProductionStop";

/// <p>How long the teardown operation waits, longer than a stop's 15 second wait for its jobs.</p>
Parameter TEARSECONDS = 22;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStopOutcome compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes, its messages and its proposals; a failing status when
/// <code>USER</code> still runs a production.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && ($ClassMethod(..#PROBE, "Current") '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStopOutcome left a production current in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    Quit tSC
}

/// <p>The probe is stopped and put back as its class declares it, its seam restored and its proposals removed,
/// whether the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#SEAM, "Restore")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Start the probe through the port and let it settle, with the operation holding each message
/// <var>pHang</var> seconds, then queue <var>pMessages</var> messages to it.</p>
Method Running(pHang As %Integer = 0, pMessages As %Integer = 0)
{
    If pHang Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetHang", pHang), "the operation holds each message " _ pHang _ " seconds")
    Do $$$AssertStatusOK($ClassMethod(..#CONTROL, "StartIt"), "the probe is started")
    Hang 3
    For tI = 1:1:pMessages {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Send"), "message " _ tI _ " is queued")
    }
}

/// <p>The agent's stop of the probe, minted on a seeded turn for this process's user.</p>
Method MintStop(Output pProposal As %DynamicObject, Output pTurn As %String)
{
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurn)
    Do $$$AssertStatusOK(tSC, "the turn is seeded")
    Set tArgs = {"rationale": "probe", "expectedImpact": "probe"}
    Do tArgs.%Set("Name", ..#PRODUCTION, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurn)
    Set tSC = $ClassMethod(..#STOPTOOL, "View", "", tArgs, 0, .pProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the stop mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p>Confirm a minted stop in process and assert its 409 answer <var>pCode</var> and that its ledger row
/// carries the code and the marker state <var>pMarked</var>: a stop that ended Suspended was applied and
/// is marked, and a partial stop records no marker, which is the story's named limit.</p>
Method ConfirmStop(pCode As %String, pTurn As %String, pProposal As %DynamicObject, pMarked As %String)
{
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmIn", pProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode), "409 " _ pCode, "the confirm answers 409 " _ pCode)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(pTurn, "auditMarked"), pMarked, "the ledger row reads " _ pMarked)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(pTurn, "code"), pCode, "and the ledger row carries the code")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pTurn)
}

/// <p>AC6, DW-2157: a stop of a running production with messages still queued behind a busy operation ends
/// Suspended; the confirm and the row action each answer 409 <code>INTEROP.PRODUCTION.SUSPENDED</code> with
/// the published sentence, the write stays applied and marked, and the list reads Suspended.</p>
/// <p>Mutation (Rule 19): drop the <code>AfterWrite</code> method from
/// <class>OcuPilot.Screen.Tool.InteropProductionStop</class> -- the confirm answers OK and this goes red.</p>
Method TestAStopThatEndsSuspendedAnswersItsCode()
{
    Do ..Running(4, 4)
    Do ..MintStop(.tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do ..ConfirmStop(##class(OcuPilot.Api.InteropError).#SUSPENDED, tTurn, tProposal, $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Listed", ..#PRODUCTION), "Suspended", "the list reads Suspended")
    ; The row action, from the same arrangement again.
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the production is settled")
    Do ..Running(4, 4)
    Set tText = $ClassMethod(..#CONTROL, "Act", "stop", ..#PRODUCTION, .tAnswer)
    Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason _ "|" _ tAnswer.detail.state, 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#SUSPENDED _ "|" _ ##class(OcuPilot.Api.InteropError).#REASONSUSPENDED _ "|Suspended", "the row action answers the same, naming the state")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Listed", ..#PRODUCTION), "Suspended", "and the list reads Suspended")
}

/// <p>AC6, DW-2162: with a job that outlasts the stop's wait after the production quiesced, the confirm and the
/// row action each answer 409 <code>INTEROP.PRODUCTION.PARTSTOPPED</code> with the published sentence, the
/// confirm's ledger row records no marker, and the list reads Running, the state the production was left
/// in.</p>
/// <p>Mutation (Rule 19): drop the <code>ErrJobsNotStopped</code> mapping from
/// <method>OcuPilot.Port.InteropPort.Statused</method> -- both legs answer 500 and go red.</p>
Method TestAStopWhoseJobOutlastsTheCapAnswersPartStopped()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddTearItem", ..#TEARSECONDS), "an operation whose teardown waits " _ ..#TEARSECONDS _ " seconds is added")
    Do ..Running()
    Do ..MintStop(.tProposal, .tTurn)
    If '$IsObject($Get(tProposal)) Quit
    Do ..ConfirmStop(##class(OcuPilot.Api.InteropError).#PARTSTOPPED, tTurn, tProposal, $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDNONE"))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Listed", ..#PRODUCTION), "Running", "the list reads Running")
    ; Let the teardown finish, then arrange it again for the row action.
    Hang ..#TEARSECONDS
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the production is settled")
    Do ..Running()
    Set tText = $ClassMethod(..#CONTROL, "Act", "stop", ..#PRODUCTION, .tAnswer)
    Do $$$AssertEquals(tText _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#PARTSTOPPED _ "|" _ ##class(OcuPilot.Api.InteropError).#REASONPARTSTOPPED, "the row action answers the same")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Listed", ..#PRODUCTION), "Running", "and the list reads Running")
    Hang ..#TEARSECONDS
}

/// <p>AC6, DW-2162: through the port with a shortened wait, a partial stop is 409 <code>PARTSTOPPED</code> and
/// logs nothing, because it is an outcome and not a fault.</p>
/// <p>Mutation (Rule 19): route <code>ErrJobsNotStopped</code> to <code>Fail</code> in
/// <method>OcuPilot.Port.InteropPort.Statused</method> -- the status and the log legs go red; keep its 409
/// and add a <code>LogFault</code> call beside it -- the log leg alone goes red, which shows the seam's
/// capture is engaged.</p>
Method TestAPartialStopIsNotLogged()
{
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddTearItem", ..#TEARSECONDS), "an operation whose teardown waits " _ ..#TEARSECONDS _ " seconds is added")
    Do ..Running()
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionRun", "USE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do $ClassMethod(tSeam, "Arm")
    Do $ClassMethod(tSeam, "Shorten", 3)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(tSeam, "Invoke", "Productions", "STOP", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 " _ ##class(OcuPilot.Api.InteropError).#PARTSTOPPED, "the stop is a partial stop")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged")
    Hang ..#TEARSECONDS
}

/// <p>AC6: the stop and restart consequence sentences each name a partial stop and the nothing-is-stopped
/// refusal.</p>
/// <p>Mutation (Rule 19): reword <parameter>OcuPilot.Api.InteropError.REASONSTOP</parameter> without its
/// partial-stop clause -- the stop leg goes red.</p>
Method TestTheStopAndRestartConsequencesNameAPartialStop()
{
    Set tError = "OcuPilot.Api.InteropError"
    For tCode = "INTEROP.STOP", "INTEROP.RESTART" {
        Set tSentence = $ClassMethod(tError, "ReasonFor", tCode)
        Do $$$AssertTrue((tSentence [ "partly stopped") && (tSentence [ "nothing is stopped"), tCode _ ": " _ tSentence)
    }
}

}

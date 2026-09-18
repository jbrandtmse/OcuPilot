/// <p>Two seams <class>OcuPilot.Test.Ledger</class> has no room for: the tool step's argument
/// string, which must run the same two redaction layers a ledger row's does (AD-3), and the store's
/// answer for a row that is gone by the time it is read (AD-9, AD-24).</p>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and touches no registration. Every
/// turn it reserves names a user starting with
/// <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter>, and
/// <method>OnAfterOneTest</method> asserts none survives.</p>
Class OcuPilot.Test.LedgerStep Extends %UnitTest.TestCase
{

/// <p>The store under test.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The shipped bounds -- in particular the shipped <code>SUMMARYMAXLENGTH</code>, so a declared
/// secret's absence from a step is redaction's work and not the argument cut's.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The user every turn here is reserved for. Shares
/// <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter>, so that fixture's teardown finds
/// it.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerStep";

/// <p>The declared secret's own value, the one
/// <class>OcuPilot.Test.LedgerTool.Probe</class> declares and no name pattern matches.</p>
Parameter SECRETVALUE = "s3cr3tstepvalue";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

Method Clear()
{
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
}

/// <p>AC3 -- the argument string a tool step carries <b>before</b> its call is dispatched is
/// redacted by the tool's own declaration first, not by the name pattern alone. This is the string
/// every tool call of every turn writes, instance- and client-fulfilled alike, and a poll during a
/// slow call renders it; <code>Value</code> matches no pattern, so without the declaration it is
/// stored in clear.</p>
/// <p>Mutation (Rule 19): replace the <method>OcuPilot.Kernel.Agent.Dispatch.StepArguments</method>
/// call that sets <var>tRunningArgs</var> in
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> with
/// <method>OcuPilot.Kernel.Agent.Dispatch.RedactedArguments</method> over the same input -- the
/// declared value reaches the step and this goes red.</p>
Method TestAToolStepsPreDispatchArgumentsAreDeclarationRedacted()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tBlock = {"id": "toolu_running"}
    Do tBlock.%Set("name", "probe_ledger_read", "string")
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tBlock.%Set("input", tInput)
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0

    ; The probe refuses the dispatch, so the step keeps the string written before it (the fixture's
    ; header says why that is the only way to observe it).
    Do $ClassMethod("OcuPilot.Test.LedgerRunningProbe", "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users")

    Set tSteps = ##class(OcuPilot.Test.Ledger).StepText(tKey)
    Do $$$AssertTrue(tSteps [ "probe.ledger.read", "the tool step was written: " _ tSteps)
    Do $$$AssertEquals(tSteps [ ..#SECRETVALUE, 0, "and carries the declared secret in no column: " _ tSteps)
    Do $$$AssertTrue(tSteps [ "[redacted]", "which reads as redacted instead")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p>A row that is gone by the time the view reads it is one absent row, not an unavailable store.
/// <method>OcuPilot.Kernel.State.Base.GuardedOpenId</method> reports a missing id as a failure, so
/// without the existence check <method>GuardedRow</method> would hand
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> an error and the whole read would
/// answer 503 <code>LEDGER.UNAVAILABLE</code>.</p>
/// <p>Mutation (Rule 19): remove the existence branch from
/// <method>OcuPilot.Kernel.State.Ledger.GuardedRow</method> -- the status is an error and this goes
/// red.</p>
Method TestARowThatIsGoneAnswersNoValuesAndNoError()
{
    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Kernel.Audit.Ledger", "RecordToolCall", tKey, ..#PROBEUSER, "permissions/users", "probe.ledger.read", "target", {}, "", "", "", "ok", "", ..#LIMITS, 1), "one row is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 0, tKey, 10, .tIds, .tProblem), "and its id reads back")
    Do $$$AssertEquals(+$Get(tIds), 1, "as one id")
    If +$Get(tIds) '= 1 Quit
    Set tId = tIds(1)

    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedRow", tId, .tPresent), "the row reads while it is there")
    Do $$$AssertEquals($Get(tPresent("turnKey")), tKey, "carrying its turn key")

    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey), "the row is then deleted")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedRow", tId, .tGone), "and reading the same id is not a failure")
    Do $$$AssertEquals($Data(tGone), 0, "it answers no values at all")
}

}

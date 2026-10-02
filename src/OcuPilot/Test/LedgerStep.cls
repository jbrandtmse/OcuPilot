/// <p>Four seams <class>OcuPilot.Test.Ledger</class> has no room for: the tool step's argument
/// string, which must run the same two redaction layers a ledger row's does (AD-3), the tool step's
/// target, which carries the redaction mark where it holds a declared secret's value (AD-33), the
/// result content a finished tool step stores and its bound (AD-33), and the store's answer for a
/// row that is gone by the time it is read (AD-9, AD-24).</p>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and touches no registration. Every
/// turn it reserves names a user starting with
/// <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter>, and
/// <method>OnAfterOneTest</method> asserts none survives. Its secret-as-id test makes the ledger log,
/// at error severity, that it withheld a call's arguments, which the instance counts toward its
/// alert state.</p>
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

/// <p>The tool step's target where the model sends a declared secret's value as the call's
/// <code>id</code>, at each write <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> makes
/// before a call is dispatched: the running append, read as the dispatch begins, and the finish a
/// refused dispatch writes (<class>OcuPilot.Test.LedgerRunningProbe</class>), the reply-budget
/// refusal (<class>OcuPilot.Test.LedgerLoopProbe</class>) and the boundary stop
/// (<class>OcuPilot.Test.LedgerLoopStopProbe</class>). Each stores the redaction mark as its target
/// and the value in no column. The dispatched call's own finish is
/// <class>OcuPilot.Test.TurnConversation</class>'s.</p>
/// <p>Mutation (Rule 19): set any one of those targets from
/// <method>OcuPilot.Kernel.Agent.Dispatch.TargetOf</method> again -- that probe's leg goes red; the
/// running append's alone -- the running-append assertion alone goes red.</p>
Method TestEachPreDispatchStepWriteMarksASecretSentAsTheId()
{
    Set tUser = ..#PROBEUSER
    For tCase = $ListBuild("OcuPilot.Test.LedgerRunningProbe", ..#LIMITS), $ListBuild("OcuPilot.Test.LedgerLoopProbe", $Parameter("OcuPilot.Test.Ledger", "BUDGET")), $ListBuild("OcuPilot.Test.LedgerLoopStopProbe", ..#LIMITS) {
        Set tProbe = $List(tCase, 1)
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), tProbe _ ": a turn is reserved")
        Do $$$AssertEquals(tBusy, 0, tProbe _ ": and is not busy")
        If $Get(tKey) = "" Continue
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), tProbe _ ": and begun")
        Set tBlock = {"id": "toolu_target"}
        Do tBlock.%Set("name", "probe_ledger_read", "string")
        Set tInput = {"Name": "probe"}
        Do tInput.%Set("id", ..#SECRETVALUE, "string")
        Do tInput.%Set("Value", ..#SECRETVALUE, "string")
        Do tBlock.%Set("input", tInput)
        Set tUses = []
        Do tUses.%Push(tBlock)
        Set tLog = []
        Set tMessages = 0
        Do ##class(OcuPilot.Test.LedgerRunningProbe).Forget()
        Do $ClassMethod(tProbe, "AnswerTools", tKey, tUser, "1", "", tUses, $List(tCase, 2), .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users")
        If tProbe = "OcuPilot.Test.LedgerRunningProbe" Do $$$AssertEquals(##class(OcuPilot.Test.LedgerRunningProbe).RunningTarget(), ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, tProbe _ ": the running append's target, read as the dispatch begins, is the redaction mark")
        Set tTargets = ""
        If $$$ISOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows)) {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If tRow.%Get("kind") = "tool" Set tTargets = tTargets _ $ListBuild(tRow.%Get("target"))
            }
        }
        Do $$$AssertEquals($ListToString(tTargets), ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, tProbe _ ": its one tool step's target is the redaction mark")
        Set tSteps = ##class(OcuPilot.Test.Ledger).StepText(tKey)
        Do $$$AssertEquals(tSteps [ ..#SECRETVALUE, 0, tProbe _ ": and the value is in no column: " _ tSteps)
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
    }
}

/// <p>A finished tool step stores the result content the model was handed, so the panel's card can
/// show what the model actually read: the <code>tool_result</code> content itself, cut to
/// <code>TOOLSTEPTEXTMAXLENGTH</code> characters ending in U+2026 when it is longer, and kept whole
/// at that length or less (AD-33). It is untrusted content (AD-11) like every other step field.</p>
/// <p>Mutation (Rule 19): revert <method>OcuPilot.Kernel.State.Step.GuardedFinishTool</method>'s
/// text to the literal <code>""</code>, or drop the <code>content</code> argument from
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s success finish -- either goes red
/// here. Cut at <code>TEXTMAXLENGTH</code> again and the cap leg goes red; cut a result of exactly
/// the cap and the edge leg goes red.</p>
Method TestAToolStepStoresTheResultContentTheModelWasHanded()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tContent = "{""fields"":[""Name""],""rows"":[{""Name"":""probe""}],""truncated"":false}"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "tool", "probe.ledger.read", "running", "", "", "", ..#LIMITS, .tSeq, .tStored), "a running tool step is appended")
    Do $$$AssertEquals(tStored, 1, "and stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(tKey, tSeq, "probe.ledger.read", "ok", "", ..#LIMITS, "", "", "", "", "", 0, tContent), "and finished with the result content")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tRows), "the turn's steps read back")
    Do $$$AssertEquals(tRows.%Size(), 1, "as one step")
    If tRows.%Size() '= 1 Quit
    Do $$$AssertEquals(tRows.%Get(0).%Get("text"), tContent, "carrying the content the model was handed, verbatim")

    Set tSourceSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Kernel.Agent.Loop", .tSource)
    Do $$$AssertStatusOK(tSourceSC, "the loop's source is readable")
    Do $$$AssertTrue(tSource [ "tDetail.argumentsTruncated, $Select($IsObject(tResult): tResult.%Get(""content""), 1: """")", "and the loop's own success finish is what passes it")

    ; The bound the content arrives under: the poll projects every step's text, so a tool step's
    ; text is cut to TOOLSTEPTEXTMAXLENGTH characters, the last of them U+2026.
    Set tMax = +$Parameter(..#LIMITS, "TOOLSTEPTEXTMAXLENGTH")
    Do $$$AssertEquals(tMax, 4096, "the shipped tool step cap is 4,096 characters")
    Set tOversized = $Translate($Justify("", 65536), " ", "x")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "tool", "probe.ledger.big", "running", "", "", "", ..#LIMITS, .tBigSeq, .tBigStored), "a second running tool step is appended")
    Do $$$AssertEquals(tBigStored, 1, "and stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(tKey, tBigSeq, "probe.ledger.big", "ok", "", ..#LIMITS, "", "", "", "", "", 0, tOversized), "and finished with a 65,536-character result")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tBigRows), "the turn's steps read back again")
    Do $$$AssertEquals(tBigRows.%Size(), 2, "as two steps")
    If tBigRows.%Size() '= 2 Quit
    Set tBigText = tBigRows.%Get(1).%Get("text")
    Do $$$AssertEquals($Length(tBigText), tMax, "the long result is cut to TOOLSTEPTEXTMAXLENGTH")
    Do $$$AssertEquals($Extract(tBigText, *), $Char(8230), "ending in U+2026")
    Do $$$AssertEquals($Extract(tBigText, 1, tMax - 1), $Extract(tOversized, 1, tMax - 1), "after the result's own first characters")
    Do $$$AssertEquals(tBigRows.%Get(1).%Get("truncated"), 1, "and the step says it was cut")

    ; The edge: a result of exactly the cap is kept whole, and one character more is cut.
    Set tExact = $Extract(tOversized, 1, tMax)
    For tI = 0, 1 {
        Set tName = "probe.ledger.edge" _ tI
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "tool", tName, "running", "", "", "", ..#LIMITS, .tEdgeSeq, .tEdgeStored), "an edge tool step is appended")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(tKey, tEdgeSeq, tName, "ok", "", ..#LIMITS, "", "", "", "", "", 0, tExact _ $Select(tI: "y", 1: "")), "and finished with a result of the cap plus " _ tI)
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedRows(tKey, .tEdgeRows), "the turn's steps read back once more")
    Do $$$AssertEquals(tEdgeRows.%Size(), 4, "as four steps")
    If tEdgeRows.%Size() '= 4 Quit
    Set tWhole = tEdgeRows.%Get(2)
    Do $$$AssertEquals($Length(tWhole.text) _ "|" _ (tWhole.text = tExact) _ "|" _ tWhole.truncated, tMax _ "|1|0", "a result of exactly the cap is kept whole and not marked cut")
    Set tOver = tEdgeRows.%Get(3)
    Do $$$AssertEquals($Length(tOver.text) _ "|" _ ($Extract(tOver.text, *) = $Char(8230)) _ "|" _ tOver.truncated, tMax _ "|1|1", "one character more is cut to the cap, ending in U+2026, and marked cut")

    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p>A turn of 60 tool steps, each finished with a 65,536-character result, still serializes
/// through <method>OcuPilot.Kernel.State.Turn.GuardedView</method>, the progress poll's view: each
/// tool step's text is 4,096 characters ending in U+2026. Uncut, the 60 results total 3,932,160
/// characters, past this build's string limit, and <code>%ToJSON()</code> raises
/// <code>&lt;MAXSTRING&gt;</code>.</p>
/// <p>Mutation (Rule 19): cut at <code>TEXTMAXLENGTH</code> again in
/// <method>OcuPilot.Kernel.State.Step.GuardedFinishTool</method> -&gt; the view no longer serializes
/// and this goes red, with the cap leg above.</p>
Method TestALongTurnsProgressStillSerializes()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tResult = $Translate($Justify("", 65536), " ", "x")
    Set tFinished = 0
    For tI = 1:1:60 {
        Set tAppendSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "tool", "probe.ledger.long", "running", "", "", "", ..#LIMITS, .tSeq, .tStored)
        If $$$ISERR(tAppendSC) || 'tStored Quit
        Set tFinishSC = ##class(OcuPilot.Kernel.State.Step).GuardedFinishTool(tKey, tSeq, "probe.ledger.long", "ok", "", ..#LIMITS, "", "", "", "", "", 0, tResult)
        If $$$ISERR(tFinishSC) Quit
        Set tFinished = tFinished + 1
    }
    Do $$$AssertEquals(tFinished, 60, "sixty tool steps are finished with a 65,536-character result each")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, tUser, .tFound, .tView), "the progress view reads")
    Do $$$AssertEquals(tFound, 1, "for the turn's owner")
    If '$IsObject(tView) Quit
    Set tJson = ""
    Try {
        Set tJson = tView.%ToJSON()
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the view serializes to one JSON string")
    }
    Do $$$AssertTrue(tJson '= "", "the view serialized")
    Set tSteps = tView.%Get("steps")
    Do $$$AssertEquals(tSteps.%Size(), 60, "carrying the sixty steps")
    Set tCut = 0
    For tI = 0:1:tSteps.%Size() - 1 {
        Set tText = tSteps.%Get(tI).%Get("text")
        If ($Length(tText) = 4096) && ($Extract(tText, *) = $Char(8230)) Set tCut = tCut + 1
    }
    Do $$$AssertEquals(tCut, 60, "each tool step's text is 4,096 characters ending in U+2026")

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

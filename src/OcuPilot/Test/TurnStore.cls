/// <p>The turn stores in process (AD-7, AD-31, AD-33, AD-41): the reserve and its busy refusal, the
/// reconcile of a turn whose job is gone, owner-only lookup, lease renewal and stop, sign-out scoped
/// to its user, retention, begin and finish around the slot, the step caps, what a poll renews and
/// the error sentence it carries, and the armed provider row.</p>
/// <p><b>Live-safe.</b> It spawns nothing: every turn is reserved and begun by this process. Turns
/// are reserved under <class>OcuPilot.Test.TurnFixture</class> probe user names, except where a poll
/// is dispatched through the shipped router in process, which answers as this process's own
/// account; those methods reserve under that account and delete their turns themselves. Every
/// probe turn, step and signal is removed after each method.</p>
Class OcuPilot.Test.TurnStore Extends %UnitTest.TestCase
{

Parameter USERA = "OcuPilotProbeTurnStoreA";

Parameter USERB = "OcuPilotProbeTurnStoreB";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter NARROW = "OcuPilot.Test.TurnLimits";

Parameter JOBLOST = "TURN.ABANDONED.JOBLOST";

Method OnBeforeOneTest() As %Status
{
    Quit ##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).AnyProbeSlotHeld(), 0, "no probe slot is left held")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish("", ..#USERA, "failed", "", "", "", 0, ..#LIMITS)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish("", ..#USERB, "failed", "", "", "", 0, ..#LIMITS)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed with their steps and signals")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

Method Reserve(pUser As %String, Output pBusy As %Boolean, pLimits As %String = {..#LIMITS}) As %String
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(pUser, "1", ..#JOBLOST, pLimits, .tKey, .pBusy, .tSweep), "the reserve completes")
    Do $$$AssertStatusOK(tSweep, "and its sweep")
    Quit tKey
}

/// <p>A reserve inserts one queued turn with its lease set; a second reserve for the same user is
/// busy while that turn is queued, and inserts nothing; another user is not.</p>
/// <p>Mutation: skip the queued-window check in <method>OcuPilot.Kernel.State.Turn.ReconcileHeld</method>
/// -- this goes red, the second reserve inserting a second row.</p>
Method TestAReserveIsOneQueuedTurnPerUser()
{
    Set tKey = ..Reserve(..#USERA, .tBusy)
    Do $$$AssertEquals(tBusy, 0, "the first reserve is not busy")
    Do $$$AssertTrue($Match(tKey, "^[0-9a-f]{32}$"), "and answers an opaque key: " _ tKey)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State"), "queued", "the turn is queued")
    Do $$$AssertTrue((##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Get(^OcuPilotTurnSignal(tKey, "renewed"))) < 5, "with its lease set to now")

    Set tSecond = ..Reserve(..#USERA, .tBusy)
    Do $$$AssertEquals(tBusy, 1, "a second reserve while the first is queued is busy")
    Do $$$AssertEquals(tSecond, "", "and answers no key")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(..#USERA), 1, "and inserted nothing")

    Set tOther = ..Reserve(..#USERB, .tBusy)
    Do $$$AssertEquals(tBusy, 0, "another user's reserve is not busy")
    Do $$$AssertNotEquals(tOther, "", "and answers its own key")
}

/// <p>A turn queued past the queued limit, and a running turn no process holds the slot for, are
/// finished <code>abandoned</code> with the lost code by the next reserve or reconcile, and the
/// slot is free again.</p>
Method TestALostTurnIsFinishedByTheNextReserveOrReconcile()
{
    Set tKey = ..Reserve(..#USERA, .tBusy)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).Age(tKey, "QueuedAt", $Parameter(..#LIMITS, "QUEUEDSECONDS") + 2), "the turn is aged past the queued limit")
    Set tNext = ..Reserve(..#USERA, .tBusy)
    Do $$$AssertEquals(tBusy, 0, "the next reserve is not busy")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tKey, "Code"), "abandoned|" _ ..#JOBLOST, "the lost turn is abandoned with the lost code")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).ForceState(tNext, "running"), "the new turn is left running with no process on its slot")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReconcile(..#USERA, ..#JOBLOST, ..#LIMITS), "a reconcile runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tNext, "State") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tNext, "Code"), "abandoned|" _ ..#JOBLOST, "and abandons it too")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.TurnFixture).Field(tNext, "EndedAt"), "", "with an end time")
}

/// <p>A turn is found only by its owner, matched exactly; renewal moves its lease; a stop from
/// anyone else sets nothing.</p>
/// <p>Mutation: drop the user predicate from <method>OcuPilot.Kernel.State.Turn.GuardedForOwner</method>
/// -- this goes red.</p>
Method TestOnlyTheOwnerFindsRenewsAndStopsATurn()
{
    Set tKey = ..Reserve(..#USERA, .tBusy)
    For tCase = ..#USERA _ "|1", ..#USERB _ "|0", $ZConvert(..#USERA, "L") _ "|0" {
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedForOwner(tKey, $Piece(tCase, "|", 1), .tFound, .tValues)
        Do $$$AssertEquals(tFound, $Piece(tCase, "|", 2), "found as " _ $Piece(tCase, "|", 1) _ ": " _ tFound)
    }
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedForOwner("0123456789abcdef0123456789abcdef", ..#USERA, .tFound, .tValues)
    Do $$$AssertEquals(tFound, 0, "an unknown key is not found")

    Set ^OcuPilotTurnSignal(tKey, "renewed") = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - 500
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedRenew(tKey), "the lease is renewed")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tKey, .tStop, .tAbandon, .tRenewedAt)
    Do $$$AssertTrue((##class(OcuPilot.Kernel.State.Turn).NowSeconds() - tRenewedAt) < 5, "to now: " _ tRenewedAt)

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(tKey, ..#USERB, .tFound), "another user's stop completes")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tKey, .tStop, .tAbandon, .tRenewedAt)
    Do $$$AssertEquals(tFound _ "|" _ tStop, "0|0", "and sets nothing")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(tKey, ..#USERA, .tFound)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tKey, .tStop, .tAbandon, .tRenewedAt)
    Do $$$AssertEquals(tFound _ "|" _ tStop, "1|1", "the owner's stop sets the flag")
}

/// <p>An abandon reaches every queued or running turn of its user and no other user's.</p>
/// <p>Mutation: drop the user predicate from
/// <method>OcuPilot.Kernel.State.Turn.GuardedAbandonForUser</method> -- this goes red.</p>
Method TestAnAbandonReachesOnlyItsUser()
{
    Set tKeyA = ..Reserve(..#USERA, .tBusy)
    Set tKeyB = ..Reserve(..#USERB, .tBusy)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedAbandonForUser(..#USERA, .tCount), "user A signs out")
    Do $$$AssertEquals(tCount, 1, "one turn is asked to abandon")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tKeyA, .tStop, .tAbandonA, .tRenewed)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(tKeyB, .tStop, .tAbandonB, .tRenewed)
    Do $$$AssertEquals(tAbandonA _ "|" _ tAbandonB, "1|0", "user A's, and not user B's")
}

/// <p>The next reserve by any user deletes a terminal turn that ended the retention period ago,
/// with its steps and signals, and keeps one that ended more recently; the owner's poll of the
/// deleted turn then answers 404, dispatched through the shipped router in process.</p>
Method TestRetentionDeletesTheTurnItsStepsAndSignals()
{
    Set tRetention = $Parameter(..#LIMITS, "RETENTIONSECONDS")
    Set tOwn = ..Reserve($Username, .tBusy)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tOwn, $Username, "completed", "", "", "done", 0, ..#LIMITS)
    Do ##class(OcuPilot.Test.TurnFixture).Age(tOwn, "EndedAt", tRetention + 1)
    Do ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/turn/" _ tOwn _ "/progress", "GET", , .tBody, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the owner's poll answers before the sweep: " _ tBody)
    For tUser = ..#USERA, ..#USERB {
        Set tKey(tUser) = ..Reserve(tUser, .tBusy)
        Do ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey(tUser), "model", "provider", "ok", "", "", "", ..#LIMITS, .tSeq)
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey(tUser), tUser, "completed", "", "", "done", 0, ..#LIMITS), "a turn of " _ tUser _ " ends")
    }
    Do ##class(OcuPilot.Test.TurnFixture).Age(tKey(..#USERA), "EndedAt", tRetention + 1)
    Do ##class(OcuPilot.Test.TurnFixture).Age(tKey(..#USERB), "EndedAt", tRetention - 60)
    Set tNext = ..Reserve("OcuPilotProbeTurnStoreC", .tBusy)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey(..#USERA), "State"), "", "the turn past retention is deleted")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey(..#USERA)), 0, "with its steps")
    Do $$$AssertEquals($Data(^OcuPilotTurnSignal(tKey(..#USERA))), 0, "and its signals")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey(..#USERB), "State"), "completed", "a turn inside retention is kept")
    Do ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/turn/" _ tOwn _ "/progress", "GET", , .tBody, .tStatus)
    Do $$$AssertEquals(tStatus, 404, "and the owner's poll of the deleted turn answers 404: " _ tBody)
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tOwn)
}

/// <p>Begin takes the slot for the calling process only from <code>queued</code>, and finish
/// records the outcome, cuts the reply at the text cap, and releases the slot.</p>
Method TestBeginAndFinishHoldTheSlotBetweenThem()
{
    Set tKey = ..Reserve(..#USERA, .tBusy)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, ..#USERB, ..#NARROW, .tBegun, .tStarted), "a begin as another user completes")
    Do $$$AssertEquals(tBegun, 0, "and does not begin")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, ..#USERA, ..#NARROW, .tBegun, .tStarted), "the owner's job begins")
    Do $$$AssertEquals(tBegun, 1, "the turn begins")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State") _ "|" _ ##class(OcuPilot.Test.TurnFixture).Field(tKey, "JobId"), "running|" _ $Job, "running, as this job")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner(..#USERA), $Job, "holding the slot")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, ..#USERA, "completed", "", "iterations", "a reply longer than sixteen", 0, ..#NARROW), "the turn finishes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner(..#USERA), "", "releasing the slot")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "Reply"), "a reply longer t", "with the reply cut at the text cap")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, ..#USERA, ..#NARROW, .tBegun, .tStarted), "a begin on an ended turn completes")
    Do $$$AssertEquals(tBegun, 0, "and does not begin")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner(..#USERA), "", "or hold the slot")
}

/// <p>Past the step cap, a step is counted on the turn rather than stored, its sequence number
/// still advances, and a field over its cap is cut and marked.</p>
Method TestStepsAreCappedOnWrite()
{
    Set tKey = ..Reserve(..#USERA, .tBusy)
    For tI = 1:1:3 {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "tool", "probe.tool", "error", "a summary over eight", "", "TOOL.UNAVAILABLE", ..#NARROW, .tSeq, .tStored), "step " _ tI _ " is appended")
        Do $$$AssertEquals(tSeq _ "|" _ tStored, tI _ "|" _ (tI < 3), "step " _ tI _ " has its sequence number and is stored only under the cap")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey), 2, "two steps are stored")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "StepsDropped"), 1, "and one is counted")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedUpdate(tKey, 3, "ok", "", "", "", ..#NARROW), "an update to the dropped step fails nothing")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey), 2, "and writes nothing")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, ..#USERA, .tFound, .tView)
    Do $$$AssertEquals(tView.steps.%Get(0).summary _ "|" _ tView.steps.%Get(0).truncated, "a summar|1", "a summary is cut at its cap and marked")
    Do $$$AssertEquals(tView.stepsDropped, 1, "and the projection counts the dropped step")
}

/// <p>An owner's poll renews the lease of a turn that has not ended, and nothing else: another
/// user's turn answers 404 and keeps its lease, and an ended turn's lease is left as it was.</p>
/// <p>Mutation: drop the <method>OcuPilot.Kernel.State.Turn.GuardedRenew</method> call from
/// <method>OcuPilot.Api.Turn.HandleProgress</method> -- this goes red.</p>
Method TestAPollRenewsOnlyItsOwnersUnfinishedTurn()
{
    Set tStale = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - 500
    Set tOwn = ..Reserve($Username, .tBusy)
    Set tOther = ..Reserve(..#USERA, .tBusy)
    Set ^OcuPilotTurnSignal(tOwn, "renewed") = tStale
    Set ^OcuPilotTurnSignal(tOther, "renewed") = tStale
    Do ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/turn/" _ tOwn _ "/progress", "GET", , .tBody, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the owner's poll answers: " _ tBody)
    Do $$$AssertTrue((##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Get(^OcuPilotTurnSignal(tOwn, "renewed"))) < 5, "and renews the lease")
    Do ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/turn/" _ tOther _ "/progress", "GET", , .tBody, .tStatus)
    Do $$$AssertEquals(tStatus, 404, "another user's turn is not found")
    Do $$$AssertEquals($Get(^OcuPilotTurnSignal(tOther, "renewed")), tStale, "and keeps its lease")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tOwn, $Username, "completed", "", "", "done", 0, ..#LIMITS), "the owner's turn ends")
    Set ^OcuPilotTurnSignal(tOwn, "renewed") = tStale
    Do ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/turn/" _ tOwn _ "/progress", "GET", , .tBody, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "a poll of the ended turn answers")
    Do $$$AssertEquals($Get(^OcuPilotTurnSignal(tOwn, "renewed")), tStale, "and renews nothing")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tOwn), "the owner's turn is removed")
}

/// <p>A poll of an ended turn carries the step, the code and the code's written sentence, whichever
/// family the code is from.</p>
/// <p>Mutation: drop the <code>reason</code> from <method>OcuPilot.Api.Turn.HandleProgress</method>
/// -- this goes red.</p>
Method TestAnEndedTurnsPollCarriesItsErrorSentence()
{
    Set tCases(1) = $ListBuild("abandoned", "TURN.ABANDONED.SIGNOUT", ##class(OcuPilot.Api.Error).#REASONTURNABANDONEDSIGNOUT)
    Set tCases(2) = $ListBuild("stopped", "AGENT.KILLSWITCH.USER", ##class(OcuPilot.Api.Error).#REASONAGENTKILLSWITCHUSER)
    Set tCases(3) = $ListBuild("failed", "PROVIDER.CREDENTIAL", ##class(OcuPilot.Kernel.Provider.Base).ReasonFor("PROVIDER.CREDENTIAL"))
    For tI = 1:1:3 {
        Set tCode = $List(tCases(tI), 2)
        Set tKey = ..Reserve($Username, .tBusy)
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, $List(tCases(tI), 1), tCode, "", "", 1, ..#LIMITS), tCode _ ": the turn ends")
        Do ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/turn/" _ tKey _ "/progress", "GET", , .tBody, .tStatus)
        Do $$$AssertEquals(tStatus, 200, tCode _ ": the poll answers " _ tBody)
        If tStatus = 200 {
            Set tError = ##class(%DynamicObject).%FromJSON(tBody).error
            Do $$$AssertNotEquals($List(tCases(tI), 3), "", tCode _ ": has a written sentence")
            Do $$$AssertEquals(tError.seq _ "|" _ tError.code _ "|" _ tError.reason, "1|" _ tCode _ "|" _ $List(tCases(tI), 3), tCode _ ": the error carries its step, code and sentence")
        }
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey), tCode _ ": the turn is removed")
    }
}

/// <p>Every <code>TURN*</code> code the error vocabulary declares is in
/// <method>OcuPilot.Api.Error.TurnCodes</method> and has a written sentence.</p>
/// <p>Mutation: remove the <code>TURN.LIMIT.TOKENS</code> branch from
/// <method>OcuPilot.Api.Error.ReasonForTurn</method> -- this goes red.</p>
Method TestEveryTurnCodeHasASentence()
{
    Set tDeclared = ##class(OcuPilot.Api.Error).TurnCodes()
    Set tFound = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ?", "OcuPilot.Api.Error")
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If $Extract(tName, 1, 4) '= "TURN" Continue
        Set tFound = tFound + 1
        Set tCode = $Parameter("OcuPilot.Api.Error", tName)
        Do $$$AssertTrue($ListFind(tDeclared, tCode) > 0, tName _ " is in TurnCodes()")
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForTurn(tCode), "", tName _ " has a written sentence")
    }
    Do $$$AssertTrue(tFound > 0, "the vocabulary declares turn codes")
    Do $$$AssertEquals($ListLength(tDeclared), tFound, "and TurnCodes() holds no code the class does not declare")
}

/// <p>The <code>turnprobe</code> provider row resolves only while
/// <code>OCUPILOT_ALLOW_TEST_PROVIDER</code> reads 1, and the provider list never carries it.</p>
/// <p>Mutation: drop the environment test from <method>OcuPilot.Kernel.Provider.Catalog.Row</method>
/// -- this goes red on an unarmed instance.</p>
Method TestTheTurnProbeRowResolvesOnlyWhenArmed()
{
    Set tArmed = ($System.Util.GetEnviron("OCUPILOT_ALLOW_TEST_PROVIDER") = 1)
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row("turnprobe", .tRow), tArmed, "the row resolves exactly when armed")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).IsKnown("turnprobe"), tArmed, "and is known exactly then")
    If tArmed Do $$$AssertEquals(tRow.adapterClass, "OcuPilot.Test.TurnProvider", "naming the scripted adapter")
    Do $$$AssertEquals($ListFind(##class(OcuPilot.Kernel.Provider.Catalog).Keys(), "turnprobe"), 0, "and the provider list never carries it")
}

}

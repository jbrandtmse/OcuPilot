/// <p>Pins the four ways a proposal closes without being confirmed (Story 5.3, DW-1209, DW-1231,
/// DW-1243): the user's own Cancel, the next typed message, New conversation, and the expiry the
/// read projects.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state and an account holding
/// <code>%All</code>. Nothing here calls a port or writes to the instance. Every row it seeds
/// carries <parameter>PROBETURN</parameter>, which is what teardown finds them by: the two Cancel
/// tests name the running account, because the shipped path matches the caller against the row's
/// own user, and the rest name <parameter>PROBEUSER</parameter>.</p>
Class OcuPilot.Test.ProposalClose Extends %UnitTest.TestCase
{

Parameter PROBEUSER = "OcuPilotProbeProposalCloser";

Parameter PROBECONV = "probe-close-conv";

/// <p>The turn key every row this class seeds carries, which is what teardown finds them by.</p>
Parameter PROBETURN = "probe-close-turn";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

/// <p>The scoped target every seeded row names.</p>
ClassMethod Target() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotprobeclose", .tKey)
    Quit tKey
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    ; Every row this class seeds carries PROBETURN, whatever account it names -- one test drives
    ; the shipped cancel and so has to name the running account.
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForTurn(..#PROBETURN)
    Do $$$AssertStatusOK(tSC, "the probe proposals are removed")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining)
    Do $$$AssertStatusOK(tSC, "and so is anything left under the probe prefix")
    Do $$$AssertEquals(tRemaining, 0, "with none surviving the removal")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(..#PROBETURN, .tLeft)
    Do $$$AssertStatusOK(tSC, "the probe turn's rows are counted")
    Do $$$AssertEquals(tLeft, 0, "and none of this class's own survives either")
    Quit $$$OK
}

/// <p>Seed one live proposal for <var>pUser</var> in conversation <var>pConvKey</var>.</p>
Method Seed(pUser As %String = {..#PROBEUSER}, pConvKey As %String = {..#PROBECONV}) As %String
{
    Kill tValues
    Set tValues("user") = pUser
    Set tValues("convKey") = pConvKey
    Set tValues("turnKey") = ..#PROBETURN
    Set tValues("toolName") = "webapp.list.update"
    Set tValues("targetRef") = ..Target()
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>DW-1243: Cancel closes the caller's own live row with the reason the card renders, and
/// answers nothing for a row that is already terminal.</p>
/// <p>Mutation: close the row with no reason in
/// <method>OcuPilot.Kernel.State.Propose.GuardedClose</method> -- the reason assertion goes red.</p>
Method TestCancelClosesTheRowAsTheUsersOwnDecision()
{
    Set tKey = ..Seed($Username)
    If tKey = "" Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Cancel", tKey, $Username, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the cancel succeeds")
    Do $$$AssertEquals(tHttp, 200, "answering 200")
    Do $$$AssertEquals(tResult.%Get("state"), "canceled", "the row is canceled")
    Do $$$AssertEquals(tResult.%Get("closedReason"), "you", "by the user's own decision")

    Set tSC = $ClassMethod(..#CONFIRM, "Cancel", tKey, $Username, .tAgain, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a second cancel is refused")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "saying nothing about whether the row exists")
}

/// <p>AD-40: Cancel is a user-originated request too, so a process acting for the model cannot make
/// one.</p>
Method TestCancelFromInsideATurnIsRefused()
{
    Set tKey = ..Seed($Username)
    If tKey = "" Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set("probe-turn", "probe-conv")
    Set tSC = $ClassMethod(..#CONFIRM, "Cancel", tKey, $Username, .tResult, .tHttp, .tCode)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusNotOK(tSC, "the cancel is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#FROMTURN, "with the from-turn code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row is untouched")
}

/// <p>DW-1231: a typed message closes every live proposal of its conversation, as the instance's
/// own fact -- one conversation's rows and no other's.</p>
/// <p>Mutation: drop the <code>ConvKey</code> predicate from
/// <method>OcuPilot.Kernel.State.Propose.GuardedCloseLiveForConvo</method> -- the other
/// conversation's row closes too and this goes red.</p>
Method TestATypedMessageClosesThatConversationsLiveProposals()
{
    Set tMine = ..Seed()
    Set tOther = ..Seed(..#PROBEUSER, "probe-close-other-conv")
    If (tMine = "") || (tOther = "") Quit

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedCloseLiveForConvo(..#PROBECONV, ..#PROBEUSER, ##class(OcuPilot.Kernel.State.Propose).#REASONMESSAGE, .tCount)
    Do $$$AssertStatusOK(tSC, "the close runs")
    Do $$$AssertEquals(tCount, 1, "closing exactly the one row of that conversation")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tMine, "State"), "canceled", "which is canceled")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tMine, "ClosedReason"), "message", "with the reason the card renders")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOther, "State"), "live", "and another conversation's row is untouched")
}

/// <p>DW-1243: New conversation closes every live proposal the caller holds, whatever conversation
/// minted it, and none of anyone else's.</p>
Method TestNewConversationClosesEveryLiveProposalOfTheCaller()
{
    Set tFirst = ..Seed()
    Set tSecond = ..Seed(..#PROBEUSER, "probe-close-other-conv")
    Set tOthers = ..Seed("OcuPilotProbeProposalCloserTwo")
    If (tFirst = "") || (tSecond = "") || (tOthers = "") Quit

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedCloseLiveForUser(..#PROBEUSER, ##class(OcuPilot.Kernel.State.Propose).#REASONYOU, .tCount)
    Do $$$AssertStatusOK(tSC, "the close runs")
    Do $$$AssertEquals(tCount, 2, "closing both of the caller's rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst, "ClosedReason"), "you", "with the reason New conversation carries")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "ClosedReason"), "you", "on the row from the other conversation too")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOthers, "State"), "live", "and another account's row is untouched")
}

/// <p>DW-1243, at the handler rather than at the store: creating a conversation closes the
/// caller's live proposals as a fact of the instance, not as something the browser draws.</p>
/// <p>Mutation: delete the <method>GuardedCloseLiveForUser</method> block from
/// <method>OcuPilot.Api.Conversation.HandleCreate</method> -- this goes red, while every test that
/// calls the store directly stays green.</p>
Method TestCreatingAConversationClosesTheCallersLiveProposalsAtTheHandler()
{
    Set tKey = ..Seed($Username)
    If tKey = "" Quit
    Set tOther = ..Seed()
    If tOther = "" Quit

    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHandler("OcuPilot.Api.Conversation", "HandleCreate", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "the handler answers rather than raising")
    Do $$$AssertEquals(tStatus, 201, "with a created conversation: " _ tBody)

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "canceled", "the caller's live proposal is closed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "you", "by the user's own decision")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOther, "State"), "live", "and another account's is untouched")

    Set tCreated = ##class(%DynamicObject).%FromJSON(tBody)
    Do ##class(OcuPilot.Kernel.State.Entry).GuardedDeleteForConvo(tCreated.%Get("conversationId"))
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tCreated.%Get("conversationId"))
}

/// <p>DW-1209: a live row past its window projects <code>expired</code> at every read, and the
/// wire row carries the terminal state, the reason and the confirmation stamp.</p>
/// <p>Mutation: report the stored state unchanged from
/// <method>OcuPilot.Kernel.State.Propose.ProjectedState</method> -- this goes red.</p>
Method TestAnExpiredRowProjectsExpiredAtEveryRead()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).AgeExpiry(tKey, 3600), "the row is aged past its window")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues), "the row reads back")
    Do $$$AssertEquals($Get(tValues("state")), "expired", "projected expired")
    Do $$$AssertEquals($Get(tValues("storedState")), "live", "while the stored value is still live")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(..#PROBETURN, ..#PROBEUSER, .tRows), "the turn's wire rows read")
    Do $$$AssertEquals(tRows.%Size(), 1, "carrying the one row")
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(tRow.%Get("state"), "expired", "which the wire reports expired")
    Do $$$AssertEquals(tRow.%GetTypeOf("closedReason"), "string", "and carries a closedReason key on every answer")
    Do $$$AssertEquals(tRow.%GetTypeOf("confirmedAt"), "string", "and a confirmedAt key, so a reader never has to tell absent from empty")
}

/// <p>The wire row of a confirmed proposal carries the terminal state and the moment of the write,
/// which is what the card's confirmed status line is drawn from.</p>
Method TestAConfirmedRowIsOnTheWireWithItsStampAndReason()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tKey, .tVersion), "the row's version reads")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tKey, tVersion, ..Target(), .tWon, .tTerminal), "the claim runs")
    Do $$$AssertEquals(tWon, 1, "and wins")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(..#PROBETURN, ..#PROBEUSER, .tRows), "the turn's wire rows read")
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(tRow.%Get("state"), "confirmed", "the wire carries the terminal state")
    Do $$$AssertNotEquals(tRow.%Get("confirmedAt"), "", "and the moment of the write")
    Do $$$AssertEquals(tRow.%Get("closedReason"), "", "with no closed reason, which belongs to a cancel")
}

}

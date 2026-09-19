/// <p>Pins the confirm path (Story 5.3, AD-40, AD-6, AD-8, AD-30, AD-34): the happy path sends the
/// stored payload and nothing else, and each of the refusals -- from a turn, a closed channel, not
/// the minting user, the conversation, the definition, a restraint, a revoked pair, a changed
/// target -- is reachable on its own.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, an account holding
/// <code>%All</code>, and nothing else. Every port call is
/// <class>OcuPilot.Test.ProposalFixture</class>'s, so <b>no write reaches the instance</b>: the
/// confirmed write goes to the fixture, which records the body it was sent. Every row names the
/// running account, because the claim's privilege re-check is against a real principal, and is
/// removed in <method>OnAfterOneTest</method> by the turn it was minted on.</p>
Class OcuPilot.Test.ProposalConfirm Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter TOOL = "webapp.list.update";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The target the fixture answers for. Nothing on the instance carries this path, and nothing
/// here would reach it if it did: the port is the fixture.</p>
Parameter TARGET = "/csp/ocupilotprobeconfirm";

/// <p>The fresh read every test starts from: three properties of the vendor's own web-application
/// shape, one of them the tool's settable <code>Description</code>.</p>
Parameter FRESH = "{""Name"":""/csp/ocupilotprobeconfirm"",""Description"":""before"",""Enabled"":true}";

/// <p>The pair the privilege refusal is driven with, refused through the fixture rather than
/// revoked on the instance.</p>
Parameter DENIEDPAIR = "%Admin_Secure:WRITE";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    ; Unconditional, not only on the path that turned it on: enforced read-only is instance-wide,
    ; so a test that aborts between turning it on and turning it off would leave every later class
    ; in the sweep refusing every write.
    Kill tRestore
    Set tRestore("enforcedReadOnly") = 0
    Do ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRestore)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Mint one live proposal on a completed turn for the running account, and answer its id.</p>
Method Seed(pDescription As %String = "after", pConvKey As %String = "") As %String
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#TARGET, "string")
    Do tArgs.%Set("Description", pDescription, "string")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOL, $Username, pConvKey, tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", ..#TARGET, "Name", ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
    Do $$$AssertStatusOK(tSC, "the probe proposal mints")
    If $$$ISERR(tSC) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>Confirm <var>pKey</var> as the running account with <var>pBody</var>.</p>
Method Confirm(pKey As %String, pBody As %DynamicObject = "", Output pHttp As %Integer, Output pCode As %String, Output pResult, Output pDetail) As %Status
{
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, pBody, $Username, .pResult, .pHttp, .pCode, .pDetail)
}

/// <p>AC3, AD-6: the port receives the stored payload with nothing of the request in it, the row is
/// burned and confirmed, and the write is made exactly once.</p>
/// <p>Mutation: take the payload from the request instead of the row in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- the body assertion goes red.</p>
Method TestTheConfirmedWriteSendsTheStoredPayload()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tStored), "the stored row reads back")
    Set tStoredPayload = $Get(tStored("payload"))
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#FRESH)

    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHttp, 200, "answering 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "the port is invoked exactly once")

    Set tSent = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Do $$$AssertEquals(tSent, tStoredPayload, "and the body it received is the stored payload, verbatim")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 1, "the row is burned")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "confirmed", "and confirmed")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ConfirmedAt"), "", "with the moment of the write recorded")
    Do $$$AssertEquals(tResult.%Get("state"), "confirmed", "the answer carries the terminal state")
    Do $$$AssertNotEquals(tResult.%Get("confirmedAt"), "", "and the confirmation stamp the card renders")
}

/// <p>AC1, AD-40: a process acting for the model cannot confirm, and the row is untouched.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Caller.IsTurn</method> return 0
/// unconditionally -- this goes red.</p>
Method TestAConfirmFromInsideATurnIsRefused()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "RowVersion")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set("probe-turn", "probe-conv")
    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()

    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#FROMTURN, "with the from-turn code")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "no request reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row is still live")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "still unburned")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "RowVersion"), tBefore, "and at the version it was read at")
}

/// <p>AC2, AD-6: a key outside the declared secret-typed set is rejected outright, and so is the
/// identifying key. No claim, no port call.</p>
/// <p>Mutation: ignore an unknown confirm key instead of refusing it in
/// <method>OcuPilot.Kernel.Proposal.Confirm.ChannelProblem</method> -- both halves go red.</p>
Method TestAKeyOutsideTheClosedChannelIsRefused()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do $$$AssertEquals($ListLength($ClassMethod(..#SCREEN, "SecretArguments")), 0, "this screen declares no secret argument, so the channel is closed to everything")
    ; The mint's own fresh read is the only port call so far; AC2 says a refused confirm adds none.
    Set tAfterMint = ##class(OcuPilot.Test.ProposalFixture).CallCount()

    Set tSC = ..Confirm(tKey, {"Description": "from the request"}, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a settable field sent at confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#CLOSEDCHANNEL, "with the closed-channel code")
    Do $$$AssertEquals(tHttp, 400, "at 400")

    Set tSC = ..Confirm(tKey, {"Name": "/csp/elsewhere"}, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "and so is the identifying key")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#CLOSEDCHANNEL, "with the same code")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).CallCount(), tAfterMint, "no request of any kind reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and certainly no write")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row was not claimed")
}

/// <p>AC4, FR-17 (user): only the minting user may confirm.</p>
Method TestAnotherUsersProposalIsRefused()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", "OcuPilotProbeProposalOther", .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "another account's confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#NOTYOURS, "as not yours")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row is untouched")
}

/// <p>AC4, FR-17 (conversation): a turn later than the minting one closes the window.</p>
/// <p>Mutation: skip the conversation check in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- this goes red.</p>
Method TestANewerTurnInTheConversationRefuses()
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", $Username, 5, .tStatus, .tLockConflict)
    Do $$$AssertTrue($IsObject(tConvo), "a probe conversation is created")
    If '$IsObject(tConvo) Quit
    Set tConvKey = tConvo.ConvKey
    Set tConvo = ""

    Set tKey = ..Seed("after", tConvKey)
    If tKey = "" Quit
    Set tMintedOn = ##class(OcuPilot.Test.ProposalFixture).Field(tKey, "TurnKey")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedAppend(tConvKey, "the message that minted it", "completed", "ok", "", 0, "[]", 0, ..#LIMITS, tMintedOn), "the minting turn is recorded")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Entry).GuardedAppend(tConvKey, "a later message", "completed", "ok", "", 0, "[]", 0, ..#LIMITS, "probe-later-turn"), "and a later turn after it")

    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#CONVERSATION, "with the conversation code")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no request reached the port")

    Do ##class(OcuPilot.Kernel.State.Entry).GuardedDeleteForConvo(tConvKey)
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tConvKey)
}

/// <p>AC4, FR-17 (definition): a definition whose version has moved, or which is gone, closes the
/// window. <code>""</code> is "no row" and is never read as <code>0</code> (DW-430).</p>
Method TestAChangedOrDeletedDefinitionRefuses()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SetDefinition(tKey, "OcuPilotProbeNoSuchDefinition", "7"), "the row is aged onto a definition version nothing carries")
    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#DEFINITION, "with the definition code")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no request reached the port")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedVersion("OcuPilotProbeNoSuchDefinition", .tVersion), "the version of a definition no row holds reads")
    Do $$$AssertEquals(tVersion, "", "as empty, which is 'no row' and never zero")
}

/// <p>AC4 and AC7, AD-30: a restraint turned on between mint and confirm refuses where the mint
/// allowed, with the shipped verdict's own code.</p>
/// <p>Mutation: hoist the restraint read to mint time -- this goes red, because the switch moves
/// after the mint.</p>
Method TestARestraintTurnedOnAfterTheMintRefuses()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Kill tValues
    Set tValues("enforcedReadOnly") = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues), "enforced read-only is turned on after the mint")

    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)
    Kill tRestore
    Set tRestore("enforcedReadOnly") = 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tRestore), "and is turned off again")

    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals($ListFind(##class(OcuPilot.Api.Error).RestraintCodes(), tCode) > 0, 1, "with a restraint code the shipped verdict produced: " _ tCode)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no request reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row is untouched")
}

/// <p>AC4 and AC7, AD-8: a declared pair the caller no longer holds refuses, naming it.</p>
Method TestARevokedPrivilegePairRefusesNamingIt()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair(..#DENIEDPAIR)
    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode, .tResult, .tDetail)
    Do ##class(OcuPilot.Test.ProposalFixture).DenyPair("")

    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the privilege code")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertTrue($IsObject(tDetail), "carrying a detail object")
    Do $$$AssertEquals(tDetail.%Get("failedPair"), ..#DENIEDPAIR, "that names the pair that failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no request reached the port")
}

/// <p>AC4, AD-6 (fingerprint): a target that moved under the diff refuses, the row closes
/// <code>canceled</code> reason <code>target-changed</code>, and nothing is written.</p>
/// <p>Mutation: compare the re-computed digest against itself instead of the stored one -- this
/// goes red.</p>
Method TestAChangedTargetRefusesAndClosesTheRow()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Name"":""/csp/ocupilotprobeconfirm"",""Description"":""moved under the diff"",""Enabled"":false}")
    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)

    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "with the target-changed code")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "no request reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "canceled", "the row closes canceled")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "target-changed", "with the reason the card renders")
}

/// <p>AC7, AD-10: the prohibited-set seam is called once, inside the transition and before the port
/// call, and answers "not prohibited" until Story 5.5 fills it.</p>
Method TestTheProhibitedSeamIsCalledOnceBeforeThePortCall()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Write).ProhibitedClass(), "", "the seam answers no prohibited set yet")
    Set tSource = ""
    Do ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Kernel.Proposal.Confirm", .tSource)
    Set tBody = $Piece(tSource, "ClassMethod Transition", 2)
    Set tBody = $Piece(tBody, "ClassMethod ChannelProblem", 1)
    Set tCalls = $Length(tBody, "..ProhibitedClassName()") - 1
    Do $$$AssertEquals(tCalls, 1, "the transition names it exactly once")
    Do $$$AssertTrue($Find(tBody, "..ProhibitedClassName()") < $Find(tBody, "..#WRITETYPE"), "and before the write goes out")
}

/// <p>AC7, AD-10: what the seam does when it answers a set -- the confirm is refused with that
/// set's own code, the row is not claimed and nothing reaches the port. Story 5.5 replaces the
/// answer, not the branch.</p>
/// <p>Mutation: invert the <code>If tProhibits</code> arm in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- this goes red.</p>
Method TestAProhibitedWriteIsRefusedBeforeThePortCall()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.ProposalFixture")
    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")

    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, "AGENT.PROHIBITED", "with the prohibited set's own code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and no request reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the token is unspent")
}

/// <p>AD-35: a declared secret-typed key is accepted by the closed channel and merged into the
/// stored payload at the port call, and nothing else in the payload moves.</p>
/// <p>The shipped descriptors declare no secret argument yet (Story 5.10 ships the first), so the
/// declared list is supplied directly here -- what is pinned is the merge and the channel's accept
/// arm, which no other test reaches.</p>
/// <p>Mutation: drop the <code>%Set</code> from
/// <method>OcuPilot.Kernel.Proposal.Confirm.WithSecrets</method>, or invert
/// <method>ChannelProblem</method>'s <code>$ListFind</code> -- this goes red.</p>
Method TestADeclaredSecretIsAcceptedAndMergedAtThePortCall()
{
    Set tNames = $ListBuild("Password")
    Set tMerged = $ClassMethod(..#CONFIRM, "MergeSecrets", "{""Name"":""/csp/probe"",""Description"":""stored""}", {"Password": "hunter2"}, tNames)
    Do $$$AssertTrue($IsObject(tMerged), "the merge answers an object")
    Do $$$AssertEquals(tMerged.%Get("Password"), "hunter2", "the declared secret reaches the body")
    Do $$$AssertEquals(tMerged.%Get("Description"), "stored", "while the stored fields are untouched")
    Do $$$AssertEquals(tMerged.%Get("Name"), "/csp/probe", "including the identifying one")

    Set tUndeclared = $ClassMethod(..#CONFIRM, "MergeSecrets", "{""Description"":""stored""}", {"Description": "from the request"}, tNames)
    Do $$$AssertEquals(tUndeclared.%Get("Description"), "stored", "and a key the list does not name is never merged")

    Set tSC = $ClassMethod(..#CONFIRM, "ChannelProblem", ..#TOOL, {"Password": "hunter2"}, .tDeclared, .tProblem)
    Do $$$AssertStatusOK(tSC, "the channel check runs")
    Do $$$AssertEquals(tProblem, 1, "and this screen, declaring no secret, refuses even that key")
    Do $$$AssertEquals($ListLength(tDeclared), 0, "because its declared list is empty")
}

/// <p>The matrix's "write fails after the claim": single-use holds, so the proposal stays confirmed
/// and burned and the port's own normalized envelope is what comes back.</p>
Method TestAFailedWriteLeavesTheProposalBurned()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWriteFault(500)
    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode, .tResult, .tDetail)

    Do $$$AssertStatusNotOK(tSC, "the confirm reports the fault")
    Do $$$AssertEquals(tHttp, 500, "at the port's own status")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 1, "the token is spent")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "confirmed", "and the row stays confirmed, so no re-attempt is possible")
    ; The caller is told the row closed even though the write did not, so a card cannot fall back
    ; to the state its last poll saw and offer Confirm on a spent token.
    Do $$$AssertTrue($IsObject($Get(tDetail)), "the refusal carries the row's new state")
    If $IsObject($Get(tDetail)) {
        Do $$$AssertEquals(tDetail.%Get("state"), "confirmed", "which is the terminal state the claim wrote")
    }

    Set tSC = ..Confirm(tKey, "", .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a second confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#BURNED, "as already decided")
}

}

/// <p>Pins what Story 24.16's suspended message writes refuse before anything changes (AD-8, AD-13, AD-21, AD-29, AD-51, AD-62): the verdict each message reads, first rule winning, so only
/// the messages still suspended, with their body and an enabled target where the action needs them, are acted on, each line naming its verdict; a set none of which can be acted on
/// (409 <code>INTEROP.SUSPENDED.NONE</code>); a review the messages moved past (409 <code>INTEROP.SUSPENDED.CHANGED</code>, and the agent's target-changed closure); a stopped production,
/// which refuses a resubmit and an edit and not a discard or a delete; a set over the cap or of a malformed id; and each missing pair, each refused 403 naming it before any vendor call.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.InteropSuspendedCase</class>). The gate legs run through the fake gate (<class>OcuPilot.Test.ScreenGate</class>). One class per run.</p>
Class OcuPilot.Test.InteropSuspendedRefusals Extends OcuPilot.Test.InteropSuspendedCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The write of each action, in the order the actions are listed.</p>
Parameter WRITES = "resubmit=RESUBMITMESSAGES,edit=EDITRESUBMIT,discard=DISCARDMESSAGES,delete=DELETEMESSAGES";

/// <p>The pairs each action's write needs beyond the viewer's two and WRITE on <code>USER</code>'s database, in the order the port asks them.</p>
Parameter EXTRAPAIRS = "resubmit=%Ens_MessageResend:USE;edit=%Ens_MessageContent:USE,%Ens_MessageResend:USE,%Ens_MessageEditResend:USE;discard=%Ens_MessageDiscard:USE;delete=%Ens_MessageDiscard:USE";

/// <p>The write type of the action <var>pKind</var>.</p>
ClassMethod WriteOf(pKind As %String) As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).SuspendedWriteType(pKind)
}

/// <p>AC4: five messages each read one verdict for a resubmit -- one that can go, one to a disabled target, one whose body is gone, one that is Completed, one no header holds -- in id
/// order with the sentence of each; the resubmit acts on the first alone and the others change nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>notsuspended</code> rule from <method>OcuPilot.Port.InteropPort.MessageVerdict</method> -- the Completed message reads
/// <code>resubmit</code> and is resubmitted, and this goes red.</p>
Method TestEachMessageIsJudgedAndOnlyTheOnesThatCanGoAreResubmitted()
{
    Set tGood = ..Susp("good")
    Set tOff = ..Susp("off", ..#OFFNAME)
    Set tNoBody = ..Susp("nobody")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DeleteBody", tNoBody), "the third message's body is deleted")
    Set tDone = ..Make("done")
    Set tSet = tGood _ "," _ tOff _ "," _ tNoBody _ "," _ tDone _ "," _ ..#GONE
    Set tCode = ..Dry("resubmit", tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    Set tExpected = ..Line(tGood, "resubmit") _ $Char(10) _ ..Line(tOff, "targetoff", , ..#OFFNAME) _ $Char(10) _ ..Line(tNoBody, "nobody") _ $Char(10) _ ..Line(tDone, "notsuspended") _ $Char(10) _ ..Line(..#GONE, "gone")
    Do $$$AssertEquals(..Lines(tDry), tExpected, "each message reads its own verdict, in id order")
    Set tCode = ..Send("resubmit", tSet, ..Digest(tDry), .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the resubmit is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) Do $$$AssertEquals(tSent.output.lines.%Size() _ "|" _ $Piece(tSent.output.lines.%Get(0), ": ", 1), "1|" _ tGood, "one line, for the message that could go")
    Do $$$AssertTrue(..Await(tGood, 9), "the first message was resubmitted and processed")
    Do $$$AssertEquals(..Status(tOff) _ "|" _ ..Status(tNoBody) _ "|" _ ..Status(tDone) _ "|" _ $ClassMethod(..#FIXTURE, "Property", tDone, "Resent"), "5|5|9|0", "the others changed nothing, the Completed one included")
}

/// <p>AC4: a discard and a delete judge a message by whether it is still suspended alone: of a suspended message, one whose body is gone, one whose target is disabled, a Completed one and an
/// id no header holds, the first three read the action's own verdict and are acted on, the lines say why for the others, and the Completed header and its body are not touched.</p>
/// <p>Mutation (Rule 19): drop the <code>notsuspended</code> rule from <method>OcuPilot.Port.InteropPort.MessageVerdict</method> -- the Completed message is deleted and this goes red; move
/// the <code>nobody</code> check above the discard and delete line -- the message with no body reads <code>nobody</code> and is not acted on, and this goes red.</p>
Method TestADiscardAndADeleteActOnTheSuspendedMessageAlone()
{
    For tKind = "discard", "delete" {
        Set tA = ..Susp("alpha " _ tKind)
        Set tNoBody = ..Susp("nobody " _ tKind)
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DeleteBody", tNoBody), tKind _ ": the second message's body is deleted")
        Set tOff = ..Susp("off " _ tKind, ..#OFFNAME)
        Set tDone = ..Make("done " _ tKind)
        Set tBody = ..BodyOf(tDone)
        Set tSet = tA _ "," _ tNoBody _ "," _ tOff _ "," _ tDone _ "," _ ..#GONE
        Set tCode = ..Dry(tKind, tSet, .tDry)
        Do $$$AssertEquals(tCode, "200 ", tKind _ ": the dry run answers")
        Do $$$AssertEquals(..Lines(tDry), ..Line(tA, tKind) _ $Char(10) _ ..Line(tNoBody, tKind) _ $Char(10) _ ..Line(tOff, tKind, , ..#OFFNAME) _ $Char(10) _ ..Line(tDone, "notsuspended") _ $Char(10) _ ..Line(..#GONE, "gone"), tKind _ ": each message reads its own verdict, the one with no body and the one to a disabled target the action's own")
        Set tCode = ..Send(tKind, tSet, ..Digest(tDry), .tSent)
        Do $$$AssertEquals(tCode, "200 ", tKind _ ": the write is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
        If $IsObject(tSent) {
            Set tNamed = ""
            For tI = 0:1:tSent.output.lines.%Size() - 1 Set tNamed = tNamed _ $Select(tNamed = "": "", 1: ",") _ $Piece(tSent.output.lines.%Get(tI), ": ", 1)
            Do $$$AssertEquals(tSent.output.lines.%Size() _ "|" _ tNamed, "3|" _ tA _ "," _ tNoBody _ "," _ tOff, tKind _ ": one line for each of the three suspended messages")
        }
        Set tActed = $Select(tKind = "discard": 4, 1: "<none>")
        Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tNoBody) _ "|" _ ..Status(tOff), tActed _ "|" _ tActed _ "|" _ tActed, tKind _ ": the three suspended messages were acted on")
        Do $$$AssertEquals(..Status(tDone) _ "|" _ ..BodyOf(tDone), "9|" _ tBody, tKind _ ": the Completed one and its body are as they were")
    }
}

/// <p>AC4: a set none of whose messages can be acted on is refused 409 <code>INTEROP.SUSPENDED.NONE</code> by the port for each of the four writes, and, as the sentence and the lines, by the
/// person's review and the agent's mint, each with nothing changed.</p>
/// <p>Mutation (Rule 19): drop the <code>Eligible</code> test in <method>OcuPilot.Port.InteropPort.PerformResend</method> -- the discard leg acts on nothing and answers 200, and this goes red.</p>
Method TestASetNoneOfWhichCanBeActedOnIsRefusedBeforeAnythingChanges()
{
    Set tDone = ..Make("done")
    Set tSet = tDone _ "," _ ..#GONE
    For tKind = "resubmit", "discard", "delete" {
        Do ..EnableKey($Parameter(..%ClassName(1), $ZConvert(tKind, "U") _ "KEY"))
    }
    Do ..EnableKey(..#EDITKEY)
    For tKind = "resubmit", "edit", "discard", "delete" {
        Do $$$AssertEquals(..SPort(..WriteOf(tKind), $Select(tKind = "edit": tDone, 1: tSet), , , $Select(tKind = "edit": "{""StringValue"":""x""}", 1: "")), "409 INTEROP.SUSPENDED.NONE", tKind _ ": the port refuses the write")
    }
    For tKind = "resubmit", "discard", "delete" {
        Set tCode = ..Dry(tKind, tSet, .tDry)
        Do $$$AssertEquals(tCode, "400 TOOL.ARGUMENTS", tKind _ ": the review of a set that can change nothing is refused")
        Do $$$AssertTrue($IsObject(tDry) && $IsObject(tDry.%Get("detail")) && (tDry.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).#REASONSUSPENDEDNONE) && (tDry.detail.%Get("problem") [ ..Line(tDone, "notsuspended")), tKind _ ": with the sentence and the line")
        Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", $Parameter(..%ClassName(1), $ZConvert(tKind, "U") _ "TOOL"), {"Messages": (tSet)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) >= 400) && '$IsObject($Get(tProposal)), tKind _ ": the agent's mint is refused and writes no proposal")
    }
    Do $$$AssertEquals(..Status(tDone) _ "|" _ $ClassMethod(..#FIXTURE, "Property", tDone, "Resent"), "9|0", "the Completed message changed nothing")
}

/// <p>AC4: a review the messages moved past is refused 409 <code>INTEROP.SUSPENDED.CHANGED</code> with nothing changed: the person's resubmit and edit, whose digest a message moved out of
/// Suspended after the review no longer matches, and the agent's, a proposal closed as a moved target on the confirm, 409 <code>PROPOSAL.TARGETCHANGED</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>pReviewed</code> comparison in <method>OcuPilot.Port.InteropPort.ReadResend</method> -- the first leg acts and goes red; leave <code>Verdicts</code>
/// out of <parameter>OcuPilot.Screen.Tool.InteropSuspendedAction.FINGERPRINTSUBJECT</parameter> -- the agent's leg goes red.</p>
Method TestAReviewThatMovedIsRefusedAndNothingChanges()
{
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tSet = tA _ "," _ tB
    Set tCode = ..Dry("resubmit", tSet, .tDry)
    Set tDigest = ..Digest(tDry)
    Do $$$AssertStatusOK(..Move(tB, 4), "the second message is discarded after the review")
    Set tCode = ..Send("resubmit", tSet, tDigest, .tRefused)
    Do $$$AssertEquals(tCode, "409 INTEROP.SUSPENDED.CHANGED", "the digest of the earlier review is refused: " _ $Select($IsObject(tRefused): tRefused.%ToJSON(), 1: tRefused))
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "5|4", "and nothing was resubmitted")
    Set tF = ..Susp("phi")
    Set tCode = ..Dry("editresubmit", tF, .tEdit, "{""StringValue"":""edited""}")
    Set tEditDigest = ..Digest(tEdit)
    Do $$$AssertEquals(tCode, "200 ", "an edit is reviewed")
    Do $$$AssertStatusOK(..Move(tF, 4), "and the message is discarded after it")
    Set tCode = ..Send("editresubmit", tF, tEditDigest, .tEditRefused, "{""StringValue"":""edited""}")
    Do $$$AssertEquals(tCode, "409 INTEROP.SUSPENDED.CHANGED", "the edit's digest is refused too: " _ $Select($IsObject(tEditRefused): tEditRefused.%ToJSON(), 1: tEditRefused))
    Set tC = ..Susp("gamma")
    Set tD = ..Susp("delta")
    Do ..EnableKey(..#RESUBMITKEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#RESUBMITTOOL, {"Messages": (tC _ "," _ tD)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's resubmit mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK(..Move(tD, 4), "the second message is discarded after the mint")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Status(tC) _ "|" _ ..Status(tD), "5|4", "and nothing was resubmitted")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC4: a production that is not running refuses a resubmit and an edit and resubmit, 409 <code>INTEROP.PRODUCTION.NOTRUNNING</code>, through the review and the port's reads and writes, with nothing
/// changed; a discard and a delete need no production and are reviewed all the same.</p>
/// <p>Mutation (Rule 19): drop the not-running refusal from <method>OcuPilot.Port.InteropPort.ReadResend</method> -- the resubmit legs go red.</p>
Method TestAStoppedProductionRefusesAResubmitAndAnEditAndNotADiscardOrADelete()
{
    Set tA = ..Susp("alpha")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the production is stopped")
    Do $$$AssertEquals(..Dry("resubmit", tA), "409 INTEROP.PRODUCTION.NOTRUNNING", "the resubmit's review is refused")
    Do $$$AssertEquals(..Dry("editresubmit", tA), "409 INTEROP.PRODUCTION.NOTRUNNING", "and the edit's")
    Do $$$AssertEquals(..SPort("RESUBMIT", tA) _ "|" _ ..SPort("RESUBMITMESSAGES", tA) _ "|" _ ..SPort("EDITSUBMIT", tA) _ "|" _ ..SPort("EDITRESUBMIT", tA, , , "{""StringValue"":""x""}"), "409 INTEROP.PRODUCTION.NOTRUNNING|409 INTEROP.PRODUCTION.NOTRUNNING|409 INTEROP.PRODUCTION.NOTRUNNING|409 INTEROP.PRODUCTION.NOTRUNNING", "as are the port's four calls")
    Do $$$AssertEquals(..Dry("discard", tA) _ "|" _ ..Dry("delete", tA), "200 |200 ", "a discard and a delete are reviewed with the production stopped")
    Do $$$AssertEquals(..Status(tA), 5, "nothing changed")
}

/// <p>AC4: a set of 100 message ids is read, 101 is refused whole 400 <code>PORT.VALIDATION</code> by the port, the review, the action and the agent's mint for each action, and so is an
/// empty set and a member that is not a message id; nothing changes.</p>
/// <p>Mutation (Rule 19): raise <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> to 101 -- the cap legs go red.</p>
Method TestASetOverTheCapOrMalformedIsRefusedWholeForEveryAction()
{
    Set tA = ..Susp("alpha")
    Set tHundred = ""
    Set tMore = ""
    For tI = 1:1:101 {
        Set tId = 900000000 + tI
        If tI <= 100 Set tHundred = tHundred _ $Select(tHundred = "": "", 1: ",") _ tId
        Set tMore = tMore _ $Select(tMore = "": "", 1: ",") _ tId
    }
    Do $$$AssertEquals(..SPort("DELETE", tHundred, .tRead), "200 ", "a set of 100 ids is read")
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.Messages.%Size() _ "|" _ tRead.Eligible, 1: ""), "100|0", "each answers a verdict and none can go")
    For tType = "RESUBMIT", "RESUBMITMESSAGES", "DISCARD", "DISCARDMESSAGES", "DELETE", "DELETEMESSAGES" {
        Do $$$AssertEquals(..SPort(tType, tMore, , , , , .tFault), "400 PORT.VALIDATION", tType _ ": 101 ids are refused whole")
        Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() [ "Messages must name 1 to 100 message header IDs"), tType _ ": naming Messages and the cap")
    }
    For tKind = "resubmit", "discard", "delete" {
        Do $$$AssertEquals(..Dry(tKind, tMore) _ "|" _ ..Send(tKind, tMore, "0"), "400 PORT.VALIDATION|400 PORT.VALIDATION", tKind _ ": the review and the action refuse it")
        Do ..EnableKey($Parameter(..%ClassName(1), $ZConvert(tKind, "U") _ "KEY"))
        Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", $Parameter(..%ClassName(1), $ZConvert(tKind, "U") _ "TOOL"), {"Messages": (tMore)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) = 400) && '$IsObject($Get(tProposal)), tKind _ ": the agent's mint refuses it")
    }
    For tBad = "", "0x1", "007", "12,,13", "abc", "1.5" {
        Do $$$AssertEquals(..SPort("DISCARD", tBad) _ "|" _ ..SPort("EDITSUBMIT", tBad), "400 PORT.VALIDATION|400 PORT.VALIDATION", "'" _ tBad _ "' is refused")
    }
    Do $$$AssertEquals(..Status(tA), 5, "nothing changed")
}

/// <p>AC4: each pair a write needs -- the Interoperability menu's, the message viewer's, the action's own (the Resend page's, the edit's three, the Discard page's), and WRITE on <code>USER</code>'s
/// database -- is refused 403 <code>AUTH.NOPRIVILEGE</code> naming it when it alone is missing, for each of the four writes, before any vendor call; the caller holding all of them is admitted.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageDiscard:USE</code> from the Suspended messages branch of <method>OcuPilot.Port.InteropPort.Pairs</method> -- the discard and delete legs
/// go red.</p>
Method TestEachMissingPairIsRefusedByNameBeforeAnyVendorCall()
{
    Set tA = ..Susp("alpha")
    Set tExtras = ..#EXTRAPAIRS
    Do $ClassMethod(..#SEAM, "Arm")
    For tI = 1:1:$Length(..#WRITES, ",") {
        Set tKind = $Piece($Piece(..#WRITES, ",", tI), "=", 1)
        Set tType = $Piece($Piece(..#WRITES, ",", tI), "=", 2)
        Set tFields = $Select(tKind = "edit": "{""StringValue"":""x""}", 1: "")
        Set tPairs = "%Ens_Portal:USE,%Ens_MessageHeader:USE"
        For tJ = 1:1:$Length(tExtras, ";") {
            If $Piece($Piece(tExtras, ";", tJ), "=", 1) = tKind Set tPairs = tPairs _ "," _ $Piece($Piece(tExtras, ";", tJ), "=", 2)
        }
        Set tPairs = tPairs _ ",%DB_USER:WRITE"
        For tMissing = 1:1:$Length(tPairs, ",") {
            Do ##class(OcuPilot.Test.ScreenGate).Reset()
            For tHeld = 1:1:$Length(tPairs, ",") {
                If tHeld '= tMissing Do ##class(OcuPilot.Test.ScreenGate).Hold($Piece($Piece(tPairs, ",", tHeld), ":", 1), $Piece($Piece(tPairs, ",", tHeld), ":", 2))
            }
            Set tCode = ..SPort(tType, tA, , , tFields, , .tFault, ..#NAMESPACE, ..#SEAM)
            Do $$$AssertEquals(tCode _ "|" _ $Select($IsObject(tFault): tFault.detail.failedPair, 1: ""), "403 AUTH.NOPRIVILEGE|" _ $Piece(tPairs, ",", tMissing), tKind _ ": without " _ $Piece(tPairs, ",", tMissing))
        }
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
    }
    Do $$$AssertEquals(..Status(tA) _ "|" _ $ClassMethod(..#FIXTURE, "Property", tA, "Resent"), "5|0", "no refused call reached the vendor")
    Do ..HoldFor("discard")
    Do $$$AssertEquals(..SPort("DISCARDMESSAGES", tA, , , , , , ..#NAMESPACE, ..#SEAM), "200 ", "the caller holding the discard's pairs is admitted")
    Do $$$AssertEquals(..Status(tA), 4, "and the message was discarded")
}

}

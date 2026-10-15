/// <p>Pins Story 20.31's message resend end to end against a running probe production in <code>USER</code> (AD-6, AD-13, AD-22, AD-34,
/// AD-51, AD-53, AD-58, AD-62): the agent's resend of two stored messages, minted and confirmed over HTTP while its key is on, and the
/// person's, reviewed through <code>POST /screens/interop.messages/dryrun</code> and sent with the digest it was reviewed at; the
/// verdict each message reads, the set that can send nothing, the stopped production and the set over the cap, each refused with
/// nothing sent; a verdict that moves between review and send (the person's <code>INTEROP.RESEND.CHANGED</code>, the agent's
/// target-changed closure); a vendor refusal of one message that leaves the rest sent; the governance key at its shipped value; and
/// the Visual Trace of the original naming the new header.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> and sends messages to it (<class>OcuPilot.Test.InteropResendCase</class>). One class per run.</p>
Class OcuPilot.Test.InteropResend Extends OcuPilot.Test.InteropResendCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropMessageResend";

Parameter KEY = "interop.messages.resend";

Parameter SCREEN = "/screens/interop.messages";

/// <p>The person's review of resending the messages <var>pSet</var> (<code>POST /dryrun</code>): <code>status code</code>.</p>
ClassMethod Dry(pSet As %String, Output pAnswer) As %String
{
    Set tBody = {"action": "resend"}
    Do tBody.%Set("id", pSet, "string")
    Quit ..Post(..#SCREEN _ "/dryrun", tBody, .pAnswer)
}

/// <p>The person's resend of <var>pSet</var> carrying the digest <var>pReviewed</var> (<code>POST /action</code>):
/// <code>status code</code>.</p>
ClassMethod Send(pSet As %String, pReviewed As %String, Output pAnswer) As %String
{
    Set tBody = {"action": "resend"}
    Do tBody.%Set("id", pSet, "string")
    Set tValues = {}
    Do tValues.%Set("Reviewed", pReviewed, "string")
    Do tBody.%Set("values", tValues)
    Quit ..Post(..#SCREEN _ "/action", tBody, .pAnswer)
}

/// <p>The Messages card or dialog text of the dry run <var>pAnswer</var>, one line for each message, newline-separated.</p>
ClassMethod Lines(pAnswer) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("rows")) || (pAnswer.rows.%Size() '= 1) Quit ""
    Quit pAnswer.rows.%Get(0).after
}

/// <p>The line a message reads in the dialog: its id, source and target, then the sentence of verdict <var>pVerdict</var>.</p>
ClassMethod Line(pId As %String, pVerdict As %String, pSource As %String = {..#SVCNAME}, pTarget As %String = {..#OPNAME}) As %String
{
    Set tSentence = ##class(OcuPilot.Api.InteropError).VerdictSentence(pVerdict)
    If pVerdict = "gone" Quit pId _ ": " _ tSentence
    Quit pId _ " " _ $Char(183) _ " " _ pSource _ " " _ $Char(8594) _ " " _ pTarget _ ": " _ tSentence
}

/// <p>AC3, AC6: the agent's resend of two messages, named in the reverse order, minted and confirmed over HTTP while its key is on,
/// sends each again as a new header in its own session, flagged resent and sharing its body; the card shows one row of both lines,
/// the target is the canonical set and destructive; the answer carries <code>&lt;id&gt;: resent as &lt;new&gt;</code> for each,
/// publishes <code>created</code>, is marked and ledgered once; and the vendor audits each new header while OcuPilot records no
/// change row of its own.</p>
/// <p>Mutation (Rule 19): skip <code>VendorResend</code> in <method>OcuPilot.Port.InteropPort.PerformResend</method> -- the new-header
/// and audit legs go red.</p>
Method TestTheAgentsResendConfirmsOverHttp()
{
    Set tA = ..Make("alpha")
    Set tB = ..Make("beta")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do ..EnableKey(..#KEY)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Messages": (tB _ " , " _ tA _ "," _ tB)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, ..#KEY _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tLines = ..Line(tA, "resend") _ $Char(10) _ ..Line(tB, "resend")
    Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).field _ "|" _ tProposal.changed.%Get(0).before, "1|Messages|", "the card shows one Messages row")
    Do $$$AssertEquals(tProposal.changed.%Get(0).after, tLines, "its after-value is the two lines in id order")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-message|USER|" _ tA _ "," _ tB, "the target is the canonical set, whatever the spelling")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.MESSAGE.RESEND|1", "its consequence code, and it is destructive")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|created", "created and marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, ..#KEY), 1, "the confirmed write is in the ledger once")
    Set tNewA = $Piece(tAnswer.output.lines.%Get(0), ": resent as ", 2)
    Set tNewB = $Piece(tAnswer.output.lines.%Get(1), ": resent as ", 2)
    Do $$$AssertEquals(tAnswer.output.lines.%Size() _ "|" _ (tNewA > tTop) _ "|" _ (tNewB > tNewA) _ "|" _ $Piece(tAnswer.output.lines.%Get(0), ": ", 1) _ "|" _ $Piece(tAnswer.output.lines.%Get(1), ": ", 1), "2|1|1|" _ tA _ "|" _ tB, "the answer names each message and the header it was sent as")
    For tCase = $ListBuild(tA, tNewA), $ListBuild(tB, tNewB) {
        Set tOriginal = $List(tCase, 1)
        Set tNew = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tNew, "SessionId"), $ClassMethod(..#FIXTURE, "Property", tOriginal, "SessionId"), tOriginal _ ": the new header is in the original's session")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tNew, "Resent") _ "|" _ $ClassMethod(..#FIXTURE, "Property", tNew, "Description"), "1|Resent " _ tOriginal, tOriginal _ ": it is flagged resent and says of which")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tNew, "MessageBodyId"), $ClassMethod(..#FIXTURE, "Property", tOriginal, "MessageBodyId"), tOriginal _ ": it shares the original's body")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tOriginal, "Resent"), 0, tOriginal _ ": the original is not changed")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tNew, .tData), 1, tOriginal _ ": the vendor audited the resend as new header " _ tNew)
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""interop-message""", .tOwn), 0, "OcuPilot records no change row of its own, for the set or for either message")
}

/// <p>AC1, AC4, AC8: the person's resend is reviewed first and sent with the digest of the review. The dry run answers the one
/// Messages row and a digest and sends nothing; the action carrying it resends and answers the lines; a message whose target is
/// disabled between review and send moves the digest, so the same digest is refused 409 <code>INTEROP.RESEND.CHANGED</code> with
/// nothing sent; and the Visual Trace of an original names the header it was resent as.</p>
/// <p>Mutation (Rule 19): drop the <code>pReviewed</code> comparison in <method>OcuPilot.Port.InteropPort.ReadResend</method> -- the
/// CHANGED leg sends and goes red.</p>
Method TestThePersonsResendIsReviewedThenSentAndRefusedWhenTheVerdictsMove()
{
    Set tA = ..Make("alpha")
    Set tC = ..Make("gamma", ..#TWONAME)
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSet = tA _ "," _ tC
    Set tCode = ..Dry(tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers 200: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    Do $$$AssertEquals(..Lines(tDry), ..Line(tA, "resend") _ $Char(10) _ ..Line(tC, "resend", , ..#TWONAME), "its one row reads both messages")
    Set tDigest = $Select($IsObject(tDry) && $IsObject(tDry.%Get("review")): tDry.review.Digest, 1: "")
    Do $$$AssertEquals($Length(tDigest), 64, "and carries the digest of the verdicts")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "the review sent nothing")
    Set tCode = ..Send(tSet, tDigest, .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the action carrying the digest is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) {
        Do $$$AssertEquals(tSent.action _ "|" _ tSent.target.type _ "|" _ tSent.target.id _ "|" _ tSent.output.lines.%Size(), "created|interop-message|" _ tSet _ "|2", "it publishes the created event for the set and answers a line for each message")
        Set tNewA = $Piece(tSent.output.lines.%Get(0), ": resent as ", 2)
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tNewA, "Resent"), 1, "the first message was sent again")
    }
    Do $$$AssertEquals(..Post(..#SCREEN _ "/action", {"action": "resend"}, .tNoId), "400 TOOL.ARGUMENTS", "an action naming no messages is refused")

    ; The Visual Trace of the original lists the new header in the same session.
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("message") = tA
    Set tSC = $ClassMethod(..#PORT, "Invoke", "MessageTrace", "LIST", .tQuery, "", .tRows, .tTraceHttp, .tFault)
    Set tSteps = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tSteps = tSteps _ $Select(tSteps = "": "", 1: ",") _ tRow.%Get("ID")
        }
    }
    Do $$$AssertEquals(tSteps, tA _ "," _ $Get(tNewA), "the original's trace names the header it was resent as")

    ; The verdicts move between review and send.
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Dry(tSet, .tSecond)
    Set tReviewed = $Select($IsObject(tSecond) && $IsObject(tSecond.%Get("review")): tSecond.review.Digest, 1: "")
    Do $$$AssertEquals(tCode _ "|" _ (tReviewed = tDigest), "200 |1", "the same set reviewed again gives the same digest")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetEnabled", ..#TWONAME, 0), "the second operation is disabled after the review")
    Set tCode = ..Send(tSet, tReviewed, .tRefused)
    Do $$$AssertEquals(tCode, "409 INTEROP.RESEND.CHANGED", "the digest of the earlier review is refused: " _ $Select($IsObject(tRefused): tRefused.%ToJSON(), 1: tRefused))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Set tCode = ..Dry(tSet, .tThird)
    Do $$$AssertEquals(..Lines(tThird), ..Line(tA, "resend") _ $Char(10) _ ..Line(tC, "targetoff", , ..#TWONAME), "a review now reads the second message as held back")
}

/// <p>AC1: five messages each read one verdict -- one that can go, one to a disabled target, one whose body is gone, one response whose
/// reply queue is gone, one no header holds -- in id order with the sentence of each; the resend sends the first alone, in its own
/// session, and the others' sessions gain no header.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.MessageVerdict</method> read <code>resend</code> for
/// <code>targetoff</code> -- the held-back leg sends a copy and goes red.</p>
Method TestEachMessageIsJudgedAndOnlyTheOnesThatCanGoAreSent()
{
    Set tGood = ..Make("good")
    Set tOff = ..Make("off", ..#OFFNAME)
    Set tNoBody = ..Make("nobody")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DeleteBody", tNoBody), "the third message's body is deleted")
    Set tAsked = ..Make("asked")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StoredResponse", tAsked, $Parameter(..#FIXTURE, "NOQUEUE"), .tNoReply), "a response replying to a queue no production has is stored")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSet = tGood _ "," _ tOff _ "," _ tNoBody _ "," _ tNoReply _ "," _ ..#GONE
    Set tCode = ..Dry(tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    Set tReply = $ClassMethod(..#FIXTURE, "Property", tNoReply, "SourceConfigName")
    Set tReplyTarget = $ClassMethod(..#FIXTURE, "Property", tNoReply, "TargetConfigName")
    Set tExpected = ..Line(tGood, "resend") _ $Char(10) _ ..Line(tOff, "targetoff", , ..#OFFNAME) _ $Char(10) _ ..Line(tNoBody, "nobody") _ $Char(10) _ ..Line(tNoReply, "noreplyqueue", tReply, tReplyTarget) _ $Char(10) _ ..Line(..#GONE, "gone")
    Do $$$AssertEquals(..Lines(tDry), tExpected, "each message reads its own verdict, in id order")
    Set tCode = ..Send(tSet, tDry.review.Digest, .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the resend is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) Do $$$AssertEquals(tSent.output.lines.%Size() _ "|" _ $Piece(tSent.output.lines.%Get(0), ": ", 1), "1|" _ tGood, "one line, for the message that could go")
    Do $$$AssertEquals($Length($ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tGood, "SessionId"), tTop), ";") _ "|" _ $ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tOff, "SessionId"), tTop) _ "|" _ $ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tNoBody, "SessionId"), tTop), "1||", "only the first message's session gained a header")
}

/// <p>AC1, AC3: a set none of whose messages can go is refused 409 <code>INTEROP.RESEND.NONE</code> by the port and, as the sentence and
/// the lines, by the person's review and the agent's mint; a production that is not running is refused 409
/// <code>INTEROP.PRODUCTION.NOTRUNNING</code> by the review and the port; each with nothing sent.</p>
/// <p>Mutation (Rule 19): drop the <code>Eligible</code> test in <method>OcuPilot.Port.InteropPort.PerformResend</method> -- the port
/// leg goes red.</p>
Method TestNothingToSendAndAStoppedProductionAreRefusedBeforeAnythingIsSent()
{
    Set tOff = ..Make("off", ..#OFFNAME)
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Dry(tOff, .tDry)
    Do $$$AssertEquals(tCode, "400 TOOL.ARGUMENTS", "the review of a set that can send nothing is refused: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    Do $$$AssertTrue($IsObject(tDry) && $IsObject(tDry.%Get("detail")) && (tDry.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).#REASONRESENDNONE) && (tDry.detail.%Get("problem") [ ..Line(tOff, "targetoff", , ..#OFFNAME)), "with the sentence and the line")
    Do $$$AssertEquals(..Port("RESENDMESSAGES", tOff), "409 INTEROP.RESEND.NONE", "the port refuses the write")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Messages": (tOff)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) >= 400) && '$IsObject($Get(tProposal)), "the agent's mint is refused and writes no proposal: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: $Get(tHttp)))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent")
    Set tGood = ..Make("good")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the production is stopped")
    Do $$$AssertEquals(..Dry(tGood), "409 INTEROP.PRODUCTION.NOTRUNNING", "the review is refused for it")
    Do $$$AssertEquals(..Port("RESEND", tGood) _ "|" _ ..Port("RESENDMESSAGES", tGood), "409 INTEROP.PRODUCTION.NOTRUNNING|409 INTEROP.PRODUCTION.NOTRUNNING", "and so are the port's read and write")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent")
}

/// <p>AC2: a set of 100 message ids is read, 101 is refused whole 400 <code>PORT.VALIDATION</code> by the port, the review and the
/// agent's mint, and so are an empty set and a member that is not a message id (<code>0x1</code>, <code>007</code>, an empty member);
/// repeats fold to one, and nothing is sent.</p>
/// <p>Mutation (Rule 19): raise <parameter>OcuPilot.Port.InteropPort.RESENDMAX</parameter> to 101 -- the cap legs go red.</p>
Method TestASetOverTheCapOrMalformedIsRefusedWholeAndNothingIsSent()
{
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tHundred = ""
    Set tMore = ""
    For tI = 1:1:101 {
        Set tId = 900000000 + tI
        If tI <= 100 Set tHundred = tHundred _ $Select(tHundred = "": "", 1: ",") _ tId
        Set tMore = tMore _ $Select(tMore = "": "", 1: ",") _ tId
    }
    Do $$$AssertEquals(..Port("RESEND", tHundred, .tRead), "200 ", "a set of 100 ids is read")
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.Messages.%Size() _ "|" _ tRead.Eligible, 1: ""), "100|0", "each answers a verdict and none can go")
    Do $$$AssertEquals(..Port("RESEND", tMore, , , , , .tFault) _ "|" _ ..Port("RESENDMESSAGES", tMore), "400 PORT.VALIDATION|400 PORT.VALIDATION", "a set of 101 is refused whole")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() [ "Messages must name 1 to 100 message header IDs"), "the refusal names Messages and the cap: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Dry(tMore, .tDry), "400 PORT.VALIDATION", "the review refuses it")
    Do $$$AssertTrue($IsObject(tDry) && (tDry.%ToJSON() [ "Messages must name 1 to 100 message header IDs"), "naming Messages and the cap")
    Do $$$AssertEquals(..Send(tMore, "0", .tSent), "400 PORT.VALIDATION", "and so does the action, whatever digest it carries")
    Do $$$AssertTrue($IsObject(tSent) && (tSent.%ToJSON() [ "Messages must name 1 to 100 message header IDs"), "naming Messages and the cap")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Messages": (tMore)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && ($Get(tHttp) = 400) && '$IsObject($Get(tProposal)), "the agent's mint refuses it: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: $Get(tHttp)))
    For tBad = "", "0x1", "007", "12,,13", "abc", "1.5" {
        Do $$$AssertEquals(..Port("RESEND", tBad), "400 PORT.VALIDATION", "'" _ tBad _ "' is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent")
}

/// <p>AC3: a proposal minted for a set whose verdicts then move (a target disabled before the confirm) is closed target-changed on
/// the confirm, 409 <code>PROPOSAL.TARGETCHANGED</code>, with nothing sent; a fresh mint and confirm then send the one message that
/// can still go.</p>
/// <p>Mutation (Rule 19): leave <code>Verdicts</code> out of <parameter>OcuPilot.Screen.Tool.InteropMessageResend.FINGERPRINTSUBJECT</parameter>
/// -- the confirm sends both and this goes red.</p>
Method TestTheAgentsConfirmIsRefusedWhenTheVerdictsMovedAfterTheMint()
{
    Set tA = ..Make("alpha")
    Set tC = ..Make("gamma", ..#TWONAME)
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Messages": (tA _ "," _ tC)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the resend mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetEnabled", ..#TWONAME, 0), "the second operation is disabled after the mint")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Messages": (tA _ "," _ tC)}, tUser, .tFresh, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "a fresh mint reads the second message as held back")
    If '$IsObject($Get(tFresh)) Quit
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tFresh.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.output.lines.%Size(), 1: ""), "200|1", "and its confirm sends the one that can go: " _ $Extract($Get(tRaw), 1, 300))
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>A message the vendor refuses is recorded with the vendor's text and the rest of the set is still sent, in id order; the
/// refusal is logged once and the answer counts what was sent and what was not.</p>
/// <p>Mutation (Rule 19): quit the loop in <method>OcuPilot.Port.InteropPort.PerformResend</method> at the first refusal -- the third
/// message is not sent and this goes red.</p>
Method TestAVendorRefusalOfOneMessageLeavesTheRestSent()
{
    Set tA = ..Make("alpha")
    Set tB = ..Make("beta")
    Set tC = ..Make("gamma")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do ..HoldPairs()
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailResendOf", tB)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tA _ "," _ tB _ "," _ tC
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Messages", "RESENDMESSAGES", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "200 ", "the write is admitted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.Resent _ "|" _ tResult.Failed _ "|" _ tResult.Messages.%Size(), "2|1|3", "two were sent, one was not, and each has an entry")
    Do $$$AssertEquals(tResult.Messages.%Get(0).ID _ "|" _ (tResult.Messages.%Get(0).NewId > tTop) _ "|" _ tResult.Messages.%Get(2).ID _ "|" _ (tResult.Messages.%Get(2).NewId > tTop), tA _ "|1|" _ tC _ "|1", "the first and the third were sent again")
    Do $$$AssertEquals(tResult.Messages.%Get(1).ID _ "|" _ (tResult.Messages.%Get(1).%Get("NewId") = ""), tB _ "|1", "the second has no new header")
    Do $$$AssertTrue(tResult.Messages.%Get(1).Error [ "resend refused for the test", "and carries the vendor's text: " _ tResult.Messages.%Get(1).Error)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tB, "SessionId"), tTop), "", "the refused message's session gained no header")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 1, "the refusal was logged once")
}

/// <p>AD-59: the copy-out draft of a resend renders one <code>ResendDuplicatedMessage</code> line for each message the proposal reviewed
/// as <code>resend</code> and none for one held back, closes the proposal as a draft and sends nothing; running the script does what the
/// write does.</p>
/// <p>Mutation (Rule 19): render every id of the set in <method>OcuPilot.Port.InteropPort.MessageSnippet</method> -- the held-back
/// message is sent by the script and this goes red.</p>
Method TestTheCopyOutDraftOfAResendRendersItsScriptAndRunningItDoesTheSame()
{
    Set tA = ..Make("alpha")
    Set tOff = ..Make("off", ..#OFFNAME)
    Set tB = ..Make("beta")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Messages": (tA _ "," _ tOff _ "," _ tB)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the resend mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSC = ..TakeDraft(tProposal.proposalId, .tDraft, .tText)
    Do $$$AssertStatusOK(tSC, "the draft is taken")
    If '$IsObject($Get(tDraft)) Quit
    Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", "an ObjectScript draft that closes the proposal")
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "ResendDuplicatedMessage(""" _ tA _ """, .tNew)") && (tText [ "ResendDuplicatedMessage(""" _ tB _ """, .tNew)") && (tText '[ ("ResendDuplicatedMessage(""" _ tOff _ """")), "one line for each message that could go, none for the one held back: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "the draft sent nothing")
    Do $$$AssertStatusOK(..RunScript(tText), "the script runs")
    Do $$$AssertEquals($Length($ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tA, "SessionId"), tTop), ";") _ "|" _ $Length($ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tB, "SessionId"), tTop), ";") _ "|" _ $ClassMethod(..#FIXTURE, "Session", $ClassMethod(..#FIXTURE, "Property", tOff, "SessionId"), tTop), "1|1|", "and sends the two that could go and not the third")
}

/// <p>AC3: the agent's resend is refused by governance at its shipped value, with nothing minted and nothing sent.</p>
/// <p>Mutation (Rule 19): set <code>interop.messages.resend</code> <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class>
/// -- the dispatch mints and this goes red.</p>
Method TestTheAgentsResendIsRefusedByGovernanceAtItsShippedValue()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tStored), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tStored), "and leaves every key to the baseline")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_resend", "input": {"rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.input.%Set("Messages", tA, "string")
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#KEY), "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tAnswer = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
    Do $$$AssertEquals(tAnswer, "1|{""code"":""GOVERNANCE.DISABLED""}", "the agent's resend is refused by governance")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
}

}

/// <p>Pins Story 24.16's resubmit and edit-and-resubmit of suspended messages end to end against a running probe production in <code>USER</code> (AD-6, AD-13, AD-22, AD-34,
/// AD-51, AD-53, AD-58, AD-59, AD-62): the person's resubmit, reviewed through <code>POST /screens/interop.suspendedmessages/dryrun</code> and sent with the digest it was
/// reviewed at, and the agent's, minted and confirmed over HTTP while its key is on, each put the suspended headers back on their target's queue under their own ids, where the
/// running production processes them, and leave the vendor's own audit row and none of OcuPilot's; the edit and resubmit of one message, from both callers, saves a copy of the body
/// that carries the change, resubmits the header under its own id with it and leaves the original body as it was; and the copy-out draft of each renders its script, sends nothing
/// and, run, does what the write does.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> and sends messages to it (<class>OcuPilot.Test.InteropSuspendedCase</class>). One class per run.</p>
Class OcuPilot.Test.InteropSuspendedResubmit Extends OcuPilot.Test.InteropSuspendedCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The line a resubmitted message reads in an outcome: <code>&lt;id&gt;: resubmitted</code>.</p>
ClassMethod Done(pId As %String) As %String
{
    Quit pId _ ": " _ ##class(OcuPilot.Api.InteropError).#OUTCOMERESUBMITTED
}

/// <p>The text of the outcome lines of the confirm or action answer <var>pAnswer</var>, newline-separated.</p>
ClassMethod Outcome(pAnswer) As %String
{
    Set tText = ""
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("output")) || '$IsObject(pAnswer.output.%Get("lines")) Quit tText
    Set tIterator = pAnswer.output.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tLine
    }
    Quit tText
}

/// <p>AC2: the person's resubmit of two suspended messages is reviewed, then sent with the digest of the review. The dry run answers the one Messages row, a digest and sends
/// nothing; the action carrying it publishes <code>updated</code> for the set and answers a line for each message; each header keeps its id, leaves Suspended and, with the
/// production running, reads Completed once it is processed, flagged resent and described as resubmitted, with its body untouched; the vendor audits each resubmit once and
/// OcuPilot records no row of its own.</p>
/// <p>Mutation (Rule 19): skip <code>VendorSuspended</code> in <method>OcuPilot.Port.InteropPort.PerformResend</method> for a resubmit -- the status legs go red.</p>
Method TestThePersonsResubmitIsReviewedThenSentUnderTheSameIds()
{
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tBodyA = ..BodyOf(tA)
    Set tSet = tA _ "," _ tB
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..Dry("resubmit", tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers 200: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    Do $$$AssertEquals(..Lines(tDry), ..Line(tA, "resubmit") _ $Char(10) _ ..Line(tB, "resubmit"), "its one row reads both messages")
    Set tDigest = ..Digest(tDry)
    Do $$$AssertEquals($Length(tDigest), 64, "and carries the digest of the verdicts")
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "5|5", "the review changed nothing")
    Set tCode = ..Send("resubmit", tSet, tDigest, .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the action carrying the digest is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) Do $$$AssertEquals(tSent.action _ "|" _ tSent.target.type _ "|" _ tSent.target.id _ "|" _ ..Outcome(tSent), "updated|interop-message|" _ tSet _ "|" _ ..Done(tA) _ $Char(10) _ ..Done(tB), "it publishes the updated event for the set and answers a line for each message")
    Do $$$AssertTrue(..Await(tA, 9) && ..Await(tB, 9), "the running production processed both: " _ ..Status(tA) _ "," _ ..Status(tB))
    For tId = tA, tB {
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tId, "Resent") _ "|" _ $ClassMethod(..#FIXTURE, "Property", tId, "Description"), "1|Resubmitted", tId _ ": flagged resent, under its own id")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tId, .tData), 1, tId _ ": the vendor audited the resubmit once")
    }
    Do $$$AssertEquals(..BodyOf(tA), tBodyA, "the body is the one the message held")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""interop-message""", .tOwn), 0, "OcuPilot records no change row of its own")
}

/// <p>AC2: the agent's resubmit of two suspended messages, named in the reverse order, minted and confirmed over HTTP while its key is on, resubmits each; the card shows one
/// row of both lines, the target is the canonical set and the proposal is destructive with its own consequence; the answer names each message, publishes <code>updated</code>, is
/// marked and ledgered once; and the vendor audits each resubmit.</p>
/// <p>Mutation (Rule 19): leave <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropSuspendedAction.FINGERPRINTSUBJECT</parameter> -- the confirm-elsewhere class
/// goes red; and leave <code>Verdicts</code> out -- the moved leg of <class>OcuPilot.Test.InteropSuspendedRefusals</class> goes red.</p>
Method TestTheAgentsResubmitConfirmsOverHttp()
{
    Set tC = ..Susp("gamma")
    Set tD = ..Susp("delta")
    Do ..EnableKey(..#RESUBMITKEY)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#RESUBMITTOOL, {"Messages": (tD _ " , " _ tC _ "," _ tD)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, ..#RESUBMITKEY _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).field _ "|" _ tProposal.changed.%Get(0).after, "1|Messages|" _ ..Line(tC, "resubmit") _ $Char(10) _ ..Line(tD, "resubmit"), "the card shows one Messages row of the two lines in id order")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-message|USER|" _ tC _ "," _ tD, "the target is the canonical set")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.SUSPENDED.RESUBMIT|1", "its consequence code, and it is destructive")
    Do $$$AssertEquals(..Status(tC) _ "|" _ ..Status(tD), "5|5", "the mint changed nothing")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|updated", "updated and marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, ..#RESUBMITKEY), 1, "the confirmed write is in the ledger once")
    Do $$$AssertEquals(..Outcome(tAnswer), ..Done(tC) _ $Char(10) _ ..Done(tD), "the answer names each message")
    Do $$$AssertTrue(..Await(tC, 9) && ..Await(tD, 9), "the running production processed both")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tC, .tData) _ "|" _ $ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tD, .tData), "1|1", "the vendor audited each resubmit")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""interop-message""", .tOwn), 0, "OcuPilot records no change row of its own")
}

/// <p>AC2: the agent's edit and resubmit of a string request, minted and confirmed over HTTP while its key is on, resubmits the header under its own id with a copy of its body
/// that carries the new value; the card shows one Body row of the field before and after and is destructive; the original body is not changed; the vendor audits the resubmit.</p>
/// <p>Mutation (Rule 19): resubmit without the clone in <method>OcuPilot.Port.InteropPort.VendorResubmitWithBody</method> -- the header keeps its body and the copy legs go red.</p>
Method TestTheAgentsEditAndResubmitSavesACopyAndKeepsTheId()
{
    Set tE = ..Susp("alpha")
    Set tOld = ..BodyOf(tE)
    Do ..EnableKey(..#EDITKEY)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EDITTOOL, {"Message": (tE), "Fields": {"StringValue": "edited"}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, ..#EDITKEY _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).field _ "|" _ tProposal.changed.%Get(0).before _ "|" _ tProposal.changed.%Get(0).after, "1|Body|StringValue: alpha|StringValue: edited", "the card shows one Body row of the field before and after")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-message|USER|" _ tE, "the target is the message")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.SUSPENDED.EDIT|1", "its consequence code, and it is destructive")
    Do $$$AssertEquals(..Status(tE) _ "|" _ ..BodyOf(tE), "5|" _ tOld, "the mint changed nothing")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ ..Outcome(tAnswer), "1|updated|" _ ..Done(tE), "updated, marked, and the line names the message")
    Do $$$AssertTrue(..Await(tE, 9), "the running production processed it")
    Do $$$AssertNotEquals(..BodyOf(tE), tOld, "the header names a copy of the body")
    Do $$$AssertEquals(..BodyText(..BodyOf(tE)) _ "|" _ ..BodyText(tOld), "StringValue=edited|StringValue=alpha", "the copy carries the new value and the original body is not changed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tE, .tData), 1, "the vendor audited the resubmit")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""interop-message""", .tOwn), 0, "OcuPilot records no change row of its own")
    Do ..DropBody(tOld)
}

/// <p>AC2: the person's edit and resubmit is a form, then a review, then a send. The review with no fields answers the form and no row; with fields it answers the one Body row; the
/// same digest sends the copy; an edit that changes nothing is refused as its sentence. The header keeps its id and the original body stays.</p>
/// <p>Mutation (Rule 19): drop the <code>pReviewed</code> comparison in <method>OcuPilot.Port.InteropPort.ReadEdit</method> -- the moved leg of
/// <class>OcuPilot.Test.InteropSuspendedRefusals</class> goes red.</p>
Method TestThePersonsEditAndResubmitIsAFormThenAReviewThenASend()
{
    Set tF = ..Susp("alpha")
    Set tOld = ..BodyOf(tF)
    Set tCode = ..Dry("editresubmit", tF, .tForm)
    Do $$$AssertEquals(tCode, "200 ", "the review with no fields answers the form: " _ $Select($IsObject(tForm): $Extract(tForm.%ToJSON(), 1, 300), 1: tForm))
    Do $$$AssertEquals($Select($IsObject(tForm): tForm.rows.%Size() _ "|" _ tForm.review.Kind _ "|" _ (tForm.review.Form.%Size() > 0), 1: ""), "0|object|1", "no row, an object body and its fields")
    Set tFields = "{""StringValue"":""edited""}"
    Set tCode = ..Dry("editresubmit", tF, .tDry, tFields)
    Do $$$AssertEquals(tCode, "200 ", "the review with the fields answers")
    Do $$$AssertEquals($Select($IsObject(tDry): tDry.rows.%Size() _ "|" _ tDry.rows.%Get(0).field _ "|" _ tDry.rows.%Get(0).before _ "|" _ tDry.rows.%Get(0).after, 1: ""), "1|Body|StringValue: alpha|StringValue: edited", "one Body row of the field before and after")
    Set tDigest = ..Digest(tDry)
    Do $$$AssertEquals(..Status(tF) _ "|" _ ..BodyOf(tF), "5|" _ tOld, "the reviews changed nothing")
    Do $$$AssertEquals(..Dry("editresubmit", tF, .tSame, "{""StringValue"":""alpha""}"), "400 TOOL.ARGUMENTS", "an edit that changes nothing is refused")
    Do $$$AssertTrue($IsObject(tSame) && $IsObject(tSame.%Get("detail")) && (tSame.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).#REASONEDITNOCHANGE), "with the sentence")
    Set tCode = ..Send("editresubmit", tF, tDigest, .tSent, tFields)
    Do $$$AssertEquals(tCode, "200 ", "the action carrying the digest is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) Do $$$AssertEquals(tSent.action _ "|" _ ..Outcome(tSent), "updated|" _ ..Done(tF), "it publishes updated and names the message")
    Do $$$AssertTrue(..Await(tF, 9), "the running production processed it")
    Do $$$AssertEquals(..BodyText(..BodyOf(tF)) _ "|" _ ..BodyText(tOld), "StringValue=edited|StringValue=alpha", "the header carries the copy and the original body is not changed")
    Do ..DropBody(tOld)
}

/// <p>AD-59: the copy-out draft of a resubmit renders one <code>ResubmitMessage</code> line for each message the proposal reviewed as <code>resubmit</code> and none for one held back,
/// closes the proposal as a draft and sends nothing; running the script does what the write does. The draft of an edit renders the clone and <code>ResubmitMessage</code> of the
/// header with it, and running it resubmits the header under its own id with the edited copy.</p>
/// <p>Mutation (Rule 19): render every id of the set in <method>OcuPilot.Port.InteropPort.SuspendedSnippet</method> -- the held-back message is resubmitted by the script and the
/// first leg goes red.</p>
Method TestTheCopyOutDraftsRenderTheirScriptsAndRunningThemDoesTheSame()
{
    Set tA = ..Susp("alpha")
    Set tOff = ..Susp("off", ..#OFFNAME)
    Set tB = ..Susp("beta")
    Set tE = ..Susp("epsilon")
    Set tOld = ..BodyOf(tE)
    Do ..EnableKey(..#RESUBMITKEY)
    Do ..EnableKey(..#EDITKEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#RESUBMITTOOL, {"Messages": (tA _ "," _ tOff _ "," _ tB)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the resubmit mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..TakeDraft(tProposal.proposalId, .tDraft, .tText)
    Do $$$AssertStatusOK(tSC, "the draft is taken")
    If '$IsObject($Get(tDraft)) Quit
    Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", "an ObjectScript draft that closes the proposal")
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "ResubmitMessage(""" _ tA _ """)") && (tText [ "ResubmitMessage(""" _ tB _ """)") && (tText '[ ("ResubmitMessage(""" _ tOff _ """")), "one line for each message that could go, none for the one held back: " _ tText)
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "5|5", "the draft sent nothing")
    Do $$$AssertStatusOK(..RunScript(tText), "the script runs")
    Do $$$AssertTrue(..Await(tA, 9) && ..Await(tB, 9), "and resubmits the two that could go")
    Do $$$AssertEquals(..Status(tOff), 5, "and not the one held back")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EDITTOOL, {"Message": (tE), "Fields": {"StringValue": "edited"}}, tUser, .tEdit, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the edit mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tEdit)) Quit
    Set tSC = ..TakeDraft(tEdit.proposalId, .tEditDraft, .tEditText)
    Do $$$AssertStatusOK(tSC, "its draft is taken")
    Do $$$AssertTrue((tEditText [ "ResubmitMessage(""" _ tE _ """, """", tClone)") && (tEditText [ "%ConstructClone"), "it clones the body and resubmits the header with the clone: " _ tEditText)
    Do $$$AssertEquals(..Status(tE) _ "|" _ ..BodyOf(tE), "5|" _ tOld, "the draft sent nothing")
    Do $$$AssertStatusOK(..RunScript(tEditText), "its script runs")
    Do $$$AssertTrue(..Await(tE, 9), "and the production processes the message")
    Do $$$AssertEquals(..BodyText(..BodyOf(tE)) _ "|" _ ..BodyText(tOld), "StringValue=edited|StringValue=epsilon", "with the edited copy, the original body unchanged")
    Do ..DropBody(tOld)
}

/// <p>An edit and resubmit whose copy was saved and then refused by the vendor leaves the header as it was, still Suspended and naming its own body, answers the refusal, logs no vendor text
/// and leaves no copy behind: no header names it, so the port deletes it.</p>
/// <p>Mutation (Rule 19): skip the delete of the copy in <method>OcuPilot.Port.InteropPort.EditCloneHere</method> for a suspended message -- the body count grows by one and this goes red.</p>
Method TestAnEditTheVendorRefusedAfterTheCopyWasSavedLeavesTheHeaderAndNoCopy()
{
    Set tE = ..Susp("alpha")
    Set tOld = ..BodyOf(tE)
    Set tBodies = $ClassMethod(..#FIXTURE, "StringRequestCount")
    Do ..HoldFor("edit")
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "RefuseEditAfterSave")
    Set tCode = ..SPort("EDITRESUBMIT", tE, .tResult, , "{""StringValue"":""edited""}", , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertTrue(+tCode >= 400, "the write is refused: " _ tCode _ " " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Status(tE) _ "|" _ ..BodyOf(tE) _ "|" _ $ClassMethod(..#FIXTURE, "Property", tE, "Resent"), "5|" _ tOld _ "|0", "the header is unchanged and still Suspended")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "StringRequestCount"), tBodies, "and the copy that was saved is gone")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText") '[ $Parameter(..#SEAM, "MARKER"), "and no log line carries the vendor's text: " _ $ClassMethod(..#SEAM, "LoggedText"))
}

}

/// <p>Pins Story 24.16's discard and delete of suspended messages end to end against a probe production in <code>USER</code> (AD-6, AD-13, AD-15, AD-22, AD-34, AD-51, AD-53, AD-62):
/// the person's discard, reviewed and sent, and the agent's, confirmed over HTTP at its shipped key, mark each message Discarded and keep its header and body, which a resend from
/// Messages can still send, and record OcuPilot's own <code>ConfigChange</code> naming the ids done and failed, once for the write; the delete, from both callers, removes each header, its
/// body when no other header names it and the body's search table rows, keeps a body another header names until the last of them is deleted, and records the same row; the copy-out
/// draft of each renders its script, sends nothing and, run, does what the write does; a vendor refusal of one message leaves the rest acted on, with its text in the answer and in no log line;
/// a body that cannot be deleted keeps its header and each caller reads it not deleted; and a search table removal that fails is logged in the port's own namespace.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.InteropSuspendedCase</class>). One class per run.</p>
Class OcuPilot.Test.InteropSuspendedRemove Extends OcuPilot.Test.InteropSuspendedCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>A minimal HL7 v2 message, which a search table indexes in four rows.</p>
Parameter HL7 = {"MSH|^~\&|PROBE|FAC|RCV|FAC|20260101120000||ADT^A01|MSG0001|P|2.3.1" _ $Char(13) _ "PID|1||123^^^MRN||DOE^JOHN||19700101|M"};

/// <p>The outcome line of a message the write acted on: <code>&lt;id&gt;: discarded</code> or <code>deleted</code> (<var>pDone</var> 1), else the <code>not</code> form.</p>
ClassMethod Done(pKind As %String, pId As %String, pDone As %Boolean = 1) As %String
{
    Quit pId _ ": " _ ##class(OcuPilot.Port.InteropPort).SuspendedOutcomeWord(pKind, pDone)
}

/// <p>The lines of the confirm or action answer <var>pAnswer</var>, newline-separated.</p>
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

/// <p>Store a suspended HL7 request, index its body in the search table, and answer its header id (0 when the body did not index).</p>
Method SuspendedHl7() As %String
{
    Set tSC = $ClassMethod(..#FIXTURE, "Hl7", ..#HL7, ..#OPNAME, .tId)
    Do $$$AssertStatusOK(tSC, "an HL7 request is stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Suspend", tId), "and suspended")
    Set tRows = $ClassMethod(..#FIXTURE, "IndexHl7", tId)
    Do $$$AssertTrue(tRows > 0, "its body has search table rows: " _ tRows)
    Quit tId
}

/// <p>AC3: the person's discard of two suspended messages is reviewed, then sent with the digest of the review. Each header reads Discarded with its body kept and its id, the
/// answer names both and publishes <code>updated</code>, the vendor writes no audit row, OcuPilot records one <code>ConfigChange</code> for the write naming both ids, and a message
/// discarded can still be resent from Messages, as a new message, leaving it Discarded.</p>
/// <p>Mutation (Rule 19): skip <code>SetStatus</code> in <method>OcuPilot.Port.InteropPort.VendorSuspended</method> for a discard -- the status legs go red; make
/// <method>OcuPilot.Port.InteropPort.JudgeMessages</method> read a Discarded header as <code>nobody</code> for a resend -- the resend legs go red.</p>
Method TestThePersonsDiscardKeepsHeaderAndBodyAndIsAuditedOnce()
{
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tBodyA = ..BodyOf(tA)
    Set tSet = tA _ "," _ tB
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..Dry("discard", tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    Do $$$AssertEquals(..Lines(tDry), ..Line(tA, "discard") _ $Char(10) _ ..Line(tB, "discard"), "its one row reads both messages")
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "5|5", "the review changed nothing")
    Set tCode = ..Send("discard", tSet, ..Digest(tDry), .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the action is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) Do $$$AssertEquals(tSent.action _ "|" _ tSent.target.id _ "|" _ ..Outcome(tSent), "updated|" _ tSet _ "|" _ ..Done("discard", tA) _ $Char(10) _ ..Done("discard", tB), "it publishes updated and answers a line for each message")
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "4|4", "both read Discarded")
    Do $$$AssertEquals(..BodyText(tBodyA) _ "|" _ ..BodyOf(tA), "StringValue=alpha|" _ tBodyA, "the body is kept and the header still names it")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tA, .tVendor), 0, "the vendor wrote no audit row")
    Do $$$AssertEquals(..OwnRows(tSince, "discard", .tOwn), 1, "OcuPilot recorded one change row for the write")
    Do $$$AssertTrue((tOwn [ """done"":""" _ tA _ "," _ tB _ """") && (tOwn [ """failed"":"""""), "naming the ids done and none failed: " _ tOwn)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""interop-message""", .tTyped), 1, "the row carries the entity type the resubmit legs count none of: " _ tTyped)
    Do $$$AssertEquals(..Port("RESEND", tA, .tRead) _ "|" _ $Select($IsObject(tRead): tRead.Eligible, 1: ""), "200 |1", "a discarded message can still be resent from Messages")
    Do $$$AssertEquals(..Port("RESENDMESSAGES", tA, .tSend) _ "|" _ $Select($IsObject(tSend): tSend.Resent _ "|" _ tSend.Failed, 1: ""), "200 |1|0", "and the resend is carried out")
    Set tNew = $Select($IsObject(tSend): tSend.Messages.%Get(0).NewId, 1: "")
    Do $$$AssertTrue((tNew '= "") && (tNew '= tA) && ..Await(tNew, 9), "the resent copy of the discarded message is a new message, processed to completion: " _ tNew)
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..BodyOf(tA), "4|" _ tBodyA, "and the discarded message itself still reads Discarded with its body")
}

/// <p>AC3: the agent's discard, minted and confirmed over HTTP with its key at the shipped value, which is on, marks the messages Discarded; the card shows one row of the lines and is
/// not destructive; the confirm is marked and ledgered once, and OcuPilot records one change row.</p>
/// <p>Mutation (Rule 19): set <code>interop.suspendedmessages.discard</code> <code>false</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -- the mint is refused and this goes red.</p>
Method TestTheAgentsDiscardConfirmsOverHttpAtItsShippedKey()
{
    Set tC = ..Susp("gamma")
    Set tD = ..Susp("delta")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tStored), "the stored policy reads")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).IsDefault(.tStored), "and leaves every key to the baseline")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#DISCARDTOOL, {"Messages": (tD _ "," _ tC)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, ..#DISCARDKEY _ " mints with no key turned on: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).after, "1|" _ ..Line(tC, "discard") _ $Char(10) _ ..Line(tD, "discard"), "the card shows one row of the two lines")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.SUSPENDED.DISCARD|0", "its consequence code, and it is not destructive")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ ..Outcome(tAnswer), "1|updated|" _ ..Done("discard", tC) _ $Char(10) _ ..Done("discard", tD), "updated, marked, and the lines name each message")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, ..#DISCARDKEY), 1, "the confirmed write is in the ledger once")
    Do $$$AssertEquals(..Status(tC) _ "|" _ ..Status(tD), "4|4", "both read Discarded")
    Do $$$AssertEquals(..OwnRows(tSince, "discard", .tOwn), 1, "OcuPilot recorded one change row for the write")
}

/// <p>AC3, orchestrator condition 1: a body that another header names survives the delete of one of its headers. A suspended message shares its body with a Completed one; the
/// person's delete removes the suspended header and keeps the body, which the other header still names and reads.</p>
/// <p>Mutation (Rule 19): delete the body without counting the headers that name it in <method>OcuPilot.Port.InteropPort.DeleteHeaderHere</method> -- the shared body goes and this
/// goes red.</p>
Method TestABodyAnotherHeaderNamesSurvivesTheDeleteOfOneHeader()
{
    Set tS = ..Susp("shared")
    Set tBody = ..BodyOf(tS)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ShareBody", tS, .tOther), "a Completed header is made to name the same body")
    Do $$$AssertEquals(..BodyOf(tOther), tBody, "both name the body")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..Dry("delete", tS, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers")
    Set tCode = ..Send("delete", tS, ..Digest(tDry), .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the delete is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) Do $$$AssertEquals(tSent.action _ "|" _ ..Outcome(tSent), "deleted|" _ ..Done("delete", tS), "it publishes deleted and names the message")
    Do $$$AssertEquals(..Status(tS), "<none>", "the suspended header is gone")
    Do $$$AssertEquals(..BodyText(tBody) _ "|" _ ..BodyOf(tOther), "StringValue=shared|" _ tBody, "the body is kept and the other header still names it")
    Do $$$AssertEquals(..OwnRows(tSince, "delete", .tOwn), 1, "OcuPilot recorded one change row for the write")
}

/// <p>AC3, orchestrator condition 1: the delete of the last header that names a body removes the body, and an HL7 body's search table rows with it. Two suspended headers share one
/// body and a third carries an indexed HL7 body; the person's delete of all three keeps the shared body past the first and removes it with the second, and removes the HL7 body and its
/// rows.</p>
/// <p>Mutation (Rule 19): skip <code>RemoveSearchTableEntries</code> and the body's <code>%DeleteId</code> in <method>OcuPilot.Port.InteropPort.DeleteHeaderHere</method> -- the body and
/// row legs go red.</p>
Method TestTheLastHeadersDeleteRemovesTheBodyAndItsSearchTableRows()
{
    Set tS1 = ..Susp("last")
    Set tBody = ..BodyOf(tS1)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ShareBody", tS1, .tS2), "a second header is made to name the body")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Suspend", tS2), "and suspended")
    Set tH = ..SuspendedHl7()
    Set tHl7Body = $ClassMethod(..#FIXTURE, "Property", tH, "MessageBodyId")
    Set tSet = tS1 _ "," _ tS2 _ "," _ tH
    Set tCode = ..Dry("delete", tSet, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the dry run answers")
    Set tCode = ..Send("delete", tSet, ..Digest(tDry), .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the delete is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    Do $$$AssertEquals(..Status(tS1) _ "|" _ ..Status(tS2) _ "|" _ ..Status(tH), "<none>|<none>|<none>", "the three headers are gone")
    Do $$$AssertEquals(..BodyText(tBody), "<none>", "the body the first two shared is gone with the last of them")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "BodyFields", "EnsLib.HL7.Message", tHl7Body, "Source"), "<none>", "the HL7 body is gone")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SearchRows", "", tHl7Body), 0, "and so are its search table rows")
}

/// <p>AC3: the agent's delete, minted and confirmed over HTTP while its key is on, removes an unshared body's header and body and an indexed HL7 body's search table rows; the card is
/// destructive with its own consequence; the confirm is marked and ledgered once and OcuPilot records one change row.</p>
/// <p>Mutation (Rule 19): record no audit row in <method>OcuPilot.Port.InteropPort.PerformResend</method> for a delete -- the row leg goes red.</p>
Method TestTheAgentsDeleteConfirmsOverHttpAndRemovesTheBodiesAndRows()
{
    Set tD = ..Susp("delta")
    Set tBody = ..BodyOf(tD)
    Set tH = ..SuspendedHl7()
    Set tHl7Body = $ClassMethod(..#FIXTURE, "Property", tH, "MessageBodyId")
    Do ..EnableKey(..#DELETEKEY)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#DELETETOOL, {"Messages": (tH _ "," _ tD)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, ..#DELETEKEY _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.SUSPENDED.DELETE|1", "its consequence code, and it is destructive")
    Do $$$AssertEquals(..Status(tD) _ "|" _ ..Status(tH), "5|5", "the mint deleted nothing")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ $Length(..Outcome(tAnswer), $Char(10)), "1|deleted|2", "deleted, marked, and a line for each message")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, ..#DELETEKEY), 1, "the confirmed write is in the ledger once")
    Do $$$AssertEquals(..Status(tD) _ "|" _ ..Status(tH), "<none>|<none>", "both headers are gone")
    Do $$$AssertEquals(..BodyText(tBody), "<none>", "the unshared body is gone")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SearchRows", "", tHl7Body), 0, "and the HL7 body's search table rows")
    Do $$$AssertEquals(..OwnRows(tSince, "delete", .tOwn), 1, "OcuPilot recorded one change row for the write")
}

/// <p>AD-59: the copy-out draft of a discard renders the open, <code>SetStatus</code> and save of each message the proposal reviewed as <code>discard</code> and none for one held back; the
/// draft of a delete renders the header's read, the guarded delete of its body and search table rows, and the header's delete, for each message that could go and none for one held back;
/// each closes the proposal as a draft and sends nothing, and running its script does what the write does: the discarded messages read Discarded with their bodies kept, the deleted ones
/// are gone with their unshared body and an HL7 body's search table rows, a body another header names is kept, and a message that left Suspended after the review is left as
/// it is. A set holding an id of no message shape renders no draft.</p>
/// <p>Mutation (Rule 19): change the delete script's <code>(tHolders = 1)</code> guard on the body's <code>%DeleteId</code> in <method>OcuPilot.Port.InteropPort.SuspendedSnippet</method> to
/// <code>&gt;= 1</code> -- the script removes the body another header names and this goes red; drop the scripts' status check -- the moved messages' legs go red.</p>
Method TestTheCopyOutDraftsOfADiscardAndADeleteRenderTheirScriptsAndRunningThemDoesTheSame()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tDone = ..Make("done")
    Set tLater = ..Susp("completed after the review")
    Set tBodyA = ..BodyOf(tA)
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#DISCARDTOOL, {"Messages": (tA _ "," _ tDone _ "," _ tB _ "," _ tLater)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the discard mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..TakeDraft(tProposal.proposalId, .tDraft, .tText)
    Do $$$AssertStatusOK(tSC, "the discard's draft is taken")
    If '$IsObject($Get(tDraft)) Quit
    Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", "an ObjectScript draft that closes the proposal")
    Set tShape = 1
    For tId = tA, tB {
        Set tOpen = "Set tHeader = ##class(Ens.MessageHeader).%OpenId(""" _ tId _ """)"
        If (tText '[ tOpen) || (tText '[ ("tHeader.SetStatus(" _ ##class(OcuPilot.Port.InteropPort).#STATUSDISCARDEDVALUE _ ")")) Set tShape = 0
    }
    Do $$$AssertTrue(tShape && (tText [ "tHeader.%Save()") && (tText '[ ("%OpenId(""" _ tDone _ """)")), "one open, SetStatus and save for each message that could go, none for the Completed one: " _ tText)
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "5|5", "the draft sent nothing")
    Do $$$AssertStatusOK(..Move(tLater, 9), "a message the review read as one to discard completes before the script runs")
    Do $$$AssertStatusOK(..RunScript(tText), "the script runs")
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB) _ "|" _ ..Status(tDone) _ "|" _ ..Status(tLater), "4|4|9|9", "and discards the two that could go, not the Completed one, nor the one no longer suspended when it ran")
    Do $$$AssertEquals(..BodyText(tBodyA) _ "|" _ ..BodyOf(tA), "StringValue=alpha|" _ tBodyA, "the body is kept and the header still names it")
    Do ..EnableKey(..#DELETEKEY)
    Set tU = ..Susp("unshared")
    Set tUBody = ..BodyOf(tU)
    Set tS = ..Susp("shared")
    Set tSBody = ..BodyOf(tS)
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ShareBody", tS, .tOther), "a Completed header is made to name the shared message's body")
    Set tH = ..SuspendedHl7()
    Set tHl7Body = $ClassMethod(..#FIXTURE, "Property", tH, "MessageBodyId")
    Set tHeld = ..Make("held back")
    Set tMoved = ..Susp("completed before the delete ran")
    Set tMovedBody = ..BodyOf(tMoved)
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#DELETETOOL, {"Messages": (tU _ "," _ tS _ "," _ tH _ "," _ tHeld _ "," _ tMoved)}, tUser, .tDelete, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the delete mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tDelete)) Quit
    Set tSC = ..TakeDraft(tDelete.proposalId, .tDeleteDraft, .tDeleteText)
    Do $$$AssertStatusOK(tSC, "the delete's draft is taken")
    Set tShape = 1
    For tId = tU, tS, tH {
        If (tDeleteText '[ ("Set tHeader = ##class(Ens.MessageHeader).%OpenId(""" _ tId _ """)")) || (tDeleteText '[ ("DELETE FROM Ens.MessageHeader WHERE ID = ?"", """ _ tId _ """)")) Set tShape = 0
    }
    Do $$$AssertTrue(tShape && (tDeleteText [ "(tHolders = 1)") && (tDeleteText [ "RemoveSearchTableEntries") && (tDeleteText '[ ("%OpenId(""" _ tHeld _ """)")), "the read, guarded body delete and header delete for each message that could go, none for the Completed one: " _ tDeleteText)
    Do $$$AssertEquals(..Status(tU) _ "|" _ ..Status(tS) _ "|" _ ..Status(tH), "5|5|5", "the draft sent nothing")
    Do $$$AssertStatusOK(..Move(tMoved, 9), "a message the review read as one to delete completes before the script runs")
    Do $$$AssertStatusOK(..RunScript(tDeleteText), "the delete's script runs")
    Do $$$AssertEquals(..Status(tU) _ "|" _ ..Status(tS) _ "|" _ ..Status(tH) _ "|" _ ..Status(tHeld), "<none>|<none>|<none>|9", "the three headers are gone and the Completed one is not")
    Do $$$AssertEquals(..Status(tMoved) _ "|" _ ..BodyText(tMovedBody), "9|StringValue=completed before the delete ran", "and the one no longer suspended when it ran is kept with its body")
    Do $$$AssertEquals(..BodyText(tUBody), "<none>", "the unshared body is gone")
    Do $$$AssertEquals(..BodyText(tSBody) _ "|" _ ..BodyOf(tOther), "StringValue=shared|" _ tSBody, "the body the Completed header names is kept")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "BodyFields", "EnsLib.HL7.Message", tHl7Body, "Source"), "<none>", "the HL7 body is gone")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SearchRows", "", tHl7Body), 0, "and so are its search table rows")
    For tKind = "discard", "delete" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tType = ##class(OcuPilot.Port.InteropPort).SuspendedWriteType(tKind)
        Set tQuery("id") = tHeld
        Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, tType, .tQuery).%Size(), 1, tKind _ ": a set of one message id renders its script")
        Set tQuery("id") = tHeld _ ",abc"
        Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, tType, .tQuery).%Size(), 0, tKind _ ": a set holding a bad id renders no draft")
    }
}

/// <p>AC3: a message the vendor refuses is recorded with the vendor's text in the answer and the rest of the set is still acted on, in id order; the change row names the ids done
/// and the id that failed, and the refusal reaches the log as one line with no vendor text.</p>
/// <p>Mutation (Rule 19): quit the loop in <method>OcuPilot.Port.InteropPort.PerformResend</method> at the first refusal -- the third message is not acted on and this goes red; log
/// the vendor's text -- the log leg goes red; give <method>OcuPilot.Screen.Tool.InteropMessageAction.FailureLine</method> the resend's word -- the outcome leg goes red.</p>
Method TestAVendorRefusalOfOneMessageLeavesTheRestActedOnAndLogsNoText()
{
    Set tA = ..Susp("alpha")
    Set tB = ..Susp("beta")
    Set tC = ..Susp("gamma")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..HoldFor("discard")
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailActOf", "discard", tB)
    Set tCode = ..SPort("DISCARDMESSAGES", tA _ "," _ tB _ "," _ tC, .tResult, , , , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals(tCode, "200 ", "the write is admitted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.Done _ "|" _ tResult.Failed _ "|" _ tResult.Messages.%Size(), "2|1|3", "two were discarded, one was not, and each has an entry")
    Do $$$AssertEquals(tResult.Messages.%Get(1).ID _ "|" _ (tResult.Messages.%Get(1).Error [ $Parameter(..#SEAM, "MARKER")), tB _ "|1", "the second carries the vendor's text in the answer")
    Set tOutput = ##class(OcuPilot.Screen.Tool.InteropSuspendedDiscard).WriteOutput(tResult)
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.lines.%Get(0) _ $Char(10) _ tOutput.lines.%Get(1), 1: ""), ..Done("discard", tA) _ $Char(10) _ ..Done("discard", tB, 0) _ ": " _ tResult.Messages.%Get(1).Error, "the outcome names the first discarded and the second not discarded, with the vendor's text")
    Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB) _ "|" _ ..Status(tC), "4|5|4", "the first and third read Discarded and the second is still suspended")
    Do $$$AssertEquals(..OwnRows(tSince, "discard", .tOwn), 1, "one change row")
    Do $$$AssertTrue((tOwn [ """done"":""" _ tA _ "," _ tC _ """") && (tOwn [ """failed"":""" _ tB _ """"), "names the ids done and the one that failed: " _ tOwn)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 1, "the refusal was logged once")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText") '[ $Parameter(..#SEAM, "MARKER"), "and the line carries no text of the vendor's: " _ $ClassMethod(..#SEAM, "LoggedText"))
}

/// <p>Take (<var>pHold</var> 1) or give back (0) this process's exclusive lock on the body <var>pBody</var> (<method>OcuPilot.Test.InteropSuspendedCase.BodyOf</method>'s) in
/// <code>USER</code>; whether the call succeeded. While it is held, another process's delete of the body waits for the lock and then fails.</p>
ClassMethod HoldBody(pBody As %String, pHold As %Boolean) As %Boolean
{
    Set tOk = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tOk = $System.Status.IsOK($ClassMethod($Piece(pBody, "|", 1), $Select(pHold: "%LockId", 1: "%UnlockId"), $Piece(pBody, "|", 2)))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOk
}

/// <p>AC3, Decided in-stage 9: a delete whose body cannot be deleted, for a reason other than the body being gone already, keeps the header and its body, and each caller is told
/// so. This process holds the lock on one message's body, so the instance's delete of it fails. The person's delete of that message and another deletes the other and answers
/// the first <code>not deleted</code> with the vendor's text; the agent's delete of the first, confirmed over HTTP, answers the same; the first still reads Suspended with its
/// body, and each write's change row names it as failed.</p>
/// <p>Mutation (Rule 19): delete the header after a body delete that failed in <method>OcuPilot.Port.InteropPort.DeleteHeaderHere</method>, as the classic page does -- the
/// header goes, the lines read <code>deleted</code> and this goes red.</p>
Method TestABodyThatCannotBeDeletedKeepsItsHeaderAndEachCallerIsToldItWasNotDeleted()
{
    Set tA = ..Susp("locked body")
    Set tB = ..Susp("free body")
    Set tBodyA = ..BodyOf(tA)
    Set tSet = tA _ "," _ tB
    Do $$$AssertTrue(..HoldBody(tBodyA, 1), "this process holds the lock on the first message's body")
    Try {
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tCode = ..Dry("delete", tSet, .tDry)
        Do $$$AssertEquals(tCode, "200 ", "the dry run answers")
        Set tCode = ..Send("delete", tSet, ..Digest(tDry), .tSent)
        Do $$$AssertEquals(tCode, "200 ", "the delete is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
        Set tLines = ..Outcome(tSent)
        Do $$$AssertTrue(($Piece(tLines, $Char(10), 1) [ (..Done("delete", tA, 0) _ ": ")) && ($Piece(tLines, $Char(10), 2) = ..Done("delete", tB)) && ($Length(tLines, $Char(10)) = 2), "the person reads the first not deleted, with the vendor's text, and the second deleted: " _ tLines)
        Do $$$AssertEquals(..Status(tA) _ "|" _ ..Status(tB), "5|<none>", "the first is still suspended and the second is gone")
        Do $$$AssertEquals(..BodyText(tBodyA) _ "|" _ ..BodyOf(tA), "StringValue=locked body|" _ tBodyA, "the first keeps its body")
        Do $$$AssertEquals(..OwnRows(tSince, "delete", .tOwn), 1, "one change row for the person's write")
        Do $$$AssertTrue((tOwn [ ("""done"":""" _ tB _ """")) && (tOwn [ ("""failed"":""" _ tA _ """")), "naming the second done and the first failed: " _ tOwn)
        Do ..EnableKey(..#DELETEKEY)
        Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
        Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#DELETETOOL, {"Messages": (tA)}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertStatusOK(tSC, "the agent's delete mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If $IsObject($Get(tProposal)) {
            Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
            Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
            Set tLines = ..Outcome($Get(tAnswer))
            Do $$$AssertTrue((tLines [ (..Done("delete", tA, 0) _ ": ")) && ($Length(tLines, $Char(10)) = 1), "the agent's answer reads the message not deleted, with the vendor's text: " _ tLines)
            Do $$$AssertEquals(..Status(tA) _ "|" _ ..BodyOf(tA), "5|" _ tBodyA, "the message is still suspended with its body")
            Do $$$AssertEquals(..OwnRows(tSince, "delete", .tOwn), 1, "one change row for the agent's write")
            Do $$$AssertTrue((tOwn [ """done"":""""") && (tOwn [ ("""failed"":""" _ tA _ """")), "naming none done and the message failed: " _ tOwn)
        }
    } Catch ex {
        Do $$$AssertTrue(0, "the test ran to its end: " _ ex.DisplayString())
    }
    Do $$$AssertTrue(..HoldBody(tBodyA, 0), "the lock is given back")
}

/// <p>AC3, the one-port rule (AD-62): a deleted body whose search table entries cannot be removed does not stop the delete, and the failure reaches the log as one line with
/// no vendor text, written once the port is back in its own namespace rather than in the message's. The seam refuses the removal for one HL7 body; the rows it left are removed
/// by the test.</p>
/// <p>Mutation (Rule 19): log the failure from <method>OcuPilot.Port.InteropPort.DeleteHeaderHere</method>, while the message's namespace is switched -- the namespace leg
/// goes red.</p>
Method TestASearchTableRemovalThatFailsIsLoggedInThePortsOwnNamespace()
{
    Set tH = ..SuspendedHl7()
    Set tHl7Body = $ClassMethod(..#FIXTURE, "Property", tH, "MessageBodyId")
    Do ..HoldFor("delete")
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailSearchRemovalOf", tHl7Body)
    Set tCode = ..SPort("DELETEMESSAGES", tH, .tResult, , , , .tFault, ..#NAMESPACE, ..#SEAM)
    Do $$$AssertEquals(tCode, "200 ", "the write is admitted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.Done _ "|" _ tResult.Failed, 1: ""), "1|0", "the message is deleted")
    Do $$$AssertEquals(..Status(tH) _ "|" _ $ClassMethod(..#FIXTURE, "BodyFields", "EnsLib.HL7.Message", tHl7Body, "Source"), "<none>|<none>", "with its header and its body")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged") _ "|" _ $ClassMethod(..#SEAM, "LoggedIn"), "1|" _ $NAMESPACE, "the refused removal was logged once, in the port's own namespace")
    Do $$$AssertTrue($ClassMethod(..#SEAM, "LoggedText") '[ $Parameter(..#SEAM, "MARKER"), "and the line carries no text of the vendor's: " _ $ClassMethod(..#SEAM, "LoggedText"))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(Ens.SearchTableBase).RemoveSearchTableEntries("EnsLib.HL7.Message", tHl7Body, 1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SearchRows", "", tHl7Body), 0, "the rows the refusal left are removed")
}

}

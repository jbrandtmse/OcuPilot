/// <p>Pins Story 20.31's edit and resend end to end against a running probe production in <code>USER</code> (AD-6, AD-13, AD-22, AD-34,
/// AD-35, AD-51, AD-53, AD-62): an <code>Ens.StringRequest</code> edited through the agent's mint and confirm and through the person's
/// form, review and send; an HL7 v2 message edited through its content; a request of every field shape edited on a clone that leaves
/// the original and the objects it shares untouched; and what an edit refuses -- a body of another document kind, a stream, a class
/// whose name begins <code>OcuPilot</code>, a change that changes nothing, a path that is no field, a credential-named field and a
/// value its field refuses -- each with nothing sent. The vendor audits each body an edit read opens, once.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b>, compiles the request classes of <parameter>OcuPilot.Test.InteropResendFixture.BODYPACKAGE</parameter> there
/// and sends messages to the production (<class>OcuPilot.Test.InteropResendCase</class>). One class per run.</p>
Class OcuPilot.Test.InteropEditResend Extends OcuPilot.Test.InteropResendCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropMessageEditResend";

Parameter KEY = "interop.messageheader.editresend";

Parameter SCREEN = "/screens/interop.messageheader";

/// <p>The request class of every field shape, and the request class whose name begins <code>OcuPilot</code>
/// (<class>OcuPilot.Test.InteropResendFixture</class>'s).</p>
Parameter BODYCLASS = {$Parameter("OcuPilot.Test.InteropResendFixture", "BODYCLASS")};

Parameter OWNBODYCLASS = {$Parameter("OcuPilot.Test.InteropResendFixture", "OWNBODYCLASS")};

Method OnPrepare() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "CreateBodyClasses")
}

Method OnRelease() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "RemoveBodyClasses")
}

/// <p>The person's review of editing and resending the message <var>pId</var> (<code>POST /dryrun</code>) with the fields
/// <var>pFields</var> (JSON object text; none asks for the form): <code>status code</code>.</p>
ClassMethod Dry(pId As %String, pFields As %String = "", Output pAnswer) As %String
{
    Set tBody = {"action": "editresend"}
    Do tBody.%Set("id", pId, "string")
    If pFields '= "" {
        Set tValues = {}
        Do tValues.%Set("fields", pFields, "string")
        Do tBody.%Set("values", tValues)
    }
    Quit ..Post(..#SCREEN _ "/dryrun", tBody, .pAnswer)
}

/// <p>The person's edit and resend of <var>pId</var> with <var>pFields</var>, carrying the digest <var>pReviewed</var>
/// (<code>POST /action</code>): <code>status code</code>.</p>
ClassMethod Send(pId As %String, pFields As %String, pReviewed As %String, Output pAnswer) As %String
{
    Set tBody = {"action": "editresend"}
    Do tBody.%Set("id", pId, "string")
    Set tValues = {}
    Do tValues.%Set("fields", pFields, "string")
    Do tValues.%Set("Reviewed", pReviewed, "string")
    Do tBody.%Set("values", tValues)
    Quit ..Post(..#SCREEN _ "/action", tBody, .pAnswer)
}

/// <p>The vendor's <code>ViewContents</code> audit rows since <var>pSince</var> naming the message header <var>pId</var>.</p>
ClassMethod Views(pSince As %String, pId As %String) As %Integer
{
    Quit $ClassMethod(..#FIXTURE, "AuditRows", pSince, "ViewContents", pId, .tData)
}

/// <p>The violations of a refused edit's fault, <code>path:code</code> joined by a comma, <code>""</code> for a fault with none.</p>
ClassMethod Violations(pFault) As %String
{
    Set tText = ""
    If '$IsObject(pFault) || '$IsObject(pFault.%Get("detail")) || '$IsObject(pFault.detail.%Get("violations")) Quit tText
    Set tIterator = pFault.detail.violations.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tViolation) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tViolation.field _ ":" _ tViolation.code
    }
    Quit tText
}

/// <p>The new header id a confirm or action answer names for the message <var>pId</var>, <code>""</code> for none.</p>
ClassMethod NewHeader(pAnswer, pId As %String) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("output")) || '$IsObject(pAnswer.output.%Get("lines")) Quit ""
    Quit $Piece(pAnswer.output.lines.%Get(0), pId _ ": resent as ", 2)
}

/// <p>The stored body fields of the header <var>pHeader</var> (<method>OcuPilot.Test.InteropResendFixture.BodyFields</method>).</p>
ClassMethod FieldsOf(pHeader As %String, pFields As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "BodyFields", $ClassMethod(..#FIXTURE, "Property", pHeader, "MessageBodyClassName"), $ClassMethod(..#FIXTURE, "Property", pHeader, "MessageBodyId"), pFields)
}

/// <p>AC3, AC5: the agent's edit of a string request, minted and confirmed over HTTP while its key is on, resends the message with a
/// copy of its body carrying the new value. The card shows one Body row of the field before and after and is destructive; the
/// confirm answers the line, publishes <code>created</code>, is marked and ledgered once; the new header is in the original's
/// session, flagged resent, and names the copy; the original body is not changed; and the vendor audits the new header.</p>
/// <p>Mutation (Rule 19): resend the original body in <method>OcuPilot.Port.InteropPort.VendorResendWithBody</method> -- the copy
/// legs go red.</p>
Method TestTheAgentsEditAndResendConfirmsOverHttp()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do ..EnableKey(..#KEY)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Message": (tA), "Fields": {"StringValue": "edited"}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, ..#KEY _ " mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ "|" _ tProposal.changed.%Get(0).field _ "|" _ tProposal.changed.%Get(0).before _ "|" _ tProposal.changed.%Get(0).after, "1|Body|StringValue: alpha|StringValue: edited", "the card shows one Body row of the field before and after")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-message|USER|" _ tA, "the target is the message")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.MESSAGE.EDITRESEND|1", "its consequence code, and it is destructive")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "the mint sent nothing")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "it confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($IsObject(tAnswer) && ($Length(tRaw, "}{") = 1), "the confirm answers exactly one envelope")
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|created", "created and marked (AD-15)")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, ..#KEY), 1, "the confirmed write is in the ledger once")
    Set tNew = ..NewHeader(tAnswer, tA)
    Do $$$AssertTrue(tNew > tTop, "the answer names the new header: " _ $Select($IsObject(tAnswer.output): tAnswer.output.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tNew, "SessionId"), $ClassMethod(..#FIXTURE, "Property", tA, "SessionId"), "the new header is in the original's session")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Property", tNew, "Resent"), 1, "and flagged resent")
    Do $$$AssertNotEquals($ClassMethod(..#FIXTURE, "Property", tNew, "MessageBodyId"), $ClassMethod(..#FIXTURE, "Property", tA, "MessageBodyId"), "it names a copy of the body")
    Do $$$AssertEquals(..FieldsOf(tNew, "StringValue"), "StringValue=edited", "the copy carries the new value")
    Do $$$AssertEquals(..FieldsOf(tA, "StringValue"), "StringValue=alpha", "and the original body is not changed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AuditRows", tSince, "Resend", tNew, .tData), 1, "the vendor audited the resend as new header " _ tNew)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """type"":""interop-message""", .tOwn), 0, "OcuPilot records no change row of its own")
}

/// <p>AC4, AC5: the person's edit is a form, then a review, then a send. The review with no fields answers the form -- the kind, the
/// field and its current value -- and no row; with fields it answers the one Body row; the same digest sends the copy; a change that
/// changes nothing is refused as the sentence; and a digest of a review the message has since moved past (its target disabled) is
/// refused 409 <code>INTEROP.RESEND.CHANGED</code> with nothing sent.</p>
/// <p>Mutation (Rule 19): drop the <code>pReviewed</code> comparison in <method>OcuPilot.Port.InteropPort.ReadEdit</method> -- the
/// CHANGED leg sends and goes red.</p>
Method TestThePersonsEditAndResendReviewsTheFormThenTheChange()
{
    Set tB = ..Make("beta", ..#TWONAME)
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tFields = {"StringValue": "edited"}.%ToJSON()
    Set tCode = ..Dry(tB, "", .tForm)
    Do $$$AssertEquals(tCode, "200 ", "the review with no fields answers: " _ $Select($IsObject(tForm): tForm.%ToJSON(), 1: tForm))
    If '$IsObject(tForm) Quit
    Do $$$AssertEquals(tForm.rows.%Size() _ "|" _ tForm.review.Kind _ "|" _ tForm.review.Form.%Size() _ "|" _ tForm.review.Form.%Get(0).Field _ "|" _ tForm.review.Form.%Get(0).Value, "0|object|1|StringValue|beta", "the form names the one field and its current value")
    Set tDigest = tForm.review.Digest
    Do $$$AssertEquals($Length(tDigest), 64, "and the digest")
    Set tCode = ..Dry(tB, tFields, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the review with fields answers")
    Do $$$AssertEquals(tDry.rows.%Size() _ "|" _ tDry.rows.%Get(0).field _ "|" _ tDry.rows.%Get(0).before _ "|" _ tDry.rows.%Get(0).after _ "|" _ (tDry.review.Digest = tDigest), "1|Body|StringValue: beta|StringValue: edited|1", "one Body row, and the digest of the message, not of the change")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "the reviews sent nothing")
    Set tCode = ..Dry(tB, {"StringValue": "beta"}.%ToJSON(), .tSame)
    Do $$$AssertEquals(tCode, "400 TOOL.ARGUMENTS", "a change that changes nothing is refused")
    Do $$$AssertTrue($IsObject(tSame) && (tSame.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).#REASONEDITNOCHANGE), "with its sentence")
    Set tCode = ..Send(tB, tFields, tDigest, .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the send carrying the digest is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If $IsObject(tSent) {
        Set tNew = ..NewHeader(tSent, tB)
        Do $$$AssertEquals(tSent.action _ "|" _ tSent.target.type _ "|" _ tSent.target.id, "created|interop-message|" _ tB, "it publishes the created event for the message")
        Do $$$AssertEquals(..FieldsOf(tNew, "StringValue") _ "|" _ ..FieldsOf(tB, "StringValue"), "StringValue=edited|StringValue=beta", "the copy carries the new value and the original keeps its own")
    }
    Set tC = ..Make("gamma", ..#TWONAME)
    Set tCode = ..Dry(tC, "", .tFirst)
    Do $$$AssertEquals(tCode, "200 ", "a second message is reviewed")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetEnabled", ..#TWONAME, 0), "its target is disabled after the review")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Send(tC, tFields, tFirst.review.Digest, .tRefused)
    Do $$$AssertEquals(tCode, "409 INTEROP.RESEND.CHANGED", "the digest of that review is refused: " _ $Select($IsObject(tRefused): tRefused.%ToJSON(), 1: tRefused))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Set tCode = ..Dry(tC, tFields, .tNone)
    Do $$$AssertEquals(tCode, "400 TOOL.ARGUMENTS", "a review now is refused: the message can no longer go")
    Do $$$AssertTrue($IsObject(tNone) && (tNone.detail.%Get("problem") [ ##class(OcuPilot.Api.InteropError).#REASONRESENDNONE), "with the sentence of the set that can send nothing")
}

/// <p>AC5: an HL7 v2 message is edited through its content. The read answers the document kind, the one <code>content</code> field and
/// the raw view; the send resends a copy that keeps the original's document type, annotates its <code>Source</code> with the original
/// body's id, and carries the new segments; the original is not changed; and a text the parser refuses is a 422 on
/// <code>content</code> with nothing sent.</p>
/// <p>Mutation (Rule 19): skip the <code>Clear()</code> in <method>OcuPilot.Port.InteropPort.EditCloneHere</method> -- the segment the
/// text dropped stays on the copy and the segment leg goes red; skip the <code>CopyValues</code> -- the new values leg goes red.</p>
Method TestAnHl7MessageIsEditedThroughItsContent()
{
    Set tText = $Parameter("OcuPilot.Test.InteropTestFixture", "DOCUMENTTEXT")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Hl7", tText _ $Char(13) _ "PID|1||123^^^MRN||DOE^JANE", ..#OPNAME, .tH), "an HL7 message of two segments is stored")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Port("EDIT", tH, .tRead)
    Do $$$AssertEquals(tCode, "200 ", "the edit read answers")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.Kind _ "|" _ tRead.Form.%Size() _ "|" _ tRead.Form.%Get(0).Field _ "|" _ tRead.Form.%Get(0).Required, "document|1|content|1", "a document with the one content field")
    Do $$$AssertTrue(tRead.Form.%Get(0).Value [ "MSH|^~\&|OCUSENDER|OCUFAC", "whose value is the raw view: " _ tRead.Form.%Get(0).Value)
    Set tNewText = $Replace($Replace(tText, "ADT^A01", "ADT^A08"), "MSG1", "MSG2")
    Set tFields = {}.%Set("content", tNewText, "string").%ToJSON()
    Set tCode = ..Dry(tH, tFields, .tDry)
    Do $$$AssertEquals(tCode, "200 ", "the review answers: " _ $Select($IsObject(tDry): tDry.%ToJSON(), 1: tDry))
    If '$IsObject(tDry) Quit
    Do $$$AssertEquals(tDry.rows.%Size() _ "|" _ tDry.rows.%Get(0).field, "1|Body", "one Body row")
    Do $$$AssertTrue((tDry.rows.%Get(0).before [ "ADT^A01") && (tDry.rows.%Get(0).after [ "ADT^A08"), "naming the changed text before and after")
    Set tCode = ..Send(tH, tFields, tDry.review.Digest, .tSent)
    Do $$$AssertEquals(tCode, "200 ", "the send is admitted: " _ $Select($IsObject(tSent): tSent.%ToJSON(), 1: tSent))
    If '$IsObject(tSent) Quit
    Set tNew = ..NewHeader(tSent, tH)
    Set tOriginalBody = $ClassMethod(..#FIXTURE, "Property", tH, "MessageBodyId")
    Set tNewBody = $ClassMethod(..#FIXTURE, "Property", tNew, "MessageBodyId")
    Do $$$AssertTrue((tNew > tTop) && (tNewBody '= tOriginalBody), "the new header names a copy of the body")
    Do $$$AssertEquals(..FieldsOf(tNew, "1:9,1:10,2:1"), "1:9=ADT^A08;1:10=MSG2;2:1=", "the copy carries the new segments, and the segment the text dropped is gone: " _ ..FieldsOf(tNew, "1:9,1:10,2:1"))
    Do $$$AssertEquals(..FieldsOf(tH, "1:9,1:10,2:1"), "1:9=ADT^A01;1:10=MSG1;2:1=1", "and the original keeps its own: " _ ..FieldsOf(tH, "1:9,1:10,2:1"))
    Do $$$AssertEquals($Piece(..FieldsOf(tNew, "DocType"), "=", 2), $Piece(..FieldsOf(tH, "DocType"), "=", 2), "the copy keeps the original's document type")
    Do $$$AssertTrue(..FieldsOf(tNew, "Source") [ ("Edited copy of " _ tOriginalBody), "and annotates its source with the original body's id: " _ ..FieldsOf(tNew, "Source"))
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Port("EDITRESEND", tH, .tResult, , {"content": "this is not an HL7 message"}.%ToJSON(), , .tFault)
    Do $$$AssertEquals(tCode _ "|" _ ..Violations(tFault), "422 " _ ##class(OcuPilot.Api.InteropError).#EDITVALUE _ "|content:" _ ##class(OcuPilot.Api.InteropError).#EDITVALUE, "a text the parser refuses is refused on content: " _ tCode)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "with nothing sent")
}

/// <p>AC5: a request of every field shape -- text, integer, closed list, a list with display words, boolean, a field of an embedded object
/// -- is edited on a clone: the supplied fields change, the credential-named ones and every field not supplied keep their value, and
/// neither the original nor the embedded object the clone started from is changed.</p>
/// <p>Mutation (Rule 19): pass <code>0</code> for <code>pCloneEmbedded</code> in <method>OcuPilot.Port.InteropPort.EditCloneHere</method>
/// -- the original's embedded city changes and this goes red.</p>
Method TestEveryFieldShapeIsEditedOnACloneAndTheOriginalIsLeftAlone()
{
    Set tFields = "Text,Count,Kind,Password,Flag,Level,Address.Street,Address.City,Credential.Value"
    Set tValues = {"Text": "orig", "Count": "3", "Kind": "alpha", "Password": "pw1", "Flag": "0", "Level": "L", "Address.Street": "1 Main", "Address.City": "Paris", "Credential.Value": "cred1"}
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StoredObject", ..#BODYCLASS, tValues, ..#OPNAME, .tO), "a request of every shape is stored")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Port("EDIT", tO, .tRead)
    Do $$$AssertEquals(tCode _ "|" _ tRead.Kind, "200 |object", "the edit read answers")
    If '$IsObject(tRead) Quit
    Set tPaths = ""
    Set tIterator = tRead.Form.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tPaths = tPaths _ $Select(tPaths = "": "", 1: ",") _ tRow.Field _ $Select(tRow.Secret: "!", 1: "")
    }
    Do $$$AssertEquals(tPaths, "Text,Count,Kind,Password!,Address.Street,Address.City,Flag,Level,Credential.Value!", "the form lists each field, the credential-named ones marked secret")
    Set tShown = ""
    Set tText = ""
    Set tIterator = tRead.Form.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Secret Set tShown = tShown _ tRow.Field _ "=[" _ tRow.Value _ "]"
        If tRow.Field = "Text" Set tText = tRow.Value
    }
    Do $$$AssertEquals(tShown _ "|" _ tText, "Password=[]Credential.Value=[]|orig", "a credential-named field shows no value and a plain one shows its own")
    Set tCode = ..Port("EDIT", tO, .tEcho, , {"Password": "x", "Text": "zzz"}.%ToJSON())
    Do $$$AssertEquals(tCode _ "|" _ $Select($IsObject(tEcho): tEcho.Fields, 1: ""), "200 |{""Text"":""zzz""}", "a read echoes the supplied fields but not a credential-named one: " _ tCode)
    Set tEdit = {"Text": "new text", "Count": "7", "Kind": "beta", "Address.City": "Lyon", "Flag": "1", "Level": "High"}.%ToJSON()
    Set tCode = ..Port("EDITRESEND", tO, .tResult, , tEdit, , .tFault)
    Do $$$AssertEquals(tCode, "200 ", "the edit and resend is admitted: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If '$IsObject(tResult) Quit
    Set tNew = tResult.NewId
    Do $$$AssertTrue(tNew > tTop, "a new header was made")
    Do $$$AssertEquals(..FieldsOf(tNew, tFields), "Text=new text;Count=7;Kind=beta;Password=pw1;Flag=1;Level=H;Address.Street=1 Main;Address.City=Lyon;Credential.Value=cred1", "the clone carries the supplied fields and keeps the rest")
    Do $$$AssertEquals(..FieldsOf(tO, tFields), "Text=orig;Count=3;Kind=alpha;Password=pw1;Flag=0;Level=L;Address.Street=1 Main;Address.City=Paris;Credential.Value=cred1", "the original is not changed, its embedded city included")
}

/// <p>AC5: an edit is refused before anything is sent when the body is of a document kind OcuPilot does not edit (X12), is only a
/// stream, or is of a class whose name begins <code>OcuPilot</code> (never opened, so no body is recorded as viewed); when no supplied
/// field changes anything; and, 422 on the path, for a path that is no field, a credential-named field, a value outside a closed
/// list, one its datatype refuses and a required field left empty. A message that cannot go reads
/// <code>INTEROP.RESEND.NONE</code>, and one no header holds is not found.</p>
/// <p>Mutation (Rule 19): drop the class-name test at the top of <method>OcuPilot.Port.InteropPort.EditBodyFacts</method> -- the
/// <code>OcuPilot</code> leg opens the body and goes red.</p>
Method TestWhatCannotBeEditedIsRefusedWithNothingSent()
{
    Set tValues = {"Text": "orig", "Count": "3", "Kind": "alpha", "Password": "pw1"}
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StoredObject", ..#BODYCLASS, tValues, ..#OPNAME, .tO), "a request is stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StoredObject", ..#OWNBODYCLASS, {"Text": "own"}, ..#OPNAME, .tOwn), "so is one of a class named OcuPilot")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "X12", ..#OPNAME, .tX12), "so is an X12 document")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StreamBody", "streamed", ..#OPNAME, .tStream), "and a stream")
    Set tOff = ..Make("off", ..#OFFNAME)
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tGot = ..Port("EDIT", tX12) _ "|" _ ..Port("EDIT", tStream) _ "|" _ ..Port("EDIT", tOwn)
    Do $$$AssertEquals(tGot, "409 INTEROP.EDIT.NOTEDITABLE|409 INTEROP.EDIT.NOTEDITABLE|409 INTEROP.EDIT.NOTEDITABLE", "an X12 body, a stream and an OcuPilot class are not editable: " _ tGot)
    Do $$$AssertEquals(..Views(tSince, tX12) _ "|" _ ..Views(tSince, tStream) _ "|" _ ..Views(tSince, tOwn), "1|1|0", "the first two were opened and recorded as viewed once each, and the OcuPilot body was never opened")
    Do $$$AssertEquals(..Port("EDITRESEND", tX12, , , {"x": "y"}.%ToJSON()), "409 INTEROP.EDIT.NOTEDITABLE", "the write refuses them as well")
    Do $$$AssertEquals(..Port("EDITRESEND", tO, , , {"Text": "orig"}.%ToJSON()), "409 INTEROP.EDIT.NOCHANGE", "a change that changes nothing is refused")
    Do $$$AssertEquals(..Port("EDITRESEND", tO, , , "{}"), "409 INTEROP.EDIT.NOCHANGE", "so is one that supplies nothing")
    For tCase = $ListBuild("Nope", "x", "Nope:" _ ##class(OcuPilot.Api.InteropError).#EDITFIELD), $ListBuild("Password", "x", "Password:" _ ##class(OcuPilot.Api.InteropError).#EDITSECRET), $ListBuild("Kind", "delta", "Kind:" _ ##class(OcuPilot.Api.InteropError).#EDITVALUE), $ListBuild("Count", "abc", "Count:" _ ##class(OcuPilot.Api.InteropError).#EDITVALUE), $ListBuild("Text", "", "Text:" _ ##class(OcuPilot.Api.InteropError).#EDITVALUE) {
        Set tCode = ..Port("EDITRESEND", tO, , , {}.%Set($List(tCase, 1), $List(tCase, 2), "string").%ToJSON(), , .tFault)
        Set tGot = tCode _ "|" _ ..Violations(tFault)
        Do $$$AssertEquals(tGot, "422 " _ $Piece($List(tCase, 3), ":", 2) _ "|" _ $List(tCase, 3), "'" _ $List(tCase, 1) _ "' = '" _ $List(tCase, 2) _ "' is refused: " _ tGot)
    }
    Do $$$AssertEquals(..Port("EDITRESEND", tOff, , , {"StringValue": "x"}.%ToJSON()), "409 INTEROP.RESEND.NONE", "a message whose target is disabled cannot go")
    Do $$$AssertEquals(..Port("EDIT", tOff, .tRead) _ "|" _ $Select($IsObject(tRead): tRead.Verdict _ "|" _ tRead.Kind, 1: ""), "200 |targetoff|", "and its read answers the verdict and no form")
    Do $$$AssertEquals(..Views(tSince, tOff), 0, "without opening its body")
    Do $$$AssertEquals(..Port("EDIT", ..#GONE), "404 PORT.NOTFOUND", "a message no header holds is not found")
    Do $$$AssertEquals(..Port("EDIT", "abc"), "400 PORT.VALIDATION", "and an id that is no number is refused")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent")
}

/// <p>AC4: a body edited after a review moves the form's digest. The person's send carrying the digest of the earlier review is refused
/// 409 <code>INTEROP.RESEND.CHANGED</code>, and the agent's proposal minted before the body changed is closed target-changed on the
/// confirm, each with nothing sent.</p>
/// <p>Mutation (Rule 19): make <code>tOriginal</code> <code>""</code> in <method>OcuPilot.Port.InteropPort.ReadEdit</method> -- both legs
/// send and go red.</p>
Method TestABodyEditedAfterTheReviewIsRefusedForThePersonAndTheAgent()
{
    Set tB = ..Make("beta")
    Set tFields = {"StringValue": "edited"}.%ToJSON()
    Set tCode = ..Dry(tB, "", .tForm)
    Do $$$AssertEquals(tCode, "200 ", "the form is reviewed")
    If '$IsObject(tForm) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetBodyProperty", tB, "StringValue", "moved"), "the body is changed by someone else after the review")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tCode = ..Send(tB, tFields, tForm.review.Digest, .tRefused)
    Do $$$AssertEquals(tCode, "409 INTEROP.RESEND.CHANGED", "the digest of that review is refused: " _ $Select($IsObject(tRefused): tRefused.%ToJSON(), 1: tRefused))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Set tA = ..Make("alpha")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Message": (tA), "Fields": {"StringValue": "edited"}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the edit mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetBodyProperty", tA, "StringValue", "moved"), "the body is changed after the mint")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a moved target: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC4: a person's edit is held to the digest of its review. A digest of the wrong length, of zeros, the digest of another message's
/// form or one that is not hex at all is refused 409 <code>INTEROP.RESEND.CHANGED</code>, nothing is sent, and
/// the reviewed digest then sends the copy.</p>
/// <p>Mutation (Rule 19): compare only the first 8 characters of the digest in <method>OcuPilot.Port.InteropPort.ReadEdit</method> -- the
/// truncated and foreign rows go red.</p>
Method TestAForgedTruncatedOrForeignDigestIsRefusedForTheEditAndOnlyTheReviewedOneSends()
{
    Set tB = ..Make("beta")
    Set tOther = ..Make("other")
    Set tFields = {"StringValue": "edited"}.%ToJSON()
    Do $$$AssertEquals(..Dry(tB, "", .tForm) _ "|" _ ..Dry(tOther, "", .tForeign), "200 |200 ", "two messages are reviewed")
    If '$IsObject(tForm) || '$IsObject(tForeign) Quit
    Set tDigest = tForm.review.Digest
    Do $$$AssertNotEquals(tForeign.review.Digest, tDigest, "their digests differ")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    For tCase = $ListBuild("64 letters a", $Translate($Justify("", 64), " ", "a")), $ListBuild("64 zeros", $Translate($Justify("", 64), " ", "0")), $ListBuild("the digest less its last digit", $Extract(tDigest, 1, 63)), $ListBuild("the digest of another message", tForeign.review.Digest), $ListBuild("a word", "reviewed") {
        Set tCode = ..Send(tB, tFields, $List(tCase, 2), .tRefused)
        Do $$$AssertEquals(tCode, "409 INTEROP.RESEND.CHANGED", $List(tCase, 1) _ " is refused as a review the verdicts no longer give")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "and nothing was sent")
    Do $$$AssertEquals(..Send(tB, tFields, tDigest, .tSent), "200 ", "the reviewed digest sends: " _ $Select($IsObject(tSent): $Extract(tSent.%ToJSON(), 1, 200), 1: tSent))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") - tTop, 1, "one copy")
}

/// <p>AC5, AD-59: what an edit refuses at the port is refused the same way at the person's review and at the agent's mint -- 422 naming the
/// credential-named field, the path that is no field and the value its field refuses, 409 for a body of another kind -- with no card
/// minted for the agent, so no copy-out script can carry a credential, and nothing sent.</p>
/// <p>Mutation (Rule 19): drop the credential-named test from the object branch of <method>OcuPilot.Port.InteropPort.ReadEdit</method> --
/// the credential rows go red.</p>
Method TestWhatAnEditRefusesIsRefusedTheSameAtTheReviewAndTheMint()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StoredObject", ..#BODYCLASS, {"Text": "orig", "Count": "3", "Kind": "alpha", "Password": "pw1"}, ..#OPNAME, .tO), "a request is stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "X12", ..#OPNAME, .tX12), "so is an X12 document")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tViolation = ##class(OcuPilot.Api.InteropError).#EDITVALUE
    For tCase = $ListBuild("Password", "x", ##class(OcuPilot.Api.InteropError).#EDITSECRET), $ListBuild("Nope", "x", ##class(OcuPilot.Api.InteropError).#EDITFIELD), $ListBuild("Kind", "delta", tViolation), $ListBuild("Count", "abc", tViolation) {
        Set tPath = $List(tCase, 1)
        Set tWant = "422 " _ $List(tCase, 3) _ "|" _ tPath _ ":" _ $List(tCase, 3)
        Set tCode = ..Dry(tO, {}.%Set(tPath, $List(tCase, 2), "string").%ToJSON(), .tDry)
        Do $$$AssertEquals(tCode _ "|" _ ..Violations(tDry), tWant, "the review refuses " _ tPath _ " = '" _ $List(tCase, 2) _ "': " _ tCode)
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Message": (tO), "Fields": ({}.%Set(tPath, $List(tCase, 2), "string"))}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertTrue($$$ISERR(tSC) && '$IsObject($Get(tProposal)) && ($Get(tHttp) = 422), "the mint refuses it and writes no card: " _ $Get(tHttp))
        Do $$$AssertEquals(..Violations($Get(tFault)), tPath _ ":" _ $List(tCase, 3), "naming " _ tPath)
    }
    Do $$$AssertEquals(..Dry(tX12, {"x": "y"}.%ToJSON()), "409 INTEROP.EDIT.NOTEDITABLE", "the review refuses a body of another kind")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Message": (tX12), "Fields": {"x": "y"}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertTrue($$$ISERR(tSC) && '$IsObject($Get(tProposal)) && ($Get(tHttp) = 409), "and so does the mint: " _ $Get(tHttp))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent")
}

/// <p>An edit whose copy was saved and then refused by the vendor leaves no copy behind and sends nothing: no header names the copy, so
/// the port deletes it.</p>
/// <p>Mutation (Rule 19): drop the delete of the copy from <method>OcuPilot.Port.InteropPort.EditCloneHere</method> -- the body count
/// grows by one and this goes red.</p>
Method TestACopyTheVendorRefusedAfterTheSaveIsDeleted()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tBodies = $ClassMethod(..#FIXTURE, "StringRequestCount")
    Do ..HoldPairs(1)
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "RefuseEditAfterSave")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tA
    Set tQuery("fields") = {"StringValue": "edited"}.%ToJSON()
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Messages", "EDITRESEND", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue(+$Get(tHttp) >= 400, "the write is refused: " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "no header was made")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "StringRequestCount"), tBodies, "and the copy that was saved is gone")
}

/// <p>A production that is not running is refused 409 <code>INTEROP.PRODUCTION.NOTRUNNING</code> by the edit read, the review and the
/// write, with nothing sent.</p>
/// <p>Mutation (Rule 19): drop the not-running refusal from <method>OcuPilot.Port.InteropPort.ReadEdit</method> -- the three legs
/// answer another refusal and this goes red.</p>
Method TestAStoppedProductionIsRefusedByTheEditReadReviewAndWrite()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the production is stopped")
    Do $$$AssertEquals(..Port("EDIT", tA) _ "|" _ ..Port("EDITRESEND", tA, , , {"StringValue": "x"}.%ToJSON()), "409 INTEROP.PRODUCTION.NOTRUNNING|409 INTEROP.PRODUCTION.NOTRUNNING", "the port's read and write are refused")
    Do $$$AssertEquals(..Dry(tA), "409 INTEROP.PRODUCTION.NOTRUNNING", "and so is the review")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "nothing was sent")
}

/// <p>AD-59: the copy-out draft of an edit renders the script that opens the message and its body, clones it, sets each changed field on
/// the clone (a closed list's display word converted, an embedded object copied first) and resends the header with the clone; the draft
/// sends nothing, and running the script leaves the clone and the original as the write does.</p>
/// <p>Mutation (Rule 19): drop the embedded object's <code>%ConstructClone(1)</code> from <method>OcuPilot.Port.InteropPort.MessageSnippet</method>
/// -- the original's embedded city changes under the script and this goes red.</p>
Method TestTheCopyOutDraftOfAnEditRendersItsScriptAndRunningItDoesTheSame()
{
    Set tFields = "Text,Level,Address.City"
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StoredObject", ..#BODYCLASS, {"Text": "orig", "Level": "L", "Address.City": "Paris"}, ..#OPNAME, .tO), "a request is stored")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Message": (tO), "Fields": {"Text": "new", "Level": "High", "Address.City": "Lyon"}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the edit mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSC = ..TakeDraft(tProposal.proposalId, .tDraft, .tText)
    Do $$$AssertStatusOK(tSC, "the draft is taken")
    If '$IsObject($Get(tDraft)) Quit
    Do $$$AssertEquals(tDraft.state _ "|" _ tDraft.closedReason _ "|" _ tDraft.draft.steps.%Get(0).kind, "canceled|draft|objectscript", "an ObjectScript draft that closes the proposal")
    Do $$$AssertTrue((tText [ "%OpenId(""" _ tO _ """)") && (tText [ "%ConstructClone(0)") && (tText [ "%ConstructClone(1)") && (tText [ "DisplayToLogical") && (tText [ "ResendDuplicatedMessage(""" _ tO _ """, .tNew, """", tClone)"), "the script opens, clones, converts and resends: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "the draft sent nothing")
    Do $$$AssertStatusOK(..RunScript(tText), "the script runs")
    Set tNew = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertTrue(tNew > tTop, "and resent the message")
    Do $$$AssertEquals(..FieldsOf(tNew, tFields), "Text=new;Level=H;Address.City=Lyon", "the clone carries the edit")
    Do $$$AssertEquals(..FieldsOf(tO, tFields), "Text=orig;Level=L;Address.City=Paris", "and the original is not changed")
}

/// <p>AD-59: the copy-out draft of an HL7 v2 edit renders the script that clones the body, clears it, annotates its source, parses the new
/// text from a character stream, copies its separators and values in, and resends the header with the clone; the draft sends nothing,
/// and running the script leaves the clone and the original as the write does.</p>
/// <p>Mutation (Rule 19): drop the <code>Clear()</code> line from the document branch of
/// <method>OcuPilot.Port.InteropPort.MessageSnippet</method> -- the segment the text dropped stays on the script's copy and this goes
/// red.</p>
Method TestTheCopyOutDraftOfAnHl7EditRendersItsScriptAndRunningItDoesTheSame()
{
    Set tText = $Parameter("OcuPilot.Test.InteropTestFixture", "DOCUMENTTEXT")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Hl7", tText _ $Char(13) _ "PID|1||123^^^MRN||DOE^JANE", ..#OPNAME, .tH), "an HL7 message of two segments is stored")
    Set tNewText = $Replace($Replace(tText, "ADT^A01", "ADT^A08"), "MSG1", "MSG2")
    Do ..EnableKey(..#KEY)
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, {"Message": (tH), "Fields": {"content": (tNewText)}}, tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the edit mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tSC = ..TakeDraft(tProposal.proposalId, .tDraft, .tScript)
    Do $$$AssertStatusOK(tSC, "the draft is taken")
    If '$IsObject($Get(tDraft)) Quit
    Do $$$AssertTrue((tScript [ ".Clear()") && (tScript [ "ImportFromLibraryStream") && (tScript [ ".Separators = ") && (tScript [ ".CopyValues(") && (tScript [ "Edited copy of ") && (tScript [ "ResendDuplicatedMessage(""" _ tH _ """, .tNew, """", tClone)"), "the script clones, clears, parses, copies and resends: " _ tScript)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId"), tTop, "the draft sent nothing")
    Do $$$AssertStatusOK(..RunScript(tScript), "the script runs")
    Set tNew = $ClassMethod(..#FIXTURE, "TopId")
    Do $$$AssertTrue(tNew > tTop, "and resent the message")
    Do $$$AssertEquals(..FieldsOf(tNew, "1:9,1:10,2:1"), "1:9=ADT^A08;1:10=MSG2;2:1=", "the copy carries the new segments and not the dropped one: " _ ..FieldsOf(tNew, "1:9,1:10,2:1"))
    Do $$$AssertTrue(..FieldsOf(tNew, "Source") [ "Edited copy of ", "and annotates its source: " _ ..FieldsOf(tNew, "Source"))
    Do $$$AssertEquals(..FieldsOf(tH, "1:9,1:10,2:1"), "1:9=ADT^A01;1:10=MSG1;2:1=1", "and the original is not changed")
}

/// <p>AC6: one <code>ViewContents</code> audit row names the message each edit read that opened a body reads, and a read that opens none
/// leaves none; the edit read of a request that can go, repeated, adds one row each time.</p>
/// <p>Mutation (Rule 19): drop <code>AuditViewHere</code> from <method>OcuPilot.Port.InteropPort.EditBodyFacts</method> -- this goes
/// red.</p>
Method TestEachEditReadThatOpensABodyIsAuditedOnce()
{
    Set tA = ..Make("alpha")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Views(tSince, tA), 0, "nothing was viewed yet")
    Do $$$AssertEquals(..Port("EDIT", tA), "200 ", "the first read answers")
    Do $$$AssertEquals(..Views(tSince, tA), 1, "one row names the message")
    Do $$$AssertEquals(..Port("EDIT", tA, , , {"StringValue": "edited"}.%ToJSON(), "EDITRESEND"), "200 ", "a read composed for the write answers")
    Do $$$AssertEquals(..Views(tSince, tA), 2, "and adds one")
}

}

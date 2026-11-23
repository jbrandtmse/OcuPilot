/// <p>What Story 24.16's armed suspended message suites share, beyond <class>OcuPilot.Test.InteropResendCase</class> (the arming check, the probe production in
/// <code>USER</code> started before each test and stopped after it, the sweep of every message the suite made, the governance key a test turns on, the HTTP and port calls):
/// suspended probe messages (a stored request set to Suspended, <method>OcuPilot.Test.InteropResendFixture.Suspend</method>), the calls of the Suspended messages screen and port,
/// the probe headers <class>OcuPilot.Test.InteropPurgeFixture</class> stores in <code>HSCUSTOM</code>, where no production runs, and their removal from both namespaces
/// before and after every test, asserted clean. A suite extends it for its tests.</p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropSuspendedCase Extends OcuPilot.Test.InteropResendCase [ Abstract ]
{

Parameter SEAM = "OcuPilot.Test.InteropSuspendedSeam";

Parameter PURGEFIXTURE = "OcuPilot.Test.InteropPurgeFixture";

Parameter ENDPOINT = "SuspendedMessages";

Parameter SCREEN = "/screens/interop.suspendedmessages";

Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>The governance keys of the four tools.</p>
Parameter RESUBMITKEY = "interop.suspendedmessages.resubmit";

Parameter EDITKEY = "interop.suspendedmessages.editresubmit";

Parameter DISCARDKEY = "interop.suspendedmessages.discard";

Parameter DELETEKEY = "interop.suspendedmessages.delete";

Parameter RESUBMITTOOL = "OcuPilot.Screen.Tool.InteropSuspendedResubmit";

Parameter EDITTOOL = "OcuPilot.Screen.Tool.InteropSuspendedEditResubmit";

Parameter DISCARDTOOL = "OcuPilot.Screen.Tool.InteropSuspendedDiscard";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.InteropSuspendedDelete";

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##super()
    If $$$ISOK(tSC) Do $ClassMethod(..#PURGEFIXTURE, "DropProbes")
    Quit tSC
}

/// <p>The probe headers of both namespaces are removed before each test, so no test reads what another left, and a failing status when one survives.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##super()
    If '$ClassMethod(..#PURGEFIXTURE, "DropProbes") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, ..%ClassName(1) _ " found probe headers in USER or HSCUSTOM before a test"))
    Do $$$AssertEquals($ClassMethod(..#PURGEFIXTURE, "Counts", ..#OTHERNAMESPACE), "header=0 body=0 log=0 io=0 alertClosed=0 alertOpen=0", "HSCUSTOM holds no probe when the test starts")
    Quit tSC
}

/// <p>The probe headers of both namespaces are removed after each test, whether it passed or failed, and asserted gone.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ##super()
    Do $$$AssertTrue($ClassMethod(..#PURGEFIXTURE, "DropProbes"), "the probe headers in USER and HSCUSTOM are removed after the test")
    Quit tSC
}

/// <p>The case's own cleanup, then a failing status when a probe header survives in either namespace.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ##super()
    If '$ClassMethod(..#PURGEFIXTURE, "DropProbes") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, ..%ClassName(1) _ " left probe headers in USER or HSCUSTOM"))
    Quit tSC
}

/// <p>Store a string request <var>pText</var> addressed to <var>pTarget</var> and set it Suspended; its header id.</p>
Method Susp(pText As %String, pTarget As %String = {..#OPNAME}) As %String
{
    Set tSC = $ClassMethod(..#FIXTURE, "Suspended", pText, pTarget, .tId)
    Do $$$AssertStatusOK(tSC, "the suspended request '" _ pText _ "' to " _ pTarget _ " is stored")
    Quit $Get(tId)
}

/// <p>The stored status of the header <var>pId</var> in <code>USER</code> (5 Suspended, 4 Discarded, 9 Completed), <code>&lt;none&gt;</code> for a header that is gone.</p>
ClassMethod Status(pId As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "Property", pId, "Status")
}

/// <p>Wait, <var>pSeconds</var> at most, until the header <var>pId</var> reads status <var>pStatus</var> in <code>USER</code>; whether it did.</p>
ClassMethod Await(pId As %String, pStatus As %Integer, pSeconds As %Integer = 30) As %Boolean
{
    For tTry = 1:1:(pSeconds * 4) {
        If ..Status(pId) = pStatus Quit
        Hang 0.25
    }
    Quit (..Status(pId) = pStatus)
}

/// <p>The person's review of <var>pAction</var> (<code>resubmit</code>, <code>discard</code> or <code>delete</code>) over the set <var>pSet</var>, or of
/// <code>editresubmit</code> over one message with the fields <var>pFields</var> (JSON object text; none asks for the form) (<code>POST /dryrun</code>):
/// <code>status code</code>.</p>
ClassMethod Dry(pAction As %String, pSet As %String, Output pAnswer, pFields As %String = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pSet, "string")
    If pFields '= "" {
        Set tValues = {}
        Do tValues.%Set("fields", pFields, "string")
        Do tBody.%Set("values", tValues)
    }
    Quit ..Post(..#SCREEN _ "/dryrun", tBody, .pAnswer)
}

/// <p>The person's <var>pAction</var> over <var>pSet</var> carrying the digest <var>pReviewed</var> and, for an edit, the fields <var>pFields</var>
/// (<code>POST /action</code>): <code>status code</code>.</p>
ClassMethod Send(pAction As %String, pSet As %String, pReviewed As %String, Output pAnswer, pFields As %String = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pSet, "string")
    Set tValues = {}
    Do tValues.%Set("Reviewed", pReviewed, "string")
    If pFields '= "" Do tValues.%Set("fields", pFields, "string")
    Do tBody.%Set("values", tValues)
    Quit ..Post(..#SCREEN _ "/action", tBody, .pAnswer)
}

/// <p>The digest a dry run answered, <code>""</code> for none.</p>
ClassMethod Digest(pAnswer) As %String
{
    Quit $Select($IsObject(pAnswer) && $IsObject(pAnswer.%Get("review")): pAnswer.review.Digest, 1: "")
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

/// <p>The Suspended messages call <var>pType</var> of the port, as the running account, over the ids <var>pId</var> in <var>pNamespace</var>, with the digest
/// <var>pReviewed</var>, the fields <var>pFields</var> and the composing action <var>pAction</var> when they are not empty: <code>status code</code>, the answer in
/// <var>pResult</var> and the fault in <var>pFault</var>. <var>pPort</var> names the class that serves it (a seam, to hold the gate's pairs).</p>
ClassMethod SPort(pType As %String, pId As %String, Output pResult, pReviewed As %String = "", pFields As %String = "", pAction As %String = "", Output pFault, pNamespace As %String = {..#NAMESPACE}, pPort As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pId '= "" Set tQuery("id") = pId
    If pReviewed '= "" Set tQuery("digest") = pReviewed
    If pFields '= "" Set tQuery("fields") = pFields
    If pAction '= "" Set tQuery("action") = pAction
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod(pPort, "Invoke", ..#ENDPOINT, pType, .tQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>Hold, for the fake gate, the pairs of a principal who lists suspended messages and, as <var>pKind</var> says (<code>resubmit</code>, <code>edit</code>,
/// <code>discard</code> or <code>delete</code>), acts on them, and READ and WRITE on <code>USER</code>'s database.</p>
ClassMethod HoldFor(pKind As %String)
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageHeader", "USE")
    If (pKind = "resubmit") || (pKind = "edit") Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageResend", "USE")
    If pKind = "edit" {
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageContent", "USE")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageEditResend", "USE")
    }
    If (pKind = "discard") || (pKind = "delete") Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageDiscard", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p>Store a Suspended probe header in <code>HSCUSTOM</code>, where no production runs, with a probe body (<method>OcuPilot.Test.InteropPurgeFixture.Header</method>); its
/// id. <var>pSuffix</var> tells probes apart.</p>
ClassMethod OtherSuspended(pSuffix As %String) As %Integer
{
    Quit $ClassMethod(..#PURGEFIXTURE, "Header", ..#OTHERNAMESPACE, 5, 0, 1, "", pSuffix)
}

/// <p>The stored status of the header <var>pId</var> in <code>HSCUSTOM</code>, <code>&lt;none&gt;</code> for a header that is gone.</p>
ClassMethod OtherStatus(pId As %String) As %String
{
    Set tStatus = "<none>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#OTHERNAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) Set tStatus = tHeader.Status
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStatus = "<unread>"
    }
    Quit tStatus
}

/// <p>Set the stored status of the header <var>pId</var> in <code>USER</code> to <var>pStatus</var> through the vendor's <code>SetStatus</code>: a message that moved after
/// a review.</p>
ClassMethod Move(pId As %String, pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) {
            Do tHeader.SetStatus(pStatus)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "no message header " _ pId)
        }
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The body the header <var>pId</var> names in <code>USER</code>, as <code>class|id</code>; the body is <code>Ens.StringRequest</code>'s in a probe.</p>
ClassMethod BodyOf(pId As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "Property", pId, "MessageBodyClassName") _ "|" _ $ClassMethod(..#FIXTURE, "Property", pId, "MessageBodyId")
}

/// <p>The <code>StringValue</code> of the body <var>pBody</var> (<method>BodyOf</method>'s), <code>&lt;none&gt;</code> for a body that is gone.</p>
ClassMethod BodyText(pBody As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "BodyFields", $Piece(pBody, "|", 1), $Piece(pBody, "|", 2), "StringValue")
}

/// <p>Delete the body <var>pBody</var> (<method>BodyOf</method>'s) from <code>USER</code>: the body an edit left behind, which no header names and the sweep does not reach.</p>
ClassMethod DropBody(pBody As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%Dictionary.CompiledClass).%ExistsId($Piece(pBody, "|", 1)) Do $ClassMethod($Piece(pBody, "|", 1), "%DeleteId", $Piece(pBody, "|", 2))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> audit event since <var>pSince</var> whose payload carries the action <var>pAction</var> (<code>discard</code> or
/// <code>delete</code>): their count, and the last one's data in <var>pData</var>.</p>
ClassMethod OwnRows(pSince As %String, pAction As %String, Output pData) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", """verb"":""" _ pAction _ """", .pData)
}

}

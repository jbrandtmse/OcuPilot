/// <p>The port to the instance's running SQL statements (AD-29, AD-36, Story 19.10): <b>the only
/// product class that reads <code>INFORMATION_SCHEMA.CURRENT_STATEMENTS</code></b>, in the caller's
/// process and namespace, as the signed-in user. Nothing here issues an HTTP request or switches
/// namespace.</p>
/// <p><b>Why its own gate.</b> The table answers every running statement on the instance, in every
/// namespace and of every user, to any principal that can run SQL (measured), so
/// <method>Invoke</method> first requires <parameter>PAIRS</parameter>, the classic Currently running
/// SQL statements page's measured audience, through <method>OcuPilot.Screen.Gate.EvaluateRequired</method>.
/// A caller missing one is refused 403 <code>PORT.ACCESSDENIED</code> with
/// <code>detail.failedPair</code>, before any statement is prepared.</p>
/// <p><b>One fixed statement</b>, <parameter>CURRENTSTATEMENTS</parameter>, binds nothing and never
/// selects <code>Parameters</code>, which holds a statement's bound values in clear (measured; AD-35).
/// The reading process's own statement is left out.</p>
/// <p><b>A statement's text</b> comes from the vendor's documented
/// <code>INFORMATION.SCHEMA.CURRENTSTATEMENTS.GetSQLStatement</code>, which maps two answers:</p>
/// <ul>
/// <li>Without READ on the statement's namespace's database it raises <code>&lt;PROTECT&gt;</code> and
/// writes a <code>%System/%Security/Protect</code> audit row, so the port calls it only for a caller
/// holding READ on that namespace's routines and globals databases, and answers <code>""</code>
/// otherwise.</li>
/// <li>Another user's statement read without <code>%Development:USE</code> answers #921, which the port
/// answers as <code>""</code>.</li>
/// </ul>
/// <p>Any other vendor error fails the whole read 500 <code>INTERNAL</code>; the vendor's text goes to
/// <method>LogFault</method> and nowhere else (AD-39).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LocalServer</method>,
/// <method>Resources</method>, <method>Rows</method>, <method>Text</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.SqlActivityPort Extends %RegisteredObject
{

/// <p>The pair set every call requires, comma-separated as <code>resource:permission</code>, in the
/// order the gate reports in (AD-8, AD-29).</p>
Parameter PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The one endpoint this port serves: the instance's running SQL statements.</p>
Parameter ENDPOINT = "CurrentStatements";

/// <p>The running statements as rows.</p>
Parameter TYPELIST = "LIST";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The one statement this port prepares, slowest first. Its columns are read by position in
/// <method>Rows</method>; <class>OcuPilot.Test.SqlActivityPort</class> pins each against the vendor
/// class.</p>
Parameter CURRENTSTATEMENTS = "SELECT Server, ProcessID, UserName, Namespace, CASE WHEN Parent IS NULL THEN QueryRunType ELSE (ParentType || ((' Query'))) END, ROUND(ExecutionDuration, 3), ExecutionStart, SQLStatementID, StatementIndexHash, CallerName, CachedQuery, CurrentWorkerCount, TP_NestingLevel FROM INFORMATION_SCHEMA.CURRENT_STATEMENTS ORDER BY ExecutionDuration DESC";

/// <p>The longest statement text answered whole; a longer one is cut to
/// <parameter>TEXTKEEP</parameter> characters and <parameter>TEXTMARK</parameter> (AD-36).</p>
Parameter TEXTMAX As INTEGER = 1024;

Parameter TEXTKEEP As INTEGER = 1021;

Parameter TEXTMARK = "...";

/// <p>The vendor's answer for another user's statement read without <code>%Development:USE</code>.</p>
Parameter CODEWITHHELD = 921;

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "sqlactivityport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p><parameter>PAIRS</parameter> as the <code>%List</code> of two-element <code>%List</code>s the
/// gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#PAIRS)
}

/// <p>This instance's own <code>Server</code> value: the host name and the superserver port, as the
/// classic page composes it.</p>
ClassMethod LocalServer() As %String
{
    Quit $ZU(110) _ ":" _ $Get(^%SYS("SSPort"))
}

/// <p>Whether a row's <var>pServer</var> names another instance than <var>pLocal</var>, ignoring case,
/// as the classic page tests it. Pure.</p>
ClassMethod IsRemote(pServer As %String, pLocal As %String = {..LocalServer()}) As %Boolean
{
    Quit ($ZConvert(pServer, "U") '= $ZConvert(pLocal, "U"))
}

/// <p><var>pText</var> as a row shows it: leading and trailing white space and control characters
/// stripped, and cut to <parameter>TEXTKEEP</parameter> characters and <parameter>TEXTMARK</parameter>
/// when it is longer than <parameter>TEXTMAX</parameter>. Pure.</p>
ClassMethod Shape(pText As %String) As %String
{
    Set tText = $ZStrip(pText, "<>WC")
    If $Length(tText) > ..#TEXTMAX Set tText = $Extract(tText, 1, ..#TEXTKEEP) _ ..#TEXTMARK
    Quit tText
}

/// <p>Serve <parameter>ENDPOINT</parameter> for request type <parameter>TYPELIST</parameter>, after
/// <parameter>PAIRS</parameter>.</p>
/// <p><var>pQuery</var> may carry <parameter>MAXROWSKEY</parameter>, a whole number above zero;
/// <parameter>DEFAULTMAXROWS</parameter> when absent. <var>pBody</var> must be empty.</p>
/// <p>On success, at 200, <var>pResult</var> is an array of at most that many rows, slowest first, each
/// <code>{Server, ProcessID, UserName, Namespace, RunType, Elapsed, Started, StatementId,
/// StatementHash, Statement, Routine, CachedQuery, Workers, TransactionLevel, Remote}</code>.
/// <code>Statement</code> is <code>""</code> where the text is withheld.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>PORT.ACCESSDENIED</code> with
/// <code>detail.failedPair</code>; 501 <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type;
/// 400 <code>PORT.VALIDATION</code> for a cap of the wrong shape; and 500 <code>INTERNAL</code>,
/// logged, for a body or any failure, no rows answered.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: a PAIRS parameter mis-edited to empty fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a SQL activity read takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint '= ..#ENDPOINT) || (pType '= ..#TYPELIST) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)

        Set tRowsSC = ..Rows(tMax, .tRows)
        If $$$ISERR(tRowsSC) {
            Set tSC = ..Fail("the running statements could not be read", tRowsSC, .pHttpStatus, .pFault)
            Quit
        }
        Kill tAllowed
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tTextSC = ..StatementText(tRow.%Get("Namespace"), tRow.%Get("StatementHash"), .tAllowed, .tText)
            If $$$ISERR(tTextSC) Quit
            Do tRow.%Set("Statement", tText, "string")
        }
        If $$$ISERR($Get(tTextSC, $$$OK)) {
            Set tSC = ..Fail("a running statement's text could not be read", tTextSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = tRows
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The running statements, slowest first and at most <var>pMax</var> of them, through
/// <parameter>CURRENTSTATEMENTS</parameter> prepared in the process's own namespace. The reading
/// process's own statement is left out, and each row's <code>Statement</code> is <code>""</code> until
/// <method>Invoke</method> fills it.</p>
ClassMethod Rows(pMax As %Integer, Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Try {
        Set tLocal = ..LocalServer()
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare(..#CURRENTSTATEMENTS)
        If $$$ISERR(tSC) Quit
        Set tRS = tStatement.%Execute()
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$SQLCode, tRS.%SQLCODE, tRS.%Message)
            Quit
        }
        Set tFound = 0
        While tRS.%Next() {
            If tFound >= pMax Quit
            Set tServer = tRS.%GetData(1)
            Set tRemote = ..IsRemote(tServer, tLocal)
            Set tPid = tRS.%GetData(2)
            If 'tRemote && (tPid = $Job) Continue
            Set tRow = {}
            Do tRow.%Set("Server", tServer, "string")
            Do tRow.%Set("ProcessID", +tPid, "number")
            Do tRow.%Set("UserName", tRS.%GetData(3), "string")
            Do tRow.%Set("Namespace", tRS.%GetData(4), "string")
            Do tRow.%Set("RunType", tRS.%GetData(5), "string")
            Do tRow.%Set("Elapsed", +tRS.%GetData(6), "number")
            Do tRow.%Set("Started", tRS.%GetData(7), "string")
            Do tRow.%Set("StatementId", tRS.%GetData(8), "string")
            Do tRow.%Set("StatementHash", tRS.%GetData(9), "string")
            Do tRow.%Set("Statement", "", "string")
            Do tRow.%Set("Routine", tRS.%GetData(10), "string")
            Do tRow.%Set("CachedQuery", tRS.%GetData(11), "string")
            Do tRow.%Set("Workers", +tRS.%GetData(12), "number")
            Do tRow.%Set("TransactionLevel", +tRS.%GetData(13), "number")
            Do tRow.%Set("Remote", tRemote, "boolean")
            Do pRows.%Push(tRow)
            Set tFound = tFound + 1
        }
        If tRS.%SQLCODE < 0 Set tSC = $$$ERROR($$$SQLCode, tRS.%SQLCODE, tRS.%Message)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>The text of the statement <var>pHash</var> running in <var>pNamespace</var>, shaped
/// (<method>Shape</method>), in <var>pText</var>. <var>pAllowed</var> holds, per namespace, whether the
/// caller holds READ on its routines and globals databases, resolved once per read through
/// <method>OcuPilot.Port.AtelierPort.DatabaseResources</method>; a namespace whose resources do not
/// resolve, or whose pairs the caller lacks, answers <code>""</code> without calling the vendor. An
/// error status is a vendor answer other than #921.</p>
ClassMethod StatementText(pNamespace As %String, pHash As %String, ByRef pAllowed, Output pText As %String) As %Status [ Private ]
{
    Set pText = ""
    If (pNamespace = "") || (pHash = "") Quit $$$OK
    If '$Data(pAllowed(pNamespace)) Set pAllowed(pNamespace) = ..MayReadText(pNamespace)
    If 'pAllowed(pNamespace) Quit $$$OK
    Set tStatus = $$$OK
    Set tText = ..Text(pNamespace, pHash, .tStatus)
    If (tStatus '= "") && $$$ISERR(tStatus) {
        If $ListFind($ListFromString($System.Status.GetErrorCodes(tStatus)), ..#CODEWITHHELD) Quit $$$OK
        Quit tStatus
    }
    Set pText = ..Shape(tText)
    Quit $$$OK
}

/// <p>Whether the caller holds READ on the resources guarding <var>pNamespace</var>'s routines and
/// globals databases; 0 when either cannot be resolved.</p>
ClassMethod MayReadText(pNamespace As %String) As %Boolean [ Private ]
{
    Do ..Resources(pNamespace, .tRoutine, .tGlobal)
    If (tRoutine = "") || (tGlobal = "") Quit 0
    Set tPairs = $ListBuild($ListBuild(tRoutine, "READ"))
    If tGlobal '= tRoutine Set tPairs = tPairs _ $ListBuild($ListBuild(tGlobal, "READ"))
    Quit ''$ClassMethod(..GateClass(), "EvaluateRequired", tPairs, .tFailedPair)
}

/// <p>The resources guarding <var>pNamespace</var>'s routines and globals databases, through
/// <method>OcuPilot.Port.AtelierPort.DatabaseResources</method>; <code>""</code> for one that does not
/// resolve.</p>
ClassMethod Resources(pNamespace As %String, Output pRoutine As %String, Output pGlobal As %String) [ Private ]
{
    Set (pRoutine, pGlobal) = ""
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(pNamespace, .pRoutine, .pGlobal, .tMapped, .tResolved)
}

/// <p>The vendor's text of statement <var>pHash</var> in <var>pNamespace</var>, and its status in
/// <var>pStatus</var>. Its signature is pinned by <class>OcuPilot.Test.SqlActivityPort</class>.</p>
ClassMethod Text(pNamespace As %String, pHash As %String, Output pStatus As %Status) As %String [ Private ]
{
    Set pStatus = $$$OK
    Quit ##class(INFORMATION.SCHEMA.CURRENTSTATEMENTS).GetSQLStatement(pNamespace, pHash, .pStatus)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The 403 the gate answers, <code>PORT.ACCESSDENIED</code> with the pair in
/// <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>No script form: this port carries no write (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ""
}

/// <p>No script steps: this port carries no write (AD-59).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
}

}

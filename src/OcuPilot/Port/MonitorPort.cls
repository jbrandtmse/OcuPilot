/// <p>The port to the instance's own monitoring API, the business logic behind
/// <code>/api/monitor/alerts</code> (AD-1, AD-29). <b>This is the only product class that names
/// <code>SYS.Monitor.SAM.Sensors</code> or <code>%SYSTEM.Monitor</code></b>, and it names the
/// vendor's sensor class only through <parameter>SENSORCLASS</parameter>.</p>
/// <p><method>Invoke</method> is the one way in. It serves one endpoint,
/// <parameter>ENDPOINTALERTS</parameter>, of request type <parameter>REQUESTTYPE</parameter>: the
/// alerts.log entries newer than a caller-held tag. The vendor method is called in process, never
/// over HTTP.</p>
/// <p><b>The port's own gate is the only gate there is.</b> <code>/api/monitor</code> is configured
/// <code>authEnabled: 64</code> with an empty resource and answers 200 to an anonymous request, and
/// <code>%Api.Monitor.alerts</code> is a two-line pass-through with no privilege check of its own.
/// <parameter>PAIRS</parameter> is therefore evaluated in the calling process first, before any
/// argument is read and before any vendor call, so a denial reaches no vendor code (AD-29).</p>
/// <p><b>Tag mode is mandatory.</b> Every call seeds <code>%request.Data("tag",1)</code>, so the rows
/// this port answers are the ones after the cursor <b>its caller</b> holds rather than the ones after
/// an instance-wide cursor shared with every other scraper. An empty tag reads the whole file.</p>
/// <p><b>Tag mode does not stop the vendor advancing that cursor.</b> Measured on this build
/// (2026-09-18): every <code>Alerts()</code> call writes
/// <code>^IRIS.Temp.SAM("LastAlertSent")</code> in <code>%SYS</code> to the newest entry it reported
/// -- with a tag, with an empty tag, and with a tag the vendor matched. Nothing this port can pass
/// prevents it. It is a read-triggered vendor write outside the two shapes AD-7 names, and the
/// decision about it is DW-1116.</p>
/// <p><b>The vendor's signature is wrong about its own answer.</b> <code>Alerts()</code> is
/// declared <code>As %Stream.Object</code> and returns a scalar <code>%String</code> read from the
/// top of the file on every call, so a large alerts.log is a <code>&lt;MAXSTRING&gt;</code> the
/// caller can only catch. <parameter>MAXANSWERCHARS</parameter> bounds what this port will read and
/// a <code>Try</code>/<code>Catch</code> maps the throw; both answer
/// <code>MONITOR.TOOLARGE</code> rather than a truncated list.</p>
/// <p>The sensor class does not exist in the install namespace and is source-stripped in
/// <code>%SYS</code>, so the port enters <code>%SYS</code> by explicit save and restore (AD-16),
/// runs the vendor method behind fresh <code>%request</code>/<code>%response</code> stubs -- which
/// it hard-requires -- with device output captured, and reads its outcome from both the return
/// value and <code>%response.Status</code>.</p>
/// <p><b>Every refusal is a written reason</b> with a slug, a <code>MONITOR.*</code> code and a
/// sentence chosen here (AD-12, AD-39); the vendor's own text and anything it wrote to the device
/// go to <method>OcuPilot.Kernel.Fault.LogRaw</method> and nowhere else.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.MonitorPortFixture</class>):
/// <method>GateClass</method>, <method>SensorClass</method>, <method>SensorNamespace</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.MonitorPort Extends %RegisteredObject
{

/// <p>The vendor's monitoring sensor class, which answers the alerts.log entries.</p>
Parameter SENSORCLASS = "SYS.Monitor.SAM.Sensors";

/// <p>The pair set every call requires, comma-separated as <code>resource:permission</code>, in the
/// order the gate reports in (AD-8).</p>
/// <p><code>%Admin_Operate:USE</code> is the resource the classic page that shows alerts.log carries
/// (<code>/csp/sys/op</code>), and <code>%SYS_Portal.Resources</code> holds no custom assignment for
/// it. <code>%DB_IRISSYS:READ</code> is what entering <code>%SYS</code> costs: database READ is
/// routine-execution permission, so a principal without it cannot reach the sensor class at all
/// (AD-9). Both are a lower bound, established against a real least-privileged principal rather
/// than copied from the screen (AD-29).</p>
Parameter PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The class the pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The namespace the sensor class lives in. Entered by explicit save and restore, once per call
/// (AD-16).</p>
Parameter SENSORNAMESPACE = "%SYS";

/// <p>The endpoint answering the instance's alerts, and the vendor method name it dispatches
/// to.</p>
Parameter ENDPOINTALERTS = "Alerts";

/// <p>The one request type the endpoint serves.</p>
Parameter REQUESTTYPE = "LIST";

/// <p>The request key the vendor reads the caller's cursor from.</p>
Parameter TAGKEY = "tag";

/// <p>The response header the vendor writes the next cursor to.</p>
Parameter TAGHEADER = "ISC-SAM-LAST-ALERT-TAG";

/// <p>The query key carrying the row cap.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The largest answer this port will read. Above it the answer is refused rather than cut: a
/// silently truncated alerts list reads as a complete one.</p>
Parameter MAXANSWERCHARS As INTEGER = 1000000;

/// <p>The hard row ceiling. An answer this ceiling would cut is <b>refused</b>, for the reason
/// <parameter>MAXANSWERCHARS</parameter> refuses an oversized one: a silently cut alert list reads as
/// a complete one, and the next cursor the vendor hands back names the last row of the whole answer
/// rather than the last row the caller saw.</p>
/// <p>A caller's own cap below this ceiling is an ordinary cap and still truncates: that caller
/// asked for a bounded page and reads the truncation signal (AD-24). Only a cut this ceiling makes,
/// which no caller asked for, is a refusal.</p>
Parameter MAXENTRIES As INTEGER = 5000;

/// <p>The longest tag the port will forward. The vendor matches it against a line prefix, so a
/// value longer than a log line can match nothing.</p>
Parameter MAXTAGLENGTH As INTEGER = 512;

/// <p>The subsystem raw vendor text is logged under.</p>
Parameter LOGSUBSYSTEM = "monitorport";

/// <p>The vendor row key carrying an entry's text, renamed to <parameter>FIELDTEXT</parameter> on
/// the way out so the declared read's field names are OcuPilot's own.</p>
Parameter VENDORMESSAGEKEY = "message";

/// <p>The three field names a row answers with.</p>
Parameter FIELDTIME = "time";

Parameter FIELDSEVERITY = "severity";

Parameter FIELDTEXT = "text";

/// <p>The reason a caller short of the pair set is refused with.</p>
Parameter REASONDENIED = "This account may not read the instance's alerts.";

/// <p>The reason a request the port does not serve is refused with.</p>
Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

/// <p>The reason a malformed tag is refused with.</p>
Parameter REASONTAGSHAPE = "The alerts cursor is not a value this instance issued.";

/// <p>The reason a malformed row cap is refused with.</p>
Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The reason an answer past <parameter>MAXANSWERCHARS</parameter>, or one that raised
/// <code>&lt;MAXSTRING&gt;</code> on the way out of the vendor, is refused with.</p>
Parameter REASONTOOLARGE = "The instance's alert list is too large to read in one answer.";

/// <p>The reason any other vendor failure is refused with.</p>
Parameter REASONFAILED = "The monitoring API could not read this instance's alerts.";

/// <p>The class the pair set is evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The namespace the vendor call is issued in. Overridable so a fixture's own sensor class -- an
/// <code>OcuPilot.*</code> class, which is invisible from <code>%SYS</code> -- can be reached;
/// production never overrides it.</p>
ClassMethod SensorNamespace() As %String
{
    Quit ..#SENSORNAMESPACE
}

/// <p>The vendor class the call is issued to. Overridable so a fixture can answer the outcomes the
/// live instance cannot produce on demand -- a throw, a <code>&lt;MAXSTRING&gt;</code>, an
/// oversized answer -- and so the fixture's vendor-entry counter has a seam to hang on; production
/// never overrides it.</p>
ClassMethod SensorClass() As %String
{
    Quit ..#SENSORCLASS
}

/// <p><parameter>PAIRS</parameter> as the <code>%List</code> of two-element <code>%List</code>s the
/// gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Set tPairs = ""
    Set tDeclared = ..#PAIRS
    For tI = 1:1:$Length(tDeclared, ",") {
        Set tPair = $Piece(tDeclared, ",", tI)
        If tPair = "" Continue
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>.</p>
/// <p><var>pQuery</var> carries <code>tag</code> (optional: the cursor a previous answer returned,
/// and <code>""</code> for the whole file) and <code>maxRows</code> (optional, a whole number above
/// zero that bounds the rows). <var>pBody</var> is not read.</p>
/// <p>On success <var>pAnswer</var> is a <class>%DynamicArray</class> of rows carrying
/// <code>time</code>, <code>severity</code> and <code>text</code>, <var>pHttpStatus</var> is 200 and
/// <var>pTag</var> is the cursor to pass back on the next call -- the vendor's own
/// <parameter>TAGHEADER</parameter>, or <code>""</code> when it wrote none.</p>
/// <p>Otherwise an error status is returned with <var>pAnswer</var> empty, <var>pHttpStatus</var>
/// the status to answer with and <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code>
/// with <code>detail.failedPair</code> before anything else is read, 501
/// <code>PORT.NOTIMPLEMENTED</code>, 400 <code>PORT.VALIDATION</code> for a malformed argument, 503
/// <code>MONITOR.TOOLARGE</code> for an answer past <parameter>MAXANSWERCHARS</parameter> or a
/// <code>&lt;MAXSTRING&gt;</code>, and 503 <code>MONITOR.FAILED</code> for any other vendor
/// failure. No exception escapes.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace,
/// <code>%request</code>, <code>%response</code> and <code>%session</code> are unchanged on
/// return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pAnswer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTag As %String) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pTag = ""
    Try {
        ; AD-29: the declared pairs decide before an argument is read and before the vendor is
        ; reached, because the vendor's own web application answers anonymously and its handler
        ; checks nothing.
        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "EvaluatePairs", ..Pairs(), .tFailedPair) {
            Set tDetail = ""
            If tFailedPair '= "" {
                Set tDetail = {}
                Do tDetail.%Set("failedPair", tFailedPair)
            }
            Set tSC = ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, ..#REASONDENIED, .pHttpStatus, .pFault, tDetail)
            Quit
        }

        If (pType '= ..#REQUESTTYPE) || (pEndpoint '= ..#ENDPOINTALERTS) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }

        Set tTag = $Get(pQuery(..#TAGKEY))
        If '..TagShapeOk(tTag) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTAGSHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Get(pQuery(..#MAXROWSKEY))
        If (tMax '= "") && '$Match(tMax, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }

        Set tSC = ..Alerts(tTag, +tMax, .pAnswer, .pHttpStatus, .pFault, .pTag)
    } Catch ex {
        Set pAnswer = ""
        Set pTag = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pTag</var> is a cursor the port will forward: at most
/// <parameter>MAXTAGLENGTH</parameter> characters and carrying no control character.
/// <code>""</code> is sound and means the whole file.</p>
ClassMethod TagShapeOk(pTag As %String) As %Boolean
{
    If pTag = "" Quit 1
    If $Length(pTag) > ..#MAXTAGLENGTH Quit 0
    Quit '$Locate(pTag, "[\x00-\x1F\x7F]")
}

/// <p>The <parameter>ENDPOINTALERTS</parameter> rows newer than <var>pTag</var>, at most
/// <var>pMax</var> of them when it is above zero and never more than
/// <parameter>MAXENTRIES</parameter>.</p>
ClassMethod Alerts(pTag As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTagOut As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = ""
    Set pTagOut = ""
    Try {
        Set tSC = ..Call(pTag, .tAnswer, .tNextTag, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Rows(tAnswer, pMax, .tRows, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pRows = tRows
        Set pTagOut = tNextTag
        Set pHttpStatus = 200
    } Catch ex {
        Set pRows = ""
        Set pTagOut = ""
        Set tSC = ..Fail("the alert read failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Call the vendor sensor with <var>pTag</var> as its cursor and answer its text as
/// <var>pAnswer</var> and its next cursor as <var>pNextTag</var>.</p>
/// <p>The call runs in <parameter>SENSORNAMESPACE</parameter>, entered by explicit save and restore,
/// behind <code>New</code>ed <code>%request</code>, <code>%response</code> and <code>%session</code>
/// with fresh stubs and the device captured, so neither the caller's CSP objects nor its response
/// device is read or written. The tag is seeded unconditionally: the no-tag path writes an
/// instance-wide cursor (AD-7).</p>
ClassMethod Call(pTag As %String, Output pAnswer As %String, Output pNextTag As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set pNextTag = ""
    Set tAnswer = ""
    Set tNextTag = ""
    Set tHttp = 0
    Set tCaptured = ""
    Set tCapturing = 0
    Set tTooLarge = 0
    Set tCallSC = $$$OK
    Set tOrigNS = $Namespace
    New %request, %response, %session
    Try {
        Set $Namespace = ..SensorNamespace()
        Set %request = ##class(%CSP.Request).%New()
        Set %response = ##class(%CSP.Response).%New()
        ; Tag mode, always: the vendor reads this key's presence, not its value, to decide whether
        ; to advance the instance-wide cursor. An empty value reads the whole file and advances
        ; nothing.
        Set %request.Data(..#TAGKEY, 1) = pTag
        Set tCallSC = $$BeginCapture^%SYS.Capture(.tCookie)
        If $$$ISOK(tCallSC) {
            Set tCapturing = 1
            Set tAnswer = $ClassMethod(..SensorClass(), ..#ENDPOINTALERTS)
        }
    } Catch exCall {
        Set tAnswer = ""
        Set tCallSC = exCall.AsStatus()
        If exCall.Name = "<MAXSTRING>" Set tTooLarge = 1
    }
    If tCapturing {
        Try {
            Kill tLines
            Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
            If $IsObject($Get(tLines)) {
                Set tIterator = tLines.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tLine) {
                    Set tCaptured = tCaptured _ $Select(tCaptured = "": "", 1: " ") _ tLine
                }
            }
        } Catch exEnd {
            If $$$ISOK(tCallSC) Set tCallSC = exEnd.AsStatus()
        }
    }
    Try {
        If $IsObject($Get(%response)) {
            Set tHttp = +%response.Status
            Set tNextTag = $Get(%response.Headers(..#TAGHEADER))
        }
    } Catch exRead {
        Set tHttp = 0
    }
    Set $Namespace = tOrigNS
    Set tSC = ..Outcome(tCallSC, tAnswer, tHttp, tCaptured, tTooLarge, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) {
        Set pAnswer = tAnswer
        Set pNextTag = tNextTag
    }
    Quit tSC
}

/// <p>What one vendor call's outcome means.</p>
/// <p>A call that did not raise, under a 2xx status, answering a string no longer than
/// <parameter>MAXANSWERCHARS</parameter>, is success. A <code>&lt;MAXSTRING&gt;</code> or an
/// oversized answer is <code>MONITOR.TOOLARGE</code>; anything else is
/// <code>MONITOR.FAILED</code>. The vendor's own status and captured output are logged on every
/// error path and never put on the wire (AD-39).</p>
ClassMethod Outcome(pCallSC As %Status, pAnswer As %String, pHttp As %Integer, pCaptured As %String, pTooLarge As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tOversized = pTooLarge
    If 'tOversized && $$$ISOK(pCallSC) && ($Length(pAnswer) > ..#MAXANSWERCHARS) Set tOversized = 1
    If 'tOversized && $$$ISOK(pCallSC) && (pHttp >= 200) && (pHttp < 300) {
        Set pHttpStatus = pHttp
        Quit $$$OK
    }
    Set tRaw = ..#ENDPOINTALERTS _ " answered HTTP " _ pHttp _ " with " _ $Length(pAnswer) _ " characters"
    If $$$ISERR(pCallSC) Set tRaw = tRaw _ "; " _ $System.Status.GetErrorText(pCallSC)
    If pCaptured '= "" Set tRaw = tRaw _ "; " _ pCaptured
    Set tRawSC = $$$ERROR($$$GeneralError, tRaw)
    If tOversized {
        Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#MONITORTOOLARGE, ..#REASONTOOLARGE, .pHttpStatus, .pFault)
    } Else {
        Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#MONITORFAILED, ..#REASONFAILED, .pHttpStatus, .pFault)
    }
    Do ..LogFault(..#ENDPOINTALERTS _ " was refused", tRawSC, pFault.code)
    Quit tSC
}

/// <p><var>pAnswer</var>, the vendor's JSON text, as rows carrying
/// <parameter>FIELDTIME</parameter>, <parameter>FIELDSEVERITY</parameter> and
/// <parameter>FIELDTEXT</parameter> -- the vendor's <parameter>VENDORMESSAGEKEY</parameter> renamed,
/// so the declared read's field names are OcuPilot's own.</p>
/// <p>At most <var>pMax</var> rows when it is above zero. An answer that
/// <parameter>MAXENTRIES</parameter> rather than <var>pMax</var> would cut is refused
/// <code>MONITOR.TOOLARGE</code>. Text that is not a JSON array is <code>MONITOR.FAILED</code>; an
/// element that is not an object is skipped.</p>
ClassMethod Rows(pAnswer As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tParsed = ""
    Try {
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pAnswer)
    } Catch exParse {
        Set tParsed = ""
    }
    If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicArray") {
        Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#MONITORFAILED, ..#REASONFAILED, .pHttpStatus, .pFault)
        Do ..LogFault(..#ENDPOINTALERTS _ " answered text that is not a JSON array", $$$ERROR($$$GeneralError, "first 200 characters: " _ $Extract(pAnswer, 1, 200)), pFault.code)
        Quit tSC
    }
    ; The hard ceiling refuses; a caller's own smaller cap truncates, because that caller asked for
    ; a bounded page and reads the truncation signal (AD-24).
    If (tParsed.%Size() > ..#MAXENTRIES) && ((pMax <= 0) || (pMax >= ..#MAXENTRIES)) {
        Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#MONITORTOOLARGE, ..#REASONTOOLARGE, .pHttpStatus, .pFault)
        Do ..LogFault(..#ENDPOINTALERTS _ " answered more rows than the port will read", $$$ERROR($$$GeneralError, tParsed.%Size() _ " rows against a ceiling of " _ ..#MAXENTRIES), pFault.code)
        Quit tSC
    }
    Set tCeiling = ..#MAXENTRIES
    If (pMax > 0) && (pMax < tCeiling) Set tCeiling = pMax
    Set tRows = []
    Set tIterator = tParsed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tRows.%Size() >= tCeiling Quit
        If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") Continue
        Set tRow = {}
        Do tRow.%Set(..#FIELDTIME, ..StringOf(tEntry, ..#FIELDTIME))
        Do tRow.%Set(..#FIELDSEVERITY, ..StringOf(tEntry, ..#FIELDSEVERITY))
        Do tRow.%Set(..#FIELDTEXT, ..StringOf(tEntry, ..#VENDORMESSAGEKEY))
        Do tRows.%Push(tRow)
    }
    Set pRows = tRows
    Quit $$$OK
}

/// <p><var>pObject</var>'s <var>pKey</var> as text: a JSON string as itself, a JSON number as its
/// own spelling, and anything else as <code>""</code>. The vendor quotes its severity, but the
/// signature does not promise to.</p>
ClassMethod StringOf(pObject As %DynamicObject, pKey As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pKey)
    If tType = "string" Quit pObject.%Get(pKey)
    If tType = "number" Quit "" _ pObject.%Get(pKey)
    Quit ""
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
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

}

/// <p>The one caller of a harvested handler body (AD-23). A body is a class method of a class that
/// extends <class>OcuPilot.Port.Harvest.Handler</class>; it answers only through
/// <method>OcuPilot.Port.Harvest.Handler.RenderResponseBody</method>, which records the render on a
/// stub response. <method>Invoke</method> gates the call, runs the body, and turns the one recorded
/// render into the port convention: a result, or a fault built by
/// <class>OcuPilot.Kernel.Fault</class> (AD-12, AD-39).</p>
/// <p>The port calls the body in the caller's process, behind stub <code>%request</code>,
/// <code>%response</code> and <code>%session</code>, with the body's device output captured and
/// discarded unless the handler takes it (AD-1, AD-61).</p>
Class OcuPilot.Port.HarvestPort Extends %RegisteredObject
{

/// <p>The class the caller's pair set is evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The class a harvested handler must extend.</p>
Parameter HANDLERBASE = "OcuPilot.Port.Harvest.Handler";

/// <p>The response stub class.</p>
Parameter RESPONSECLASS = "OcuPilot.Port.Harvest.Response";

/// <p>The request stub a body that reads a JSON body is handed.</p>
Parameter REQUESTCLASS = "OcuPilot.Port.AtelierRequest";

/// <p>The log subsystem a body's fault is logged under.</p>
Parameter LOGSUBSYSTEM = "harvestport";

/// <p>The class the pair set is evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>Run the class method <var>pMethod</var> of <var>pHandler</var> with <var>pArgs</var>, and
/// answer what it rendered.</p>
/// <p>The steps, in order: the gate, then the handler check, then the stubs, then the call with
/// output captured, then <code>$NAMESPACE</code> restored, then the outcome.</p>
/// <ul>
/// <li><b>Gate.</b> <var>pPairs</var> is the caller's declared pair set, a list of
/// <code>$ListBuild(resource, permission)</code> pairs, evaluated through
/// <method>GateClass</method>'s <code>EvaluateRequired</code>; an empty set fails closed. A refusal is
/// 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code> when a pair failed, and is
/// not logged. The body does not run.</li>
/// <li><b>Handler.</b> <var>pHandler</var> must extend <parameter>HANDLERBASE</parameter> and define
/// <var>pMethod</var> as a compiled public class method; otherwise the answer is 500
/// <code>INTERNAL</code>, logged, and nothing runs.</li>
/// <li><b>Stubs.</b> <var>pQuery</var>'s members become <code>%request.Data</code>; a non-empty
/// <var>pBody</var> (a JSON text or a dynamic object) becomes the request's content and the method
/// <code>POST</code>, otherwise the method is <code>GET</code>.</li>
/// <li><b>Outcome.</b> Exactly one render is answered: an OK status gives <var>pResult</var> as the
/// render's result part (<code>{}</code> when it passed none) and 200; any other status gives the
/// fault <class>OcuPilot.Kernel.Fault</class>.<method>Outcome</method> builds, with 403 asked for when
/// the raw text holds <code>&lt;PROTECT&gt;</code>, the HTTP status its code names (403
/// <code>PORT.ACCESSDENIED</code>, 404 <code>PORT.NOTFOUND</code>, 409 <code>PORT.CONFLICT</code>, 400
/// <code>PORT.VALIDATION</code>, 501 <code>PORT.NOTIMPLEMENTED</code>, otherwise 500), and the raw
/// text logged once. No render or several, or an exception, is 500 <code>INTERNAL</code>, logged.
/// The body's device output is discarded unless its handler takes it (<method>OcuPilot.Port.Harvest.Handler.OnCaptured</method>,
/// called after an OK render with the namespace restored; AD-39's eighth exception).</li>
/// </ul>
/// <p>The answer follows the port convention. <var>pFault</var> is
/// <code>{error, reason, code[, detail]}</code> and is empty on success; the returned status is an
/// error whenever <var>pFault</var> is set. <var>pConsole</var> is an OK render's message part, the body's
/// own text unnormalized, and <code>""</code> on every other answer; it reaches no wire, model or log
/// unless an AD-39 exception names it.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9). The caller's
/// <code>%request</code>, <code>%response</code>, <code>%session</code>, device and
/// <code>$NAMESPACE</code> are unchanged on return, on every path; no <code>OcuPilot.*</code> class
/// is called while <code>$NAMESPACE</code> differs from the caller's, except by the body itself.</p>
ClassMethod Invoke(pHandler As %String, pMethod As %String, pPairs As %List, ByRef pQuery, pBody = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pConsole As %DynamicArray, pArgs...) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pConsole = ""
    Set tOrigNS = $NAMESPACE
    Set tDevice = $IO
    Set tAnswered = 0
    Set tCapturing = 0
    Set tCaught = ""
    Set tStub = ""
    New %request, %response, %session
    Try {
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: an empty set fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", $Get(pPairs), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Set tAnswered = 1
            Quit
        }
        If '..IsHandler($Get(pHandler), $Get(pMethod)) {
            Set tSC = ..Fail($Get(pHandler) _ "." _ $Get(pMethod) _ " is not a harvested handler method", $$$ERROR($$$GeneralError, "not a harvested handler method"), .pHttpStatus, .pFault)
            Set tAnswered = 1
            Quit
        }
        Set tBodyGiven = $IsObject(pBody) || ($Get(pBody) '= "")
        If tBodyGiven {
            Set %request = $ClassMethod(..#REQUESTCLASS, "%New")
            Set tBodySC = %request.SetJsonBody(pBody)
            If $$$ISERR(tBodySC) {
                Set tSC = ..Fail("the request body could not be set", tBodySC, .pHttpStatus, .pFault)
                Set tAnswered = 1
                Quit
            }
        } Else {
            Set %request = ##class(%CSP.Request).%New()
        }
        Set %request.Method = $Select(tBodyGiven: "POST", 1: "GET")
        Set tKey = ""
        For {
            Set tKey = $Order(pQuery(tKey))
            If tKey = "" Quit
            Set %request.Data(tKey, 1) = pQuery(tKey)
        }
        Set tStub = $ClassMethod(..#RESPONSECLASS, "%New")
        Set %response = tStub
        Set %session = ""
        Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
        If $$$ISERR(tCaptureSC) {
            Set tSC = ..Fail("the body's output could not be captured", tCaptureSC, .pHttpStatus, .pFault)
            Set tAnswered = 1
            Quit
        }
        Set tCapturing = 1
        Do $ClassMethod(pHandler, pMethod, pArgs...)
    } Catch ex {
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tCapturing {
        Try {
            Set tEndSC = $$EndCapture^%SYS.Capture(tCookie, .tLines)
        } Catch exEnd {
            If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        }
        If $IO '= tDevice Use tDevice
    }
    If tAnswered Quit tSC
    Try {
        If $IsObject(tCaught) {
            Set tSC = ..Fail($Get(pHandler) _ "." _ $Get(pMethod) _ " raised an exception", tCaught.AsStatus(), .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..Answer(pHandler, pMethod, tStub, .pResult, .pHttpStatus, .pFault, .pConsole)
            If $$$ISOK(tSC) && $IsObject(pResult) {
                Set tCapturedSC = $ClassMethod(pHandler, "OnCaptured", $Select($IsObject($Get(tLines)): tLines, 1: []), pResult)
                If $$$ISERR(tCapturedSC) {
                    Set pResult = ""
                    Set tSC = ..Fail($Get(pHandler) _ "." _ $Get(pMethod) _ " could not take its captured output", tCapturedSC, .pHttpStatus, .pFault)
                }
            }
        }
    } Catch exAnswer {
        Set pResult = ""
        Set tSC = ..Fail("the body's answer could not be read", exAnswer.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pHandler</var> is a compiled class that extends <parameter>HANDLERBASE</parameter>
/// and has <var>pMethod</var> as a public class method defined below the base, so neither the base's
/// own render nor a helper it inherits runs as a body.</p>
ClassMethod IsHandler(pHandler As %String, pMethod As %String) As %Boolean [ Private ]
{
    If '$Match(pHandler, "^[A-Za-z%][A-Za-z0-9%.]*$") Quit 0
    If '$Match(pMethod, "^[A-Za-z][A-Za-z0-9]*$") Quit 0
    If '##class(%Dictionary.CompiledClass).%ExistsId(pHandler) Quit 0
    If '$ClassMethod(pHandler, "%Extends", ..#HANDLERBASE) Quit 0
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(pHandler _ "||" _ pMethod)
    If '$IsObject(tMethod) || 'tMethod.ClassMethod || tMethod.Private Quit 0
    If tMethod.Origin = ..#HANDLERBASE Quit 0
    Quit $ClassMethod(tMethod.Origin, "%Extends", ..#HANDLERBASE)
}

/// <p>The answer for the render <var>pStub</var> recorded, once the namespace is the caller's.</p>
ClassMethod Answer(pHandler As %String, pMethod As %String, pStub As %RegisteredObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pConsole As %DynamicArray) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = pHandler _ "." _ pMethod
    Set tRenders = pStub.Renders
    If tRenders '= 1 {
        Set tText = tName _ " rendered " _ tRenders _ " times, not once"
        Quit ..Fail(tText, $$$ERROR($$$GeneralError, tText), .pHttpStatus, .pFault)
    }
    Set tStatus = pStub.RenderStatus
    If $$$ISOK(tStatus) {
        Set pConsole = pStub.MsgPart
        Set pResult = $Select($IsObject(pStub.ResPart): pStub.ResPart, 1: {})
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tAsk = $Select($System.Status.GetErrorText(tStatus) [ "<PROTECT>": 403, 1: 0)
    Set tOutcomeSC = ##class(OcuPilot.Kernel.Fault).Outcome(tAsk, tStatus, .pFault, .tDetail)
    Set pHttpStatus = ..HttpStatusFor(pFault.%Get("code"))
    Do ..LogFault(tName _ " rendered a failure", tStatus, pFault.%Get("code"))
    Quit $$$ERROR($$$GeneralError, pFault.%Get("code") _ ": " _ pFault.%Get("reason"))
}

/// <p>The HTTP status a fault's machine code is answered with.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer [ Private ]
{
    If pCode = ##class(OcuPilot.Api.Error).#PORTACCESSDENIED Quit 403
    If pCode = ##class(OcuPilot.Api.Error).#PORTNOTFOUND Quit 404
    If pCode = ##class(OcuPilot.Api.Error).#PORTCONFLICT Quit 409
    If pCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION Quit 400
    If pCode = ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED Quit 501
    Quit 500
}

/// <p><code>""</code>: no harvested body this port runs is a write, so no request type has a
/// script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ""
}

/// <p>No step: no harvested body this port runs is a write (AD-59).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
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

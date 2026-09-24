/// <p>Test connection's one provider call, made in a short-lived child job the request process
/// waits for against a wall-clock bound (AD-42). A per-call timeout cannot bound a foreground
/// request, because <code>%Net.HttpRequest.Timeout</code> re-arms on every socket read; with the
/// call in a child, the request process owns the clock and answers before the Web Gateway's
/// <code>Server_Response_Timeout</code> would.</p>
/// <p><b>The bound</b> is <method>BoundSeconds</method> of <method>GatewaySeconds</method>:
/// <code>g - min(MARGINSECONDS, g\2)</code>, with <code>g</code> the gateway's timeout as
/// <method>OcuPilot.Install.Installer.GatewayResponseTimeout</method> reads it, or
/// <parameter>UNREADGATEWAYSECONDS</parameter> when it cannot be read.</p>
/// <p><b>The child</b> (<method>Child</method>) inherits the caller's <code>$USERNAME</code> and
/// <code>$ROLES</code>, calls <method>OcuPilot.Port.ProviderPort.InvokeDraft</method> -- the same
/// port, TLS configuration, address judgement and adapter a test uses in process -- and signals its
/// result back. It writes nothing: the verification write, the change record and the response stay
/// in the request process. A key the request body carries crosses by <code>$System.Event</code>
/// message, straight into the child's <class>%DynamicObject</class>; it is never a
/// <code>JOB</code> argument, a global, a log line or part of the reply.</p>
/// <p><b>An abandoned child</b> is not stopped. Its result carries a nonce the next
/// <method>Call</method> in that process does not match, and each <method>Call</method> clears
/// the process's event queue before it spawns, so a late answer is discarded and can verify
/// nothing. A provider that drips its reply keeps its child alive until the child's own per-read
/// timeout, one child per press.</p>
/// <p><b>Caller contract:</b> no <code>New $ROLES</code> escalation is in effect in any frame of the
/// caller's stack (AD-9), because a job keeps the roles it was spawned with.</p>
Class OcuPilot.Kernel.Provider.TestCall Extends %RegisteredObject
{

/// <p>The gateway timeout <method>GatewaySeconds</method> answers when the installer's read
/// answers nothing usable: the stock <code>Server_Response_Timeout</code>.</p>
Parameter UNREADGATEWAYSECONDS As %Integer = 60;

/// <p>The most <method>BoundSeconds</method> takes off the gateway's timeout, for the spawn and
/// the work after the call: the verification write, the re-read, the audit row and the
/// response.</p>
Parameter MARGINSECONDS As %Integer = 10;

/// <p>Seconds <method>Call</method> waits for the spawn to be accepted.</p>
Parameter SPAWNTIMEOUT As %Integer = 5;

/// <p>Seconds <method>Child</method> waits for a body key after it signalled ready.</p>
Parameter KEYWAITSECONDS As %Integer = 10;

/// <p>The subsystem the child's failures are logged under.</p>
Parameter LOGSUBSYSTEM = "providerport";

/// <p>The most characters of the reply text the child signals back. Far above what Test
/// connection shows (<parameter>OcuPilot.Api.Definitions.TESTREPLYMAX</parameter>), so the
/// caller still sees whether the reply was longer than that.</p>
Parameter REPLYSIGNALMAX As %Integer = 32000;

/// <p>The class <method>GatewaySeconds</method> reads the gateway's timeout through. A seam, so a
/// test can make the read answer nothing or another value; production never overrides it.</p>
ClassMethod GatewayClass() As %String
{
    Quit "OcuPilot.Install.Installer"
}

/// <p>The gateway's <code>Server_Response_Timeout</code> as a positive whole number of seconds,
/// with <var>pSource</var> where it was read. A read that fails, answers nothing, or answers
/// anything but a positive whole number answers <parameter>UNREADGATEWAYSECONDS</parameter> with
/// <var>pSource</var> <code>unread</code>. Never an error.</p>
ClassMethod GatewaySeconds(Output pSource As %String) As %Integer
{
    Set pSource = "unread"
    Set tSeconds = ..#UNREADGATEWAYSECONDS
    Set tOrigNS = $Namespace
    Try {
        Set tTimeout = ""
        Set tReadSource = ""
        Set tSC = $ClassMethod(..GatewayClass(), "GatewayResponseTimeout", .tTimeout, .tReadSource)
        If $Namespace '= tOrigNS Set $Namespace = tOrigNS
        If $$$ISERR(tSC) Quit
        If '$Match(tTimeout, "^[0-9]+$") Quit
        If +tTimeout < 1 Quit
        Set tSeconds = +tTimeout
        Set pSource = tReadSource
    } Catch ex {
        If $Namespace '= tOrigNS Set $Namespace = tOrigNS
        Set tSeconds = ..#UNREADGATEWAYSECONDS
        Set pSource = "unread"
    }
    Quit tSeconds
}

/// <p>The wall-clock bound, in seconds, for a gateway timeout of <var>pGateway</var> seconds:
/// <code>g - min(MARGINSECONDS, g\2)</code>, where <code>g</code> is <var>pGateway</var> as a whole
/// number, or <parameter>UNREADGATEWAYSECONDS</parameter> when it is not a positive number. At
/// least 1. Pure.</p>
ClassMethod BoundSeconds(pGateway As %String = "") As %Integer
{
    Set tGateway = ..#UNREADGATEWAYSECONDS
    If $IsValidNum(pGateway) && (+pGateway > 0) Set tGateway = +pGateway \ 1
    Set tMargin = tGateway \ 2
    If tMargin > ..#MARGINSECONDS Set tMargin = ..#MARGINSECONDS
    Set tBound = tGateway - tMargin
    If tBound < 1 Set tBound = 1
    Quit tBound
}

/// <p>Make the one call <var>pValues</var> and <var>pMessages</var> describe through
/// <var>pPortClass</var>'s <code>InvokeDraft</code> in a child job, and wait for it for at most
/// <var>pBound</var> seconds of wall clock, counted from entry.</p>
/// <p>On an answer, <var>pResponse</var> carries the reply's text, stop reason, HTTP status and
/// latency, and <var>pHttpStatus</var> / <var>pFault</var> are the port's own. At the deadline,
/// <var>pFault</var> is <code>""</code> and <var>pTimedOut</var> is 1. A spawn that is not accepted
/// answers 502 <code>PROVIDER.TRANSPORT</code>, logged, with no call made, and so does a child that
/// signals it failed, as soon as it does. <var>pWaited</var> is the
/// whole seconds waited, rounded, on every path.</p>
/// <p><var>pValues</var> is not added to: the port fills its keys in the child's copy.</p>
ClassMethod Call(pPortClass As %String, ByRef pValues, ByRef pMessages, pBound As %Numeric, Output pResponse As OcuPilot.Kernel.Provider.Response, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWaited As %Integer, Output pTimedOut As %Boolean)
{
    Set pResponse = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pWaited = 0
    Set pTimedOut = 0
    Set tStarted = $ZHorolog
    Set tDeadline = tStarted + pBound
    Try {
        Do $System.Event.Clear($Job)
        Set tNonce = $System.Util.CreateGUID()
        Set tNeedsKey = ($Get(pValues("keySource")) = ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCEBODY)
        Set tValuesJson = ..ValuesJson(.pValues)
        Set tMessagesJson = ..MessagesJson(.pMessages)
        If '..Spawn(tNonce, pPortClass, tValuesJson, tNeedsKey, tMessagesJson, .tChild) {
            Do ..Transport("the Test connection call could not be started", $$$ERROR($$$GeneralError, "the child job was not accepted within " _ ..#SPAWNTIMEOUT _ " seconds"), .pHttpStatus, .pFault)
            Quit
        }
        Set tReady = ..Await(tNonce, "ready", tDeadline, .tPayload)
        If tReady = "refused" {
            Do ..Transport("the Test connection child did not run as its caller", $$$ERROR($$$GeneralError, "the child refused to run as another user"), .pHttpStatus, .pFault)
            Quit
        }
        If tReady = "failed" {
            Do ##class(OcuPilot.Kernel.Provider.Base).Fault(##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "", "", .pFault, .pHttpStatus)
            Quit
        }
        If tReady '= "ready" {
            Set pTimedOut = 1
            Quit
        }
        If tNeedsKey {
            ; The body object is held, never its member: the key is read inside the signal's
            ; argument and never bound to a local (AD-35, AD-48).
            Set tKeyBody = $Get(pValues("keyBody"))
            If $IsObject(tKeyBody) {
                Do $System.Event.Signal(tChild, tKeyBody.%Get($Get(pValues("keyField"))))
            } Else {
                Do $System.Event.Signal(tChild, "")
            }
            Set tKeyBody = ""
        }
        Set tKind = ..Await(tNonce, "result", tDeadline, .tPayload)
        If tKind = "failed" {
            Do ##class(OcuPilot.Kernel.Provider.Base).Fault(##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "", "", .pFault, .pHttpStatus)
            Quit
        }
        If tKind '= "result" {
            Set pTimedOut = 1
            Quit
        }
        Do ..Rebuild(tPayload, .pResponse, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResponse = ""
        Do ..Transport("the Test connection call failed in the request process", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Set tWaited = $ZHorolog - tStarted
    If tWaited < 0 Set tWaited = 0
    Set pWaited = $Normalize(tWaited, 0)
}

/// <p>Spawn <method>Child</method> for this process, and answer whether the <code>JOB</code> was
/// accepted within <parameter>SPAWNTIMEOUT</parameter> seconds; <var>pChild</var> is the child's
/// process id when it was, <code>""</code> otherwise. The one <code>JOB</code> in this class.</p>
ClassMethod Spawn(pNonce As %String, pPortClass As %String, pValuesJson As %String, pNeedsKey As %Boolean, pMessagesJson As %String, Output pChild As %Integer) As %Boolean
{
    Set pChild = ""
    Job ##class(OcuPilot.Kernel.Provider.TestCall).Child($Job, pNonce, $Username, pPortClass, pValuesJson, pNeedsKey, pMessagesJson):($Namespace):..#SPAWNTIMEOUT
    If '$Test Quit 0
    Set pChild = $ZChild
    Quit 1
}

/// <p>Wait until <var>pDeadline</var> (<code>$ZHorolog</code> seconds) for a message on this
/// process's queue carrying <var>pNonce</var> and the kind <var>pWanted</var>, or the kind
/// <code>refused</code> or <code>failed</code>; answer the kind received, or <code>""</code> at the deadline.
/// <var>pPayload</var> is the message's third element. A message with any other nonce, or one that
/// is not a list, is discarded.</p>
ClassMethod Await(pNonce As %String, pWanted As %String, pDeadline As %Numeric, Output pPayload As %String) As %String [ Private ]
{
    Set pPayload = ""
    Set tKind = ""
    For {
        Set tRemaining = pDeadline - $ZHorolog
        If tRemaining <= 0 Quit
        Set tMessage = $System.Event.WaitMsg("", tRemaining)
        If $ListGet(tMessage, 1) '= 1 Continue
        Set tBody = $ListGet(tMessage, 2)
        If '$ListValid(tBody) Continue
        If $ListGet(tBody, 1) '= pNonce Continue
        Set tReceived = $ListGet(tBody, 2)
        If (tReceived '= pWanted) && (tReceived '= "refused") && (tReceived '= "failed") Continue
        Set tKind = tReceived
        Set pPayload = $ListGet(tBody, 3)
        Quit
    }
    Quit tKind
}

/// <p>Rebuild the child's signalled result <var>pPayload</var> -- JSON text -- into the port's
/// three outputs.</p>
ClassMethod Rebuild(pPayload As %String, Output pResponse As OcuPilot.Kernel.Provider.Response, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) [ Private ]
{
    Set tResult = ##class(%DynamicAbstractObject).%FromJSON(pPayload)
    Set pResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Set pResponse.Text = tResult.%Get("text")
    Set pResponse.StopReason = tResult.%Get("stopReason")
    Set pResponse.HttpStatus = +tResult.%Get("responseStatus")
    Set pResponse.LatencyMs = +tResult.%Get("latencyMs")
    Set pHttpStatus = +tResult.%Get("httpStatus")
    Set pFault = ""
    If $IsObject(tResult.%Get("fault")) Set pFault = tResult.%Get("fault")
}

/// <p>The child job's entry point, spawned by <method>Call</method> and never called directly.
/// <var>pParent</var> is the request process, <var>pNonce</var> the tag its messages carry,
/// <var>pUser</var> the user it must be running as, <var>pValuesJson</var> and
/// <var>pMessagesJson</var> the call's values and messages (<method>ValuesJson</method>,
/// <method>MessagesJson</method>), and <var>pNeedsKey</var> 1 when the key arrives by message.</p>
/// <p>It refuses, signalling <code>refused</code>, when <code>$Username</code> is not
/// <var>pUser</var>. Otherwise it clears its own queue, signals <code>ready</code>, takes the key
/// when one is due, calls <code>InvokeDraft</code> and signals <code>result</code>. It never
/// throws; a failure signals <code>failed</code>, so the request answers at once rather than at its
/// bound, and is logged through <method>OcuPilot.Kernel.Fault.LogRaw</method>.</p>
ClassMethod Child(pParent As %Integer, pNonce As %String, pUser As %String, pPortClass As %String, pValuesJson As %String, pNeedsKey As %Boolean = 0, pMessagesJson As %String = "")
{
    Set tKeyBody = ""
    Try {
        If $Username '= pUser {
            Do $System.Event.Signal(pParent, $ListBuild(pNonce, "refused"))
            Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, "the Test connection child did not start as its caller", $$$ERROR($$$GeneralError, "user differs from the start"), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
            Quit
        }
        Do $System.Event.Clear($Job)
        Kill tValues
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pValuesJson)
        Set tIterator = tParsed.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            Set tValues(tName) = tValue
        }
        Kill tMessages
        Set tMessages = 0
        If pMessagesJson '= "" {
            Set tMessageArray = ##class(%DynamicAbstractObject).%FromJSON(pMessagesJson)
            Set tIterator = tMessageArray.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tMessage) {
                Set tMessages = tMessages + 1
                Set tMessages(tMessages, "role") = tMessage.%Get("role")
                Set tMessages(tMessages, "content") = tMessage.%Get("content")
            }
        }
        Do $System.Event.Signal(pParent, $ListBuild(pNonce, "ready"))
        If pNeedsKey {
            ; The key is taken off the message straight into the object's member (AD-35, AD-48).
            Set tKeyBody = {}
            Do tKeyBody.%Set($Get(tValues("keyField")), $ListGet($System.Event.WaitMsg("", ..#KEYWAITSECONDS), 2), "string")
            Set tValues("keyBody") = tKeyBody
        }
        Kill tTools
        Do $ClassMethod(pPortClass, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
        Kill tValues("keyBody")
        Set tKeyBody = ""
        Set tOut = {}
        Do tOut.%Set("httpStatus", +$Get(tHttpStatus), "number")
        If $IsObject($Get(tResponse)) {
            Do tOut.%Set("text", $Extract(tResponse.Text, 1, ..#REPLYSIGNALMAX), "string")
            Do tOut.%Set("stopReason", tResponse.StopReason, "string")
            Do tOut.%Set("responseStatus", +tResponse.HttpStatus, "number")
            Do tOut.%Set("latencyMs", +tResponse.LatencyMs, "number")
        }
        If $IsObject($Get(tFault)) Do tOut.%Set("fault", tFault)
        Do $System.Event.Signal(pParent, $ListBuild(pNonce, "result", tOut.%ToJSON()))
    } Catch ex {
        Set tKeyBody = ""
        Kill tValues
        Do $System.Event.Signal(pParent, $ListBuild(pNonce, "failed"))
        Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, "the Test connection child failed", ex.AsStatus(), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
    }
}

/// <p><var>pValues</var>'s top-level nodes as a JSON object of strings, for the child's
/// <code>JOB</code> argument. <code>keyBody</code> is left out: it is the request body, and the
/// key it carries crosses by message instead.</p>
ClassMethod ValuesJson(ByRef pValues) As %String
{
    Set tOut = {}
    Set tName = ""
    For {
        Set tName = $Order(pValues(tName))
        If tName = "" Quit
        If tName = "keyBody" Continue
        If '($Data(pValues(tName)) # 2) Continue
        Do tOut.%Set(tName, pValues(tName), "string")
    }
    Quit tOut.%ToJSON()
}

/// <p><var>pMessages</var> -- <code>pMessages(n, "role")</code> / <code>(n, "content")</code> with
/// the count in <code>pMessages</code> -- as a JSON array of <code>{role, content}</code>.</p>
ClassMethod MessagesJson(ByRef pMessages) As %String
{
    Set tOut = []
    For tI = 1:1:+$Get(pMessages) {
        Set tMessage = {}
        Do tMessage.%Set("role", $Get(pMessages(tI, "role")), "string")
        Do tMessage.%Set("content", $Get(pMessages(tI, "content")), "string")
        Do tOut.%Push(tMessage)
    }
    Quit tOut.%ToJSON()
}

/// <p>The fault a test that waited <var>pSeconds</var> with no answer carries:
/// <code>PROVIDER.TESTTIMEOUTLOCAL</code> when <var>pMarkedLocal</var>, otherwise
/// <code>PROVIDER.TESTTIMEOUT</code>, with the reason's placeholders resolved --
/// <code>&lt;provider&gt;</code> to <var>pLabel</var>, <code>&lt;n&gt;</code> to
/// <var>pSeconds</var> -- and <code>detail</code> carrying <code>waitedSeconds</code> and
/// <code>providerLabel</code>. <var>pHttpStatus</var> is 504.</p>
ClassMethod TimeoutFault(pMarkedLocal As %Boolean, pLabel As %String, pSeconds As %Integer, Output pFault As %DynamicObject, Output pHttpStatus As %Integer)
{
    Set tCode = $Select(''pMarkedLocal: ##class(OcuPilot.Api.Error).#PROVIDERTESTTIMEOUTLOCAL, 1: ##class(OcuPilot.Api.Error).#PROVIDERTESTTIMEOUT)
    Set tReason = ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tCode)
    Set tReason = $Replace($Replace(tReason, "<provider>", pLabel), "<n>", +pSeconds)
    Do ##class(OcuPilot.Kernel.Provider.Base).Fault(tCode, tReason, "", .pFault, .pHttpStatus)
    Set tDetail = {}
    Do tDetail.%Set("waitedSeconds", +pSeconds, "number")
    Do tDetail.%Set("providerLabel", pLabel, "string")
    Do pFault.%Set("detail", tDetail)
}

/// <p>Answer 502 <code>PROVIDER.TRANSPORT</code> in <var>pHttpStatus</var> / <var>pFault</var>, and
/// log <var>pStatus</var> under <var>pMessage</var>.</p>
ClassMethod Transport(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) [ Private ]
{
    Do ##class(OcuPilot.Kernel.Provider.Base).Fault(##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "", "", .pFault, .pHttpStatus)
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT)
}

}

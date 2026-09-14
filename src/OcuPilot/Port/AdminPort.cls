/// <p>The port to the instance's own administration API (AD-2, AD-26, AD-27). <b>This is the
/// only class in the tree that names an <code>%Api.Admin.*</code> class</b>, and it names them
/// only through the parameters below, so a vendor change has a blast radius of one file.</p>
/// <p><method>Invoke</method> is the one way to call an admin endpoint. A caller names the
/// endpoint package-relative (<code>WebApp.App</code>) and the request type by its vendor
/// parameter suffix (<code>GET</code>, <code>LIST</code>, <code>INFO</code>), and receives
/// either the endpoint's result or an error <class>%Status</class> with a wire-safe fault. The
/// call reproduces <code>Dispatch.v1:Main()</code> on the pinned build, in its order: construct
/// at <parameter>APIVERSION</parameter>, gate on <code>ResourcesOR()</code>, seed
/// <code>%request.Data</code> and run <code>SaveQueryParams()</code> then
/// <code>ValidateQueryParams()</code>, <code>ValidateRequest()</code>,
/// <code>ValidateSemantics()</code>, <code>ShouldRunAsync()</code>, and
/// <code>Run()</code> inside the vendor's output capture. The sequence runs in
/// <code>%SYS</code>, reached by save and restore (AD-16), behind port-owned
/// <code>%request</code>, <code>%response</code> and <code>%session</code> stubs that are
/// <code>New</code>ed in the invoking frame, so the caller's own CSP objects are never read or
/// written and <code>IsRunningAsync</code> stays 0.</p>
/// <p>Success is exactly an OK vendor status under a 2xx HTTP status. An answer of
/// <code>202</code> whose <code>Location</code> names an <code>async-result</code> id is polled
/// through the <code>AsyncResult</code> endpoint until the task is terminal or
/// <method>AsyncTimeout</method> passes (AD-26), whichever entry queued it; a terminal task's row
/// is deleted by the port. Nothing is cached across calls (AD-8): every invocation first
/// re-runs <method>VerifyInstance</method>.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.PortFixture</class>):
/// <method>AdminApiClass</method>, <method>ProbeEndpointClass</method>,
/// <method>EndpointClass</method>, <method>HoldsResource</method>, <method>OnBeforeRun</method>,
/// <method>PollTask</method>, <method>ForgetTask</method>, <method>AsyncTimeout</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.AdminPort Extends %RegisteredObject
{

/// <p>The vendor's admin API routing class, whose <code>UrlMap</code>
/// <method>HighestDispatchVersion</method> reads.</p>
Parameter ADMINAPICLASS = "%Api.Admin";

/// <p>The package the vendor's endpoint classes live in. Named here, not in the inventory
/// fixture that enumerates them, so AD-27's containment holds for the literal as well as
/// for the calls.</p>
Parameter ENDPOINTPACKAGE = "%Api.Admin.Endpoints.";

/// <p>The vendor base class every endpoint extends. It declares <code>TYPEGET</code> and
/// <code>TYPELIST</code> for all of them and answers <code>{}</code> for a read its subclass
/// does not implement.</p>
Parameter ENDPOINTBASECLASS = "%Api.Admin.Endpoint";

/// <p>The endpoint whose answers stand for the whole API's contract. Chosen because it is
/// read-only, takes no request body and needs no query parameter, so constructing it and
/// asking it three questions changes nothing on the instance.</p>
Parameter PROBEENDPOINT = "%Api.Admin.Endpoints.WebSession";

/// <p>The API version OcuPilot is built against (NFR-8). Every endpoint is constructed at
/// this version (AD-2, step 1).</p>
Parameter APIVERSION As INTEGER = 2;

/// <p>The request type the probe is constructed with -- the vendor's
/// <code>TYPELIST</code>. Spelled as its number because reading the vendor's parameter for
/// it would mean a second class naming an <code>%Api.Admin.*</code> class.</p>
Parameter PROBETYPE As INTEGER = 0;

/// <p>The base of every async task row, whose IdKey is the task's GUID. Named for
/// <method>ForgetTask</method>'s delete and for the terminal state names.</p>
Parameter ASYNCTASKCLASS = "%Api.Admin.Util.AsyncTask";

/// <p>The task class <code>Main()</code> hands an endpoint to when
/// <code>ShouldRunAsync()</code> is true.</p>
Parameter ASYNCTASKENDPOINTCLASS = "%Api.Admin.Util.AsyncTaskEndpoint";

/// <p>The class holding the vendor's <code>BeginCaptureOutput</code> and
/// <code>EndCaptureOutput</code>.</p>
Parameter CAPTURECLASS = "%Api.Admin.Util.General";

/// <p>The package-relative endpoint an async task is polled through.</p>
Parameter ASYNCRESULTENDPOINT = "AsyncResult";

/// <p>What a <code>Location</code> header carries before a task's GUID when an endpoint queued
/// work and answered <code>202</code>.</p>
Parameter ASYNCLOCATION = "async-result?id=";

/// <p>The request-type suffixes <method>Invoke</method> accepts, each resolved through the
/// endpoint's own <code>TYPE&lt;suffix&gt;</code> parameter. Reads only.</p>
Parameter TYPESUFFIXES = "GET,LIST,INFO";

/// <p>The synthetic request URL prefix. <code>GetName()</code> labels a task with the text
/// after <code>api/admin</code>, and <code>NormalizeLocationHeader()</code> builds the
/// <code>Location</code> from the text before <code>/api/admin</code>, so both need it.</p>
Parameter STUBURLPREFIX = "/api/admin/v2/ocupilot/";

/// <p>The bounded wait for an async task, in seconds (AD-26).</p>
Parameter ASYNCTIMEOUT = 30;

/// <p>The pause between two polls of an async task, in seconds.</p>
Parameter POLLINTERVAL = 0.05;

/// <p>The HTTP status <code>Main()</code> sets when the gate refuses or a
/// <code>&lt;PROTECT&gt;</code> escapes <code>Run()</code>.</p>
Parameter HTTPFORBIDDEN = "403 Forbidden";

/// <p>The HTTP status <code>Main()</code> sets when query parameters or the request body fail
/// validation.</p>
Parameter HTTPBADREQUEST = "400 Bad Request";

/// <p>The admin API routing class this port reads. Overridable so
/// <class>OcuPilot.Test.PortFixture</class> can point the real derivation at a fixture
/// class carrying a fixture <code>UrlMap</code>, which is how version 1, version 3 and an
/// absent API are pinned without touching the instance's own admin API. Production never
/// overrides this.</p>
ClassMethod AdminApiClass() As %String
{
    Quit ..#ADMINAPICLASS
}

/// <p>The endpoint class <method>ProbeAnswers</method> constructs. Overridable for the same
/// reason as <method>AdminApiClass</method>; production never overrides it.</p>
ClassMethod ProbeEndpointClass() As %String
{
    Quit ..#PROBEENDPOINT
}

/// <p>The vendor endpoint package, exposed as a method so
/// <class>OcuPilot.Test.AdminInventory</class> enumerates the classes without naming the
/// package itself.</p>
ClassMethod EndpointPackage() As %String
{
    Quit ..#ENDPOINTPACKAGE
}

/// <p>The highest <code>N</code> among <var>pClass</var>'s own <code>UrlMap</code> routes
/// that forward to <code>&lt;pClass&gt;.Dispatch.v&lt;N&gt;</code>; <code>0</code> when the
/// class, the <code>UrlMap</code> or every such forward is absent <b>or unreadable</b> --
/// the two are not told apart here, so the caller's detail must not claim which it was.</p>
/// <p>This reproduces the vendor's own computation -- <code>%Api.Admin.Info()</code> reads
/// the same <code>UrlMap</code> out of the same class-definition dictionary, tests for
/// <code>Forward="&lt;class&gt;</code> and takes
/// <code>+$Piece(line, "&lt;class&gt;.Dispatch.v", 2)</code> -- so OcuPilot and
/// <code>/api/admin/info</code> cannot report different versions. Two deliberate
/// differences, neither able to change the answer: <code>Info()</code> seeds at 1 and so
/// can never report an absent API, where this reports <code>0</code>, which is what the
/// mismatch notice needs to say; and <code>Info()</code> skips the XData's first and last
/// lines as the <code>&lt;Routes&gt;</code> wrapper, where this reads every line -- a
/// <code>Forward=</code> can only occur inside that wrapper.</p>
/// <p><code>Info()</code> itself is never called in-process: it reads
/// <code>%session.Username</code>, sets <code>%response.Status</code> and writes its JSON
/// to the device.</p>
ClassMethod HighestDispatchVersion(pClass As %String) As %Integer
{
    Set tVersion = 0
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClass, "UrlMap", , .tSC)
        If '$IsObject(tXData) Quit
        Set tMarker = "Forward=""" _ pClass
        Set tPrefix = pClass _ ".Dispatch.v"
        Do tXData.Data.Rewind()
        While 'tXData.Data.AtEnd {
            Set tLine = tXData.Data.ReadLine()
            If tLine '[ tMarker Continue
            Set tFound = +$Piece(tLine, tPrefix, 2)
            If tFound > tVersion Set tVersion = tFound
        }
    } Catch {
        Set tVersion = 0
    }
    Quit tVersion
}

/// <p>Whether the probe endpoint still answers the contract AD-2's sequence depends on:
/// it constructs as <code>%New(&lt;type&gt;, 2)</code>, its <code>ResourcesOR()</code>
/// returns a non-empty <code>%List</code> for the gate to evaluate, and its
/// <code>ShouldRunAsync()</code> answers 0 or 1 so the synchronous and async paths can be
/// told apart.</p>
/// <p><var>pDetail</var> names the class and what it lacked; it is empty exactly when the
/// probe passed. The three questions are asked through
/// <code>$ClassMethod</code>/dynamic dispatch rather than a typed reference, so a fixture
/// endpoint needs no vendor superclass (AD-27).</p>
ClassMethod ProbeAnswers(Output pDetail As %String) As %Boolean
{
    Set pDetail = ""
    Set tClass = ..ProbeEndpointClass()
    Try {
        Set tEndpoint = $ClassMethod(tClass, "%New", ..#PROBETYPE, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set pDetail = "probe endpoint " _ tClass _ " did not construct at ApiVersion " _ ..#APIVERSION
            Quit
        }
        Set tResources = tEndpoint.ResourcesOR()
        If ('$ListValid(tResources)) || ($ListLength(tResources) = 0) {
            Set pDetail = "probe endpoint " _ tClass _ " returned no resource from ResourcesOR()"
            Quit
        }
        Set tAsync = tEndpoint.ShouldRunAsync()
        If (tAsync '= 0) && (tAsync '= 1) {
            Set pDetail = "probe endpoint " _ tClass _ " answered ShouldRunAsync() with " _ tAsync
            Quit
        }
    } Catch ex {
        Set pDetail = "probe endpoint " _ tClass _ " failed the port's contract: " _ ex.DisplayString()
    }
    Quit pDetail = ""
}

/// <p>Report the usable admin API version, and refuse to report one at all unless the named
/// probe endpoint still answers (AD-27: fail loudly, never a partly-working screen).</p>
/// <p><var>pVersion</var> is the derived version, or <code>0</code> when the API is absent
/// or the probe failed. <var>pDetail</var> is empty exactly when
/// <var>pVersion</var> is the instance's real version and the probe passed; otherwise it
/// names what was missing and is what the caller logs. An error
/// <class>%Status</class> is always accompanied by a non-empty <var>pDetail</var>.</p>
/// <p>A version other than <parameter>APIVERSION</parameter> is not an error here: the
/// client needs the number in order to name it in the mismatch notice.</p>
ClassMethod VerifyInstance(Output pVersion As %Integer, Output pDetail As %String) As %Status
{
    Set tSC = $$$OK
    Set pVersion = 0
    Set pDetail = ""
    Try {
        Set tClass = ..AdminApiClass()
        Set pVersion = ..HighestDispatchVersion(tClass)
        If pVersion = 0 {
            Set pDetail = "admin API unusable: " _ tClass _ " publishes no readable UrlMap route forwarding to " _ tClass _ ".Dispatch.v<N>"
            Quit
        }
        Set tProbeDetail = ""
        If '..ProbeAnswers(.tProbeDetail) {
            Set pVersion = 0
            Set pDetail = tProbeDetail
            Quit
        }
    } Catch ex {
        Set pVersion = 0
        Set pDetail = "the admin API check failed: " _ ex.DisplayString()
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Call one admin endpoint as the calling process's user (AD-1, AD-2, AD-26).</p>
/// <p><var>pEndpoint</var> is package-relative (<code>WebApp.App</code>); <var>pType</var> is a
/// suffix from <parameter>TYPESUFFIXES</parameter>; <var>pQuery</var> holds query parameters as
/// <code>pQuery(name) = value</code>; <var>pBody</var> is the request body, <code>{}</code> when
/// omitted.</p>
/// <p>Returns OK exactly when the endpoint's status is OK and its HTTP status is 2xx, with
/// <var>pResult</var> the endpoint's return value (an async task's <code>Result</code>) and
/// <var>pFault</var> empty. Otherwise returns an error <class>%Status</class> carrying only
/// OcuPilot's own text, <var>pResult</var> empty and <var>pFault</var>
/// <code>{error, reason, code}</code> from <class>OcuPilot.Kernel.Fault</class>; vendor text goes
/// to <method>LogFault</method> alone. <var>pHttpStatus</var> is the numeric HTTP status in both
/// cases: the endpoint's, 503 for a refusal the port decided (<code>PORT.UNAVAILABLE</code>,
/// <code>PORT.TIMEOUT</code>), 501 for a name no compiled endpoint class answers, a suffix
/// outside <parameter>TYPESUFFIXES</parameter>, a suffix the class declares no
/// <code>TYPE&lt;suffix&gt;</code> parameter for, or a read the class leaves to the vendor base
/// class (<method>ImplementsRead</method>).</p>
/// <p>Must not be called from an escalated frame (AD-9). The caller's namespace,
/// <code>%request</code>, <code>%response</code> and <code>%session</code> are unchanged on
/// return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tVerifySC = ..VerifyInstance(.tVersion, .tDetail)
        If $$$ISERR(tVerifySC) || (tVersion '= ..#APIVERSION) || (tDetail '= "") {
            If (tVersion '= 0) && (tVersion '= ..#APIVERSION) {
                Set tReason = "The instance's administration API reports version " _ tVersion _ ", and OcuPilot needs version " _ ..#APIVERSION
            } Else {
                Set tReason = "The instance's administration API is absent or did not answer OcuPilot's probe"
            }
            Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, tReason, .pHttpStatus, .pFault)
            If $$$ISERR(tVerifySC) {
                Do ..LogFault("admin API unverified", tVerifySC, pFault.code)
            } ElseIf tDetail '= "" {
                Do ..LogFault("admin API unverified", $$$ERROR($$$GeneralError, tDetail), pFault.code)
            }
            Quit
        }

        Set tClass = ..EndpointClass(pEndpoint)
        Set tType = ""
        If tClass '= "" Set tType = ..EndpointType(tClass, pType)
        If tType = "" {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
            Quit
        }

        Set tSeqSC = ..RunSequence(pEndpoint, tClass, tType, .pQuery, pBody, .tAnswer, .tHttp, .tLocation)
        If $$$ISOK(tSeqSC) && (tHttp = 202) && (tLocation [ ..#ASYNCLOCATION) {
            Set tAnswer = ""
            Set tGuid = $Piece($Piece(tLocation, ..#ASYNCLOCATION, 2), "&", 1)
            Set tSC = ..AwaitTask(pEndpoint, tGuid, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $$$ISOK(tSeqSC) && (tHttp >= 200) && (tHttp < 300) {
            Set pResult = tAnswer
            Set pHttpStatus = tHttp
            Quit
        }
        Set tSC = ..Fail(pEndpoint, tHttp, tSeqSC, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Do ..LogFault(pEndpoint _ " failed inside the port", ex.AsStatus(), pFault.code)
        Set tSC = $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
    }
    Quit tSC
}

/// <p>The fully qualified endpoint class for a package-relative name, or <code>""</code> when
/// the name is not dotted identifiers or no such compiled class exists.</p>
ClassMethod EndpointClass(pEndpoint As %String) As %String
{
    If '$Match(pEndpoint, "^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit ""
    Set tClass = ..#ENDPOINTPACKAGE _ pEndpoint
    If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) Quit ""
    Quit tClass
}

/// <p>Whether the calling process holds <var>pResource</var> at <code>USE</code>, which is the
/// test <code>Main()</code> applies to each entry of <code>ResourcesOR()</code>.</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    Quit $System.Security.Check(pResource, "U")
}

/// <p>Called with the endpoint after <code>ShouldRunAsync()</code> answers 0 and before
/// <code>Run()</code>, in <code>%SYS</code>. Does nothing in production.</p>
ClassMethod OnBeforeRun(pEndpoint As %RegisteredObject)
{
    Quit
}

/// <p>Read one async task's state through the <code>AsyncResult</code> endpoint's GET, by the
/// same sequence <method>Invoke</method> runs. <var>pAnswer</var> is that endpoint's answer
/// (<code>State</code>, <code>TaskName</code>, <code>Result</code>,
/// <code>FailureReason</code>, ...); <var>pHttpStatus</var> the HTTP status it left. The status
/// returned is the vendor sequence's.</p>
ClassMethod PollTask(pGuid As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer) As %Status
{
    Set tQuery("id") = pGuid
    Set tClass = ..#ENDPOINTPACKAGE _ ..#ASYNCRESULTENDPOINT
    Quit ..RunSequence(..#ASYNCRESULTENDPOINT, tClass, $Parameter(tClass, "TYPEGET"), .tQuery, "", .pAnswer, .pHttpStatus, .tLocation)
}

/// <p>Delete the task row <var>pGuid</var> names, once it is terminal and no worker still owns
/// it. Only the row this call queued is deleted. A failure is logged and never raised.</p>
ClassMethod ForgetTask(pGuid As %String)
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#ASYNCTASKCLASS, "%DeleteId", pGuid)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFault("an async task row could not be removed", tSC)
}

/// <p>The bounded wait, in seconds, for an async task to reach a terminal state.</p>
ClassMethod AsyncTimeout() As %Numeric
{
    Quit ..#ASYNCTIMEOUT
}

/// <p>Send raw vendor text to the log, and nowhere else (AD-39).</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("adminport", pMessage, pStatus, pCode)
}

/// <p>The vendor type number for suffix <var>pSuffix</var> on <var>pClass</var>, or
/// <code>""</code> when the suffix is not in <parameter>TYPESUFFIXES</parameter>, the class
/// declares no <code>TYPE&lt;suffix&gt;</code> parameter, or <method>ImplementsRead</method>
/// says the class does not implement that read.</p>
ClassMethod EndpointType(pClass As %String, pSuffix As %String) As %String [ Private ]
{
    If '$Match(pSuffix, "^[A-Z]+$") Quit ""
    If '$ListFind($ListFromString(..#TYPESUFFIXES), pSuffix) Quit ""
    Set tType = $Parameter(pClass, "TYPE" _ pSuffix)
    If tType = "" Quit ""
    If '..ImplementsRead(pClass, pSuffix) Quit ""
    Quit tType
}

/// <p>Whether <var>pClass</var> implements the read <var>pSuffix</var> names. The base class's
/// <code>Run()</code> sends <code>GET</code> to <code>RunGet</code> and <code>LIST</code> to
/// <code>RunList</code>, answers <code>{}</code> for any other type, and both runners answer
/// <code>{}</code>; so a read is implemented when <code>Run</code>, or the runner for that
/// suffix, is defined below <parameter>ENDPOINTBASECLASS</parameter>. A class that overrides
/// <code>Run</code> is trusted to dispatch its own types.</p>
ClassMethod ImplementsRead(pClass As %String, pSuffix As %String) As %Boolean [ Private ]
{
    If ..MethodOrigin(pClass, "Run") '= ..#ENDPOINTBASECLASS Quit 1
    Set tRunner = $Case(pSuffix, "GET": "RunGet", "LIST": "RunList", : "")
    If tRunner = "" Quit 0
    Quit ..MethodOrigin(pClass, tRunner) '= ..#ENDPOINTBASECLASS
}

/// <p>The class that defines <var>pClass</var>'s compiled method <var>pMethod</var>, or
/// <code>""</code> when it has none.</p>
ClassMethod MethodOrigin(pClass As %String, pMethod As %String) As %String [ Private ]
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(pClass, pMethod, 0)
    If '$IsObject(tMethod) Quit ""
    Quit tMethod.Origin
}

/// <p>Construct the endpoint behind fresh stubs and run <method>Sequence</method> in
/// <code>%SYS</code>. <var>pHttpStatus</var> is the stub response's numeric status, raised to
/// 500 when the returned status is an error under no status or any 2xx (<code>Main()</code>
/// raises it under 200, 201 and 202);
/// <var>pLocation</var> is its <code>Location</code> header.</p>
/// <p>The endpoint is constructed before the switch, in the caller's namespace, because a
/// class compiled only there cannot be constructed from <code>%SYS</code>; the vendor's
/// <code>%OnNew</code> records the type and version and nothing else.</p>
ClassMethod RunSequence(pEndpoint As %String, pClass As %String, pType As %Integer, ByRef pQuery, pBody As %DynamicAbstractObject, Output pAnswer, Output pHttpStatus As %Integer, Output pLocation As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pLocation = ""
    New %request, %response, %session
    Set tOrigNS = $NAMESPACE
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %request.Method = "GET"
        Set %request.URL = ..#STUBURLPREFIX _ $ZConvert($Translate(pEndpoint, ".", "/"), "L")
        Set tName = $Order(pQuery(""))
        While tName '= "" {
            Set %request.Data(tName, 1) = pQuery(tName)
            Set tName = $Order(pQuery(tName))
        }
        Set %response = ##class(%CSP.Response).%New()
        Set %session = {"Username": ($USERNAME)}
        Set tBody = $Select($IsObject(pBody): pBody, 1: {})

        Set tEndpoint = $ClassMethod(pClass, "%New", pType, ..#APIVERSION)
        If '$IsObject(tEndpoint) {
            Set tSC = $Get(%objlasterror, $$$ERROR($$$GeneralError, "endpoint did not construct"))
            Quit
        }
        Set tEndpoint.IsRunningAsync = 0

        Set $NAMESPACE = "%SYS"
        Set tSC = ..Sequence(tEndpoint, tBody, .pAnswer)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $IsObject($Get(%response)) {
        Set pHttpStatus = +%response.Status
        Set pLocation = %response.GetHeader("Location")
    }
    If $$$ISERR(tSC) && ((pHttpStatus = 0) || ((pHttpStatus >= 200) && (pHttpStatus < 300))) {
        Set pHttpStatus = 500
    }
    Quit tSC
}

/// <p><code>Main()</code>'s steps after construction, in its order, against stubs already in
/// place. Runs in <code>%SYS</code>.</p>
ClassMethod Sequence(pEndpoint As %RegisteredObject, pBody As %DynamicAbstractObject, Output pAnswer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Try {
        Set tAllowed = 0
        Set tResources = pEndpoint.ResourcesOR()
        For tI = 1:1:$ListLength(tResources) {
            Set tAllowed = tAllowed || ..HoldsResource($ListGet(tResources, tI))
        }
        If 'tAllowed {
            Set %response.Status = ..#HTTPFORBIDDEN
            Quit
        }

        Do pEndpoint.SaveQueryParams()
        Try {
            Do pEndpoint.ValidateQueryParams()
        } Catch exQuery {
            Set %response.Status = ..#HTTPBADREQUEST
            Set tSC = exQuery.AsStatus()
        }
        If $$$ISERR(tSC) Quit

        Set tSC = pEndpoint.ValidateRequest(pBody)
        If $$$ISERR(tSC) {
            Set %response.Status = ..#HTTPBADREQUEST
            Quit
        }
        Try {
            Set tSC = pEndpoint.ValidateSemantics()
        } Catch exSemantics {
            Set tSC = exSemantics.AsStatus()
        }
        If $$$ISERR(tSC) Quit

        If pEndpoint.ShouldRunAsync() {
            Set tTask = $ClassMethod(..#ASYNCTASKENDPOINTCLASS, "%New", %request, pEndpoint)
            Set tSC = $$$ADDSC(tSC, tTask.SaveRequestBody(pBody))
            Set tSC = $$$ADDSC(tSC, tTask.AddToAsyncQueue())
            ; Drop the task before anything polls it: while an OREF to the row survives, the
            ; poll's %OpenId returns this in-memory copy, which stays Queued.
            Set tTask = ""
            Quit
        }

        Do ..OnBeforeRun(pEndpoint)
        Try {
            Set tSC = $ClassMethod(..#CAPTURECLASS, "BeginCaptureOutput", .tCookie)
            If $$$ISERR(tSC) Quit
            Set pAnswer = pEndpoint.Run(.tSC, pBody)
        } Catch exRun {
            Set tSC = exRun.AsStatus()
            If exRun.%IsA("%Exception.SystemException") && (exRun.Name = "<PROTECT>") {
                Set %response.Status = ..#HTTPFORBIDDEN
            }
        }
        If $Data(tCookie) Do $ClassMethod(..#CAPTURECLASS, "EndCaptureOutput", tCookie, .tLines)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Poll task <var>pGuid</var> until it is terminal or <method>AsyncTimeout</method> passes.
/// <code>Finished</code> is a 200 success carrying the task's <code>Result</code>;
/// <code>Failed</code> is a 500 whose fault is built from <code>FailureReason</code>; both
/// delete the row. No terminal state within the bound is <code>PORT.TIMEOUT</code>, and the row
/// is left to the worker that still owns it.</p>
ClassMethod AwaitTask(pEndpoint As %String, pGuid As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set tFinished = $Parameter(..#ASYNCTASKCLASS, "STATEFINISHED")
    Set tFailed = $Parameter(..#ASYNCTASKCLASS, "STATEFAILED")
    Set tBound = ..AsyncTimeout()
    Set tStart = $ZHorolog
    For {
        Set tAnswer = ""
        Set tPollHttp = 0
        Set tPollSC = ..PollTask(pGuid, .tAnswer, .tPollHttp)
        If $$$ISERR(tPollSC) || (tPollHttp < 200) || (tPollHttp >= 300) || '$IsObject(tAnswer) {
            Set tSC = ..Fail(pEndpoint _ " task " _ pGuid, $Select((tPollHttp < 200) || (tPollHttp >= 300): tPollHttp, 1: 500), tPollSC, .pHttpStatus, .pFault)
            Quit
        }
        If tAnswer.State = tFinished {
            Do ..ForgetTask(pGuid)
            Set pResult = tAnswer.Result
            Set pHttpStatus = 200
            Quit
        }
        If tAnswer.State = tFailed {
            Do ..ForgetTask(pGuid)
            Set tSC = ..Fail(pEndpoint, 500, $$$ERROR($$$GeneralError, tAnswer.FailureReason), .pHttpStatus, .pFault)
            Quit
        }
        If ($ZHorolog - tStart) >= tBound {
            Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTTIMEOUT, "The instance did not finish that operation in time", .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " task " _ pGuid _ " left " _ tAnswer.State _ " at the bound", tSC, pFault.code)
            Quit
        }
        Hang ..#POLLINTERVAL
    }
    Quit tSC
}

/// <p>A failed vendor outcome: the fault from <method>OcuPilot.Kernel.Fault.Outcome</method>,
/// the vendor status to the log, and an error status carrying only the fault's own text.</p>
ClassMethod Fail(pEndpoint As %String, pHttp As %Integer, pVendorSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = $Select(+pHttp: +pHttp, 1: 500)
    Set tOutcomeSC = ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, pVendorSC, .pFault, .tDetail)
    If $$$ISERR(tOutcomeSC) Do ..LogFault(pEndpoint _ " fault mapping failed", tOutcomeSC, pFault.code)
    If $$$ISERR(pVendorSC) Do ..LogFault(pEndpoint _ " failed with HTTP " _ pHttpStatus, pVendorSC, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>A refusal the port decided itself, with no vendor status behind it.</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

}

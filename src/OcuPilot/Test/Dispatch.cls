/// <p>In-process dispatch harness for <class>OcuPilot.Api.Router</class> subclasses.</p>
/// <p>Story 1.5 created the two web applications, so an over-the-wire test is possible now
/// (<class>OcuPilot.Test.Wire</class>); this harness stays because it reaches router
/// behaviour a wire test cannot address on its own — a fixture route table, a fixture
/// identity, and a framework error path with no application of its own. It exercises the
/// router's real runtime minus the gateway hop: it builds standalone
/// <class>%CSP.Request</class> /
/// <class>%CSP.Response</class> stubs (the same construction AD-2 uses for the vendor's own
/// endpoint objects), calls <code>DispatchRequest</code> directly — which runs the real
/// <code>UrlMap</code> matcher, the real <method>OnPreDispatch</method> and both real
/// framework-error overrides — and captures whatever the router writes to the response
/// device, unparsed, so <class>OcuPilot.Test.Envelope</class>'s <code>}{</code> check runs
/// against the literal wire body rather than something a JSON parser already forgave.</p>
/// <p>The capture uses a bound mnemonic I/O space (<method>Redirects</method>, below) rather
/// than a real device or file — <code>Use tNull::("^"_$ZNAME)</code> only resolves those
/// labels when they live in the routine <i>currently executing</i>, which is why this
/// class's capture and its label block must stay together rather than being factored into
/// a shared base class.</p>
Class OcuPilot.Test.Dispatch Extends %RegisteredObject
{

/// <p>Dispatch <var>pMethod</var> <var>pUrl</var> against <var>pRouterClass</var> (a class
/// name naming an <class>OcuPilot.Api.Router</class> subclass) in-process.</p>
/// <p><var>pParams</var>, when supplied, is a flat <class>%DynamicObject</class> of query
/// parameters set on the request before dispatch (e.g. <code>{"ns": ("HSCUSTOM")}</code>) —
/// this is how a test drives <code>?ns=</code> and <class>OcuPilot.Test.RouterFixture</class>'s
/// fixture-identity override without a real query string.</p>
/// <p>Returns the dispatched <class>%Status</class>; <var>pBody</var> is the captured,
/// <b>unparsed</b> response body, <var>pStatus</var> is the numeric HTTP status
/// <code>%response.Status</code> was left at, and <var>pAllowHeader</var> is whatever
/// <code>%response</code>'s <code>Allow</code> header was set to (empty when none was set).</p>
/// <p><var>pApplication</var>, when supplied, is the web application the CSP server would
/// have matched. Only a handler that reads <code>%request.Application</code> needs it —
/// <class>OcuPilot.Api.StaticHandler</class> resolves its bundle directory from it (AD-21),
/// so without it every path resolves against an empty root and a refusal test could not tell
/// a working check from a broken one.</p>
/// <p><var>pRequestBody</var>, when supplied, is seeded as the request's
/// <property>%CSP.Request.Content</property> stream -- where the CSP server delivers a JSON body,
/// and the stream <method>OcuPilot.Kernel.Utils.ReadRequestBody</method> falls back to -- so a
/// handler that takes a body runs the same read here as it does over a socket.</p>
/// <p>It is applied through the request's own <code>UpdateURL</code>, which is how the CSP
/// server itself fills the property in: <code>ApplicationSet</code> is
/// <code>[ Private ]</code>, so the property cannot be assigned from here, and going through
/// the real resolver means the stub carries the application IRIS would actually have matched
/// rather than one this harness asserted. <code>UpdateURL</code> switches to the
/// application's namespace, so the caller's namespace is saved and restored around it
/// (AD-16).</p>
ClassMethod Invoke(pRouterClass As %String, pUrl As %String, pMethod As %String, pParams As %DynamicObject = "", Output pBody As %String, Output pStatus As %Integer, Output pAllowHeader As %String, pApplication As %String = "", pRequestBody As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pBody = ""
    Set pStatus = 0
    Set pAllowHeader = ""
    Set tCapturing = 0
    Try {
        Set %request = ##class(%CSP.Request).%New()
        If pApplication '= "" {
            Set tOrigNS = $NAMESPACE
            Set tAppSC = %request.UpdateURL(pApplication _ "/")
            Set $NAMESPACE = tOrigNS
            If $$$ISERR(tAppSC) {
                Set tSC = tAppSC
                Quit
            }
        }
        Set %request.Method = $ZConvert(pMethod, "U")
        Set %request.URL = pUrl
        If $IsObject(pParams) {
            Set tIter = pParams.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                Do %request.Set(tKey, tVal)
            }
        }
        If pRequestBody '= "" {
            ; Assigned to Content, the public property the CSP server fills for a JSON body.
            ; InsertMimeData is [ Final, Internal ] on %CSP.Request, and a harness is no place to
            ; lean on either.
            Set tRequestStream = ##class(%Stream.GlobalBinary).%New()
            Set tWriteSC = tRequestStream.Write(pRequestBody)
            If $$$ISERR(tWriteSC) {
                Set tSC = tWriteSC
                Quit
            }
            Set %request.Content = tRequestStream
            Set tRequestStream = ""
        }
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotDispatchCap = ""
        ; Arm the cleanup guard BEFORE the three statements that can leave the process
        ; with an open device or an active redirect. Set after them, a throw from any of
        ; the three skips the Catch's restore and strands $IO in the mnemonic space for
        ; the rest of the test process. Close/ReDirectIO(0)/Use are all tolerant of
        ; being called when the corresponding step never happened.
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        Set tSC = $ClassMethod(pRouterClass, "DispatchRequest", pUrl, %request.Method)

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pBody = $Get(%OcuPilotDispatchCap, "")
        Set pStatus = +%response.Status
        Set pAllowHeader = %response.GetHeader("Allow")
    } Catch ex {
        ; Restore first (AD-16). UpdateURL switches to the matched application's namespace,
        ; so a throw from it -- or from anything after it -- would otherwise leave this
        ; process in that namespace for every later method in the %UnitTest run, which is
        ; cross-test contamination in a suite whose classes already share one instance.
        ; A no-op on the normal path, where the restore beside UpdateURL has already run.
        If $Get(tOrigNS) '= "" Set $NAMESPACE = tOrigNS
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotDispatchCap
    Quit tSC
}

/// <p>Capture what <var>pRouterClass</var>'s <code>Http500</code> writes for
/// <var>pStatus</var> — the vendor's own call site for
/// <method>OcuPilot.Api.Router.ReportHttpStatusCode</method>'s <code>$$$ISERR</code> branch
/// (<code>%CSP.REST.Page()</code> calls it with whatever status
/// <code>DispatchRequest</code> returned, <file>irislib/%CSP/REST.cls</file>:205-210,
/// :493).</p>
/// <p><b>Why not run <code>Page()</code> itself.</b> <code>Page()</code> rebinds the
/// process's mnemonic space to <code>^%SYS.cspServer2</code>, the CSP server's own writer,
/// which needs a real CSP session and device; driving its next act directly keeps the
/// production call site without pretending this harness is a web server. The whole chain
/// does run for real over the wire in <class>OcuPilot.Test.Wire</class>.</p>
ClassMethod InvokeHttp500(pRouterClass As %String, pStatus As %Status, Output pBody As %String, Output pHttpStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pBody = ""
    Set pHttpStatus = 0
    Set tCapturing = 0
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %response = ##class(%CSP.Response).%New()

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotDispatchCap = ""
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        Set tSC = $ClassMethod(pRouterClass, "Http500", ##class(%Exception.StatusException).CreateFromStatus(pStatus))

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pBody = $Get(%OcuPilotDispatchCap, "")
        Set pHttpStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotDispatchCap
    Quit tSC
}

/// <p>Capture what <var>pHandlerClass</var>'s no-argument <var>pMethod</var> writes, against
/// <class>%CSP.Request</class> / <class>%CSP.Response</class> stubs carrying <var>pParams</var> as
/// query parameters. <var>pBody</var> is the unparsed response body and <var>pStatus</var> the
/// numeric HTTP status <code>%response.Status</code> was left at.</p>
/// <p><b>The route table is not involved, deliberately.</b> A handler the router's
/// <code>UrlMap</code> names by class offers no seam a fixture subclass can arrive through, so a
/// fixture is driven at the handler's own entry point instead. Everything above it -- the matcher
/// and <method>OcuPilot.Api.Router.OnPreDispatch</method> -- is <method>Invoke</method>'s subject
/// and is exercised over the wire besides.</p>
ClassMethod InvokeHandler(pHandlerClass As %String, pMethod As %String = "Handle", pParams As %DynamicObject = "", Output pBody As %String, Output pStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pBody = ""
    Set pStatus = 0
    Set tCapturing = 0
    Try {
        Set %request = ##class(%CSP.Request).%New()
        Set %response = ##class(%CSP.Response).%New()
        If $IsObject(pParams) {
            Set tIter = pParams.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                Do %request.Set(tKey, tVal)
            }
        }

        Set tInitIO = $IO
        Set tNull = ##class(%Library.Device).GetNullDevice()
        Set %OcuPilotDispatchCap = ""
        ; Armed before the three statements that can strand the process in the mnemonic space,
        ; for the reason Invoke's own comment gives.
        Set tCapturing = 1
        Open tNull:::1
        Use tNull::("^" _ $ZNAME)
        Do ##class(%Library.Device).ReDirectIO(1)

        Set tSC = $ClassMethod(pHandlerClass, pMethod)

        Do ##class(%Library.Device).ReDirectIO(0)
        Use tInitIO
        Close tNull
        Set tCapturing = 0

        Set pBody = $Get(%OcuPilotDispatchCap, "")
        Set pStatus = +%response.Status
    } Catch ex {
        If tCapturing {
            Do ##class(%Library.Device).ReDirectIO(0)
            Use tInitIO
            Close tNull
        }
        Set tSC = ex.AsStatus()
    }
    Kill %OcuPilotDispatchCap
    Quit tSC
}

/// <p>Mnemonic I/O space bound via <code>Use tNull::("^"_$ZNAME)</code> in
/// <method>Invoke</method> — must live in this class's own compiled routine for
/// <code>$ZNAME</code> to resolve these labels. Accumulates every <code>Write</code> issued
/// while the redirect is active into the process-private <var>%OcuPilotDispatchCap</var>.</p>
ClassMethod Redirects() [ Internal, Private, ProcedureBlock = 0 ]
{
    Quit
wstr(s) Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ s Quit
wchr(a) Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ $Char(a) Quit
wnl Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ $Char(10) Quit
wff Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ $Char(12) Quit
wtab(n) New tChars Set $Piece(tChars, " ", n+1) = "" Set %OcuPilotDispatchCap = $Get(%OcuPilotDispatchCap, "") _ tChars Quit
rstr(len,time) Quit ""
rchr(time) Quit ""
}

}

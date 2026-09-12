/// <p>AD-12's paired necessary-and-sufficient assertions: no response body contains
/// <code>}{</code> (necessary but not sufficient on its own), paired with an assertion
/// that every error path returns exactly one well-formed envelope with a slug from the
/// closed enum, the key set is exactly <code>{error, reason, code}</code> (or with
/// <code>detail</code> added), <code>detail</code> is omitted rather than <code>null</code>
/// when absent, an unknown slug is refused outright, and an internal exception yields a
/// generic client reason with the real detail reaching
/// <class>OcuPilot.Kernel.Audit.Log</class> only.</p>
Class OcuPilot.Test.Envelope Extends %UnitTest.TestCase
{

/// <p>The <code>}{</code> check must run on the raw, <b>unparsed</b> body —
/// <method>OcuPilot.Test.Dispatch.Invoke</method> already returns it unparsed for exactly
/// this reason, since parsing first would parse only the leading object and hide the
/// double-envelope defect. Paired with a secondary check that the body parses cleanly as
/// one JSON object carrying a non-empty <code>error</code> slug.</p>
Method AssertSingleEnvelope(pBody As %String, pLabel As %String)
{
    Do $$$AssertEquals((pBody [ "}{"), 0, pLabel _ ": no }{ concatenation in body")
    Set tObj = ""
    Try {
        Set tObj = ##class(%DynamicObject).%FromJSON(pBody)
    } Catch ex {
        ; Quit here, not after: tObj is still "" on this path, and the two member
        ; accesses below would raise <INVALID OREF> on a plain string — replacing the
        ; real assertion failure with an unrelated runtime error exactly when the test
        ; is already reporting a problem.
        Do $$$AssertTrue(0, pLabel _ ": body must parse as a single JSON object (was: " _ $Extract(pBody, 1, 120) _ ")")
        Quit
    }
    Do $$$AssertTrue($IsObject(tObj), pLabel _ ": parsed JSON is an object")
    Do $$$AssertTrue((tObj.error '= ""), pLabel _ ": envelope carries a non-empty error slug")
    Quit
}

/// <p>The key set is exactly <code>{error, reason, code}</code>, or those three plus
/// <code>detail</code> — never a fourth or fifth key beyond that, and never
/// <code>detail</code> present-but-null.</p>
Method AssertExactKeySet(pObj As %DynamicObject, pExpectDetail As %Boolean, pLabel As %String)
{
    Set tKeyCount = 0
    Set tHasError = 0, tHasReason = 0, tHasCode = 0, tHasDetail = 0
    Set tIter = pObj.%GetIterator()
    While tIter.%GetNext(.tKey) {
        Set tKeyCount = tKeyCount + 1
        If tKey = "error" Set tHasError = 1
        If tKey = "reason" Set tHasReason = 1
        If tKey = "code" Set tHasCode = 1
        If tKey = "detail" Set tHasDetail = 1
    }
    Do $$$AssertTrue(tHasError, pLabel _ ": has error")
    Do $$$AssertTrue(tHasReason, pLabel _ ": has reason")
    Do $$$AssertTrue(tHasCode, pLabel _ ": has code")
    Do $$$AssertEquals(tKeyCount, $Select(pExpectDetail: 4, 1: 3), pLabel _ ": a fifth key (or a missing one) is a test failure")
    If pExpectDetail {
        Do $$$AssertTrue(tHasDetail, pLabel _ ": has detail when one was supplied")
    } Else {
        Do $$$AssertTrue('tHasDetail, pLabel _ ": detail is omitted, never present-but-null, when none was supplied")
    }
}

/// <p>Both framework overrides (404 and 405) each write exactly one envelope. The bare
/// root is the one path this fixture's <code>/:resource</code> catch-all cannot match
/// (see <class>OcuPilot.Test.Routing</class>'s own note), so it is the clean 404 case;
/// DELETE on <code>/ping</code> exercises the genuine automatic
/// <method>OcuPilot.Api.Router.Http405</method> path, not an explicit guard route.</p>
Method TestNoDoubleEnvelopeOnFrameworkPaths()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do ..AssertSingleEnvelope(tBody, "framework 404")

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "DELETE", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do ..AssertSingleEnvelope(tBody, "framework 405")
}

/// <p>The nested-<code>Catch</code> route's inner failure renders exactly one envelope —
/// the outer <code>Try</code> is never resumed to write a second one (mutation: change
/// the fixture's inner <code>Return $$$OK</code> to a bare <code>Quit</code> and watch
/// this go red).</p>
Method TestNestedCatchProducesExactlyOneEnvelope()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/parse", "POST", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 400, "the inner parse failure renders a single 400")
    Do ..AssertSingleEnvelope(tBody, "nested Catch route")
}

/// <p>An unhandled internal exception yields a generic client reason and the machine
/// code <code>INTERNAL</code> — the raw exception name never reaches the client, only
/// <class>OcuPilot.Kernel.Audit.Log</class>.</p>
Method TestUnhandledExceptionRendersGenericReasonWithCodeInternal()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/boom", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 500, "an unhandled internal exception yields 500")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "server_error", "the internal path renders through Api.Error")
    Do $$$AssertEquals(tObj.code, "INTERNAL", "the internal path always carries the INTERNAL code")
    Do $$$AssertEquals(tObj.reason, "An internal error occurred", "the client sees a generic reason, never the raw exception text")
    Do $$$AssertTrue((tObj.reason '[ "UNDEFINED"), "the raw exception name never reaches the client")
    Do ..AssertSingleEnvelope(tBody, "unhandled exception route")
}

/// <p>DW-26: <method>OcuPilot.Api.Error.RenderInternal</method> used to name
/// <class>OcuPilot.Kernel.Audit.Log</class> by hard class name, so no test could intercept
/// what it actually logs. <class>OcuPilot.Test.ErrorProbe</class> overrides the
/// <method>OcuPilot.Api.Error.LogError</method> seam <method>RenderInternal</method>
/// (inherited unchanged) reaches through <code>..</code> dispatch, so this asserts the
/// subsystem, message and the real exception's <method>DisplayString()</method> detail
/// actually reach the seam.</p>
/// <p>Mutation: change the literal <code>"Internal error"</code> message
/// <method>RenderInternal</method> passes to the seam to anything else — the message
/// assertion below goes red.</p>
Method TestRenderInternalRoutesSubsystemMessageAndDetailThroughSeam()
{
    Do ##class(OcuPilot.Test.ErrorProbe).Clear()
    Set tException = ""
    Try {
        Set tValue = tOcuPilotEnvelopeNeverAssigned + 1
    } Catch ex {
        Set tException = ex
    }
    Do $$$AssertTrue($IsObject(tException), "a real exception was caught to route through RenderInternal")

    Do ##class(OcuPilot.Test.ErrorProbe).RenderInternal("An internal error occurred", tException)

    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorProbe).Captured("subsystem"), "router", "RenderInternal logs subsystem ""router"" through the seam")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorProbe).Captured("message"), "Internal error", "RenderInternal logs message ""Internal error"" through the seam")
    Set tData = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.ErrorProbe).Captured("data"))
    Do $$$AssertEquals(tData.detail, tException.DisplayString(), "the caught exception's DisplayString() reaches the seam as detail")

    Do ##class(OcuPilot.Test.ErrorProbe).Clear()
}

/// <p>Every error path's key set is exactly <code>{error, reason, code}</code> when no
/// detail is supplied.</p>
Method TestKeySetWithoutDetail()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do ..AssertExactKeySet(tObj, 0, "framework 404, no detail supplied")
}

/// <p><code>detail</code> is added, and only added, when a caller supplies a structured
/// detail object (mutation: add a fifth key to the object <code>Error.Render</code>
/// builds and watch this go red).</p>
Method TestKeySetWithDetail()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/detailed", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 422, "the detailed fixture route returns 422")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do ..AssertExactKeySet(tObj, 1, "validation route, detail supplied")
    Do $$$AssertEquals(tObj.detail.fields.%Get(0), "name", "the supplied detail object round-trips intact")
}

/// <p>Pins <method>OcuPilot.Api.Error.GetSlugForStatus</method>'s twelve-way mapping
/// directly. Its only call site is
/// <method>OcuPilot.Api.Router.ReportHttpStatusCode</method>'s non-404 branch, which no
/// dispatch test reaches — but that branch <b>is</b> reachable in production
/// (<code>%CSP.REST.Page()</code> calls <code>..Http403()</code> at
/// <code>irislib/%CSP/REST.cls:169</code>), so the mapping shipped entirely unexecuted:
/// inverting any pair below left the whole suite green. Also pins that the derived
/// machine code is the dotted-uppercase slug, never the status number — the Design
/// Notes' settled shape.</p>
/// <p>Mutation: swap the 401 and 403 return values in
/// <method>OcuPilot.Api.Error.GetSlugForStatus</method> → the first two assertions go
/// red.</p>
Method TestSlugForStatusMapping()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(401), "unauthorized", "401 maps to unauthorized")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(403), "forbidden", "403 maps to forbidden")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(400), "bad_request", "400 maps to bad_request")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(404), "not_found", "404 maps to not_found")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(405), "method_not_allowed", "405 maps to method_not_allowed")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(409), "conflict", "409 maps to conflict")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(412), "precondition_failed", "412 maps to precondition_failed")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(415), "bad_content_type", "415 maps to bad_content_type")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(422), "validation_failed", "422 maps to validation_failed")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(500), "server_error", "500 maps to server_error")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(501), "not_implemented", "501 maps to not_implemented")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(503), "unavailable", "503 maps to unavailable")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).GetSlugForStatus(418), "server_error", "an unmapped status falls back to server_error")

    ; The code the router derives from a slug is dotted uppercase, never the number.
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(403), "ROUTE.FORBIDDEN", "the derived machine code is dotted uppercase, not ROUTE.403")
}

/// <p>The derivation itself, now that it has one home
/// (<method>OcuPilot.Api.Error.CodeForStatus</method>) rather than two byte-identical copies.</p>
/// <p><b>The separator is what this is about.</b> <code>$ZConvert</code> alone leaves a slug's
/// underscore in, so <code>server_error</code> derived to <code>ROUTE.SERVER_ERROR</code> while
/// every hand-written code in the class is unseparated — two spelling families for one
/// vocabulary, and a client matching on one would not recognize the other. Every derived code
/// is also run through the writer's own format guard, which is what makes "no underscore" an
/// invariant rather than a habit.</p>
/// <p>Mutation: drop the <code>$Translate</code> from
/// <method>OcuPilot.Api.Error.CodeForStatus</method> → the 500 and 405 rows go red
/// (<code>ROUTE.SERVER_ERROR</code>), and so does the format-guard assertion.</p>
Method TestCodeForStatusIsUnseparatedAndPassesTheWritersOwnGuard()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(500), "ROUTE.SERVERERROR", "the derived code carries no separator")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(405), "ROUTE.METHODNOTALLOWED", "nor in a three-word slug")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(404), "ROUTE.NOTFOUND")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(418), "ROUTE.SERVERERROR", "an unmapped status derives from the fallback slug")

    ; The two the writer also declares as parameters are equal to their derivation, so the
    ; declared code and the derived one cannot drift into two spellings of one thing.
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(404), ##class(OcuPilot.Api.Error).#ROUTENOTFOUND, "the declared 404 code IS the derived one")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).CodeForStatus(405), ##class(OcuPilot.Api.Error).#ROUTEMETHODNOTALLOWED, "and the declared 405 code likewise")

    ; Every status the mapping knows derives a code the writer would accept.
    Set tStatuses = $ListBuild(400, 401, 403, 404, 405, 409, 412, 415, 422, 500, 501, 503, 418)
    For tI = 1:1:$ListLength(tStatuses) {
        Set tCode = ##class(OcuPilot.Api.Error).CodeForStatus($List(tStatuses, tI))
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), "derived code '" _ tCode _ "' passes the format guard")
    }
}

/// <p>The code is a declared, format-guarded identifier — an invariant of the one writer, not a
/// convention its call sites keep.</p>
/// <p>Calling <method>OcuPilot.Api.Error.Render</method> with no <code>%response</code> set up
/// at all is itself the proof that nothing is written: a refusal that happened after the status
/// assignment would throw rather than return, and a refusal that happened after the
/// <code>Write</code> could not return this status at all.</p>
/// <p>Mutation: replace <method>OcuPilot.Api.Error.IsValidCode</method>'s body with
/// <code>Quit pCode '= ""</code> — the numeric and lower-case rows go red, which is exactly the
/// pair the old <code>pCode = ""</code> guard let through.</p>
Method TestMalformedCodeIsRefusedAndNothingIsWritten()
{
    Set tBad = $ListBuild("", "403", "500", "route.notfound", "Route.NotFound", "ROUTE_NOTFOUND", "ROUTE.", ".ROUTE", "1ROUTE", "ROUTE NOTFOUND")
    For tI = 1:1:$ListLength(tBad) {
        Set tCode = $List(tBad, tI)
        Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, "irrelevant", tCode)
        Do $$$AssertStatusNotOK(tSC, "'" _ tCode _ "' is refused rather than rendered")
        Do $$$AssertTrue(($System.Status.GetErrorText(tSC) [ "Malformed error code"), "'" _ tCode _ "' is refused BY THE CODE GUARD, not by something downstream")
    }

    ; ...and every code the tree actually ships passes, so the guard is a filter on mistakes
    ; rather than on the vocabulary. A new code that cannot pass this is a code to rename.
    ;
    ; Read from the writer's own parameter list rather than typed here. A hand-written roster
    ; claims to cover "every code the tree ships" and silently stops being true the next time
    ; one is declared -- which had already happened: the five PORT.* codes were minted as
    ; literals in OcuPilot.Kernel.Fault and were in no list. Candidates are the parameters whose
    ; value looks like a machine code (upper case, dots and underscores admitted so a code
    ; minted WITH an underscore is still tested and still fails); the slugs are lower case and
    ; drop out, and CODEPATTERN is the guard's own regex, not a code.
    Set tChecked = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ?", "OcuPilot.Api.Error")
    While tRS.%Next() {
        Set tName = tRS.%Get("Name")
        If tName = "CODEPATTERN" Continue
        Set tCode = $Parameter("OcuPilot.Api.Error", tName)
        If '$Match(tCode, "^[A-Z][A-Z0-9._]*$") Continue
        Set tChecked = tChecked + 1
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), "declared code '" _ tName _ "' = '" _ tCode _ "' passes its own guard")
    }
    ; A sweep that found nothing would pass every row above without testing a thing.
    Do $$$AssertTrue(tChecked >= 19, "the sweep found the declared codes rather than an empty roster (found " _ tChecked _ ")")
}

/// <p>The rendered <code>code</code> is a JSON <b>string</b>, always — the second half of "never
/// a number" (AD-39). The format guard refuses a numeric code above; this pins that even a code
/// the guard admits cannot be re-typed on the way out by the serializer's own inference.</p>
/// <p>Mutation: drop the <code>"string"</code> type hint from
/// <method>OcuPilot.Api.Error.Render</method>'s <code>%Set("code", ...)</code> and this stays
/// green today (no shipped code is numeric) — which is why the guard and the hint are pinned as
/// two rows rather than one: each covers the case the other would let through.</p>
Method TestRenderedCodeIsAlwaysAJsonString()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertTrue((tBody [ """code"":""ROUTE.NOTFOUND"""), "the code is serialized quoted, never bare")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.%GetTypeOf("code"), "string", "and parses back as a string")
}

/// <p>DW-25, both halves. A failing <method>OnPreDispatch</method> comes back out of
/// <code>DispatchRequest</code> as an error status with <b>no</b> envelope written — that is
/// why this branch needed an application before it could be observed at all — and the
/// vendor's next act, <code>Http500</code>, turns exactly that status into exactly one 500
/// envelope carrying the machine code <code>INTERNAL</code>, a generic reason, and no trace
/// of the real error text. The same chain runs end to end over the wire in
/// <method>OcuPilot.Test.Wire.TestPreDispatchFailureRendersOneInternalEnvelope</method>.</p>
/// <p>Mutation: delete the <code>$$$ISERR(pSC)</code> branch from
/// <method>OcuPilot.Api.Router.ReportHttpStatusCode</method> so the status falls through to
/// the slug-derived branch, and the code assertion below goes red.</p>
Method TestPreDispatchFailureBecomesOneInternalEnvelope()
{
    Set tParams = {}
    Do tParams.%Set(##class(OcuPilot.Test.PreFault).#FAULTPARAM, 1)
    Set tDispatchSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.PreFault", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusNotOK(tDispatchSC, "a failing OnPreDispatch comes back to Page() as an error status")
    Do $$$AssertEquals(tBody, "", "DispatchRequest writes no envelope itself -- Page() is what renders one")

    Set tSC = ##class(OcuPilot.Test.Dispatch).InvokeHttp500("OcuPilot.Test.PreFault", tDispatchSC, .tRendered, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "Http500 completes")
    Do $$$AssertEquals(tHttpStatus, 500, "the failing pre-dispatch status renders as 500")
    Do ..AssertSingleEnvelope(tRendered, "pre-dispatch failure")
    Set tObj = ##class(%DynamicObject).%FromJSON(tRendered)
    Do ..AssertExactKeySet(tObj, 0, "pre-dispatch failure")
    Do $$$AssertEquals(tObj.code, "INTERNAL", "the internal branch always carries the INTERNAL code")
    Do $$$AssertEquals(tObj.reason, "An internal error occurred", "the client sees a generic reason")
    Do $$$AssertTrue((tRendered '[ "pre-dispatch fixture failure"), "the real error text is logged, never sent")
}

/// <p>DW-34: a framework status with no matching route renders a code derived from the
/// slug, never from the number. Driven through the same call
/// <code>%CSP.REST.Page()</code>'s own <code>Http403()</code> makes, so this is the
/// branch's production shape rather than a direct call to the override.</p>
/// <p>Mutation: change <method>OcuPilot.Api.Router.ReportHttpStatusCode</method>'s final
/// branch back to <code>"ROUTE." _ tStatus</code> and the code assertion below goes red
/// (<code>ROUTE.403</code>).</p>
Method TestFrameworkStatusWithNoRouteRendersASlugDerivedCode()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.PreFault", "/framework403", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 403, "the reported framework status reaches the wire as 403")
    Do ..AssertSingleEnvelope(tBody, "framework 403")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do ..AssertExactKeySet(tObj, 0, "framework 403")
    Do $$$AssertEquals(tObj.error, "forbidden", "403 renders the forbidden slug")
    Do $$$AssertEquals(tObj.code, "ROUTE.FORBIDDEN", "the code is derived from the slug")
    Do $$$AssertTrue((tObj.code '[ "403"), "and is never the status number")
}

/// <p>The slug enum is closed: an unrecognized slug is refused outright, and nothing is
/// written — calling this with no <code>%response</code> set up at all is itself proof
/// that the refusal happens before any device interaction.</p>
Method TestUnknownSlugIsRefused()
{
    Set tSC = ##class(OcuPilot.Api.Error).Render(400, "made_up", "irrelevant", "IRRELEVANT.CODE")
    Do $$$AssertStatusNotOK(tSC, "an unknown slug is refused rather than rendered")
}

/// <p>The 405 override sets the Allow header — deleting it from
/// <method>OcuPilot.Api.Error.Render405</method> is a mutation this suite (via
/// <class>OcuPilot.Test.Routing</class>'s 405 row) is expected to catch.</p>
Method TestRender405SetsAllowHeader()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/guarded", "POST", , .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tAllow, "GET", "Render405 sets the Allow header to the supported verbs")
}

/// <p>I/O matrix "Handler success" row: a fixture route returning a
/// <class>%DynamicObject</class> is written exactly once through
/// <class>OcuPilot.Api.Response</class>, and <code>%response.ContentType</code> is
/// <code>application/json</code> (mutation: delete the <code>%response.ContentType</code>
/// assignment from <method>OcuPilot.Api.Response.JSON</method> and watch this go red).</p>
Method TestHandlerSuccessWritesJsonOnceWithContentType()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/success", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "the success route returns 200")
    Do $$$AssertEquals((tBody [ "}{"), 0, "no double-write on the success path")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue($IsObject(tObj), "the success body parses as a single JSON object")
    Do $$$AssertEquals(tObj.ok, 1, "Response.JSON wrote the fixture's own payload, once")
    Do $$$AssertEquals(%response.ContentType, "application/json", "Response.JSON sets application/json on the success path")
}

}

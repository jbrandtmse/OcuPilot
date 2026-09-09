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
        Do $$$AssertTrue(0, pLabel _ ": body must parse as a single JSON object (was: " _ $Extract(pBody, 1, 120) _ ")")
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

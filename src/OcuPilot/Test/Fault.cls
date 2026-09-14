/// <p>AD-39's normalization, pinned: a vendor <class>%Status</class> becomes an OcuPilot slug,
/// a stable machine code and OcuPilot's own written reason, and its raw text reaches the log
/// and nothing else.</p>
/// <p><b>The load-bearing assertion is over the rendered envelope, not over
/// <method>OcuPilot.Kernel.Fault.Normalize</method>'s outputs.</b> A mapping that returned the
/// right three values and a writer that then put the vendor's own text on the wire would
/// satisfy every direct check of the mapping; only the body can say whether the internal detail
/// actually left the instance. The fixture route
/// <method>OcuPilot.Test.RouterFixture.VendorFaultRoute</method> runs the whole chain --
/// normalize, log, render -- and <class>OcuPilot.Test.Dispatch</class> captures the body
/// unparsed.</p>
/// <p>Needs nothing from the instance beyond a compiled class: the vendor status is minted from
/// <code>$$$ClassDoesNotExist</code> rather than provoked out of a real
/// <code>%Api.Admin.*</code> call, so no endpoint is constructed and no configuration is read.</p>
Class OcuPilot.Test.Fault Extends %UnitTest.TestCase
{

/// <p>The internal detail the fixture status carries. Chosen by this test rather than taken
/// from vendor English, so the "did it leak" assertion searches for a value that cannot be
/// reworded out from under it by a release.</p>
/// <p>A stand-in class name, not the real vendor package: AD-27 caps that dependency at
/// <class>OcuPilot.Port.AdminPort</class> however the name is spelled, and a fixture's string
/// parameter is one of the spellings <code>scripts/check-objectscript.py</code> refuses. What
/// the assertion needs is a class-shaped token that appears nowhere else, which this is.</p>
Parameter FAULTTEXT = "%Vendor.Internal.Endpoints.FaultProbe";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>The AC, both halves at once: no part of the vendor text reaches the rendered envelope,
/// and the raw text does reach the captured log line.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Fault.Normalize</method> return
/// <code>$System.Status.GetOneStatusText(pStatus, 1)</code> as <var>pReason</var> — the shape
/// that strips the domain, id and source but not an interpolated class name — and the
/// first assertion goes red with the class name in the body.</p>
Method TestVendorTextReachesTheLogAndNeverTheEnvelope()
{
    Set tParams = {}
    Do tParams.%Set("_fixtureFaultText", ..#FAULTTEXT)
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/vendor-fault", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 500, "the normalized fault renders with the status the route gave it")

    Do $$$AssertTrue((tBody '[ ..#FAULTTEXT), "the vendor class name never reaches the rendered envelope")
    Do $$$AssertTrue((tBody '[ "ERROR #"), "nor does the vendor's own error-number prefix")
    Do $$$AssertTrue((tBody '[ "5351"), "nor the internal message id")

    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "server_error", "an unmapped vendor status defaults to server_error")
    Do $$$AssertEquals(tObj.code, "INTERNAL", "and to the INTERNAL code")
    Do $$$AssertEquals(tObj.reason, "An internal error occurred", "with OcuPilot's own generic reason")

    Set tLogged = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue((tLogged [ ..#FAULTTEXT), "the raw vendor text DOES reach the log line, in full")
    Do $$$AssertTrue((tLogged [ "INTERNAL"), "and the line carries the code the client was given, so the two pair up")
}

/// <p>Each mapped row answers with its own slug, code and written reason, and none of those
/// reasons is the vendor's text.</p>
/// <p>Mutation: swap the <code>not_found</code> and <code>conflict</code> rows in
/// <method>OcuPilot.Kernel.Fault.Normalize</method> and the two rows below go red.</p>
Method TestMappedStatusesTakeTheirOwnSlugCodeAndReason()
{
    Do ..AssertMaps($$$ERROR($$$AccessDenied), "forbidden", "PORT.ACCESSDENIED")
    Do ..AssertMaps($$$ERROR($$$LoadObjectNotFound, "Thing", "id"), "not_found", "PORT.NOTFOUND")
    Do ..AssertMaps($$$ERROR($$$DeleteObjectNotFound, "Thing", "id"), "not_found", "PORT.NOTFOUND")
    Do ..AssertMaps($$$ERROR($$$IDKeyNotUnique, "Thing", "IDKEY", "id"), "conflict", "PORT.CONFLICT")
    Do ..AssertMaps($$$ERROR($$$KeyNotUnique, "Thing", "Index", "id"), "conflict", "PORT.CONFLICT")
    Do ..AssertMaps($$$ERROR($$$PropertyRequired, "Name"), "validation_failed", "PORT.VALIDATION")
    Do ..AssertMaps($$$ERROR($$$DatatypeValidationFailed, "%String", "x"), "validation_failed", "PORT.VALIDATION")
    Do ..AssertMaps($$$ERROR($$$NotImplemented), "not_implemented", "PORT.NOTIMPLEMENTED")
}

/// <p>One mapped row: the slug and code are the expected pair, the reason is non-empty and is
/// not the vendor's own text, and the code is one the error writer would accept.</p>
Method AssertMaps(pStatus As %Status, pExpectedSlug As %String, pExpectedCode As %String)
{
    Set tSC = ##class(OcuPilot.Kernel.Fault).Normalize(pStatus, .tSlug, .tCode, .tReason, .tDetail)
    Do $$$AssertStatusOK(tSC, pExpectedCode _ ": Normalize completes")
    Do $$$AssertEquals(tSlug, pExpectedSlug, pExpectedCode _ ": slug")
    Do $$$AssertEquals(tCode, pExpectedCode, pExpectedCode _ ": code")
    Do $$$AssertNotEquals(tReason, "", pExpectedCode _ ": a written reason is always supplied")
    Do $$$AssertNotEquals(tReason, tDetail, pExpectedCode _ ": the reason is OcuPilot's own, never the vendor's stripped text")
    Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), pExpectedCode _ ": the code passes the writer's own format guard")
}

/// <p><method>OcuPilot.Kernel.Fault.Outcome</method> maps the HTTP status first: 403, 404, 409,
/// 400 and 422 each take their own code even under an OK status. An unmapped HTTP status takes
/// <method>OcuPilot.Kernel.Fault.Normalize</method>'s answer for an error status, and the internal
/// default for an OK one.</p>
Method TestOutcomeMapsTheHttpStatusFirstThenFallsBackToNormalize()
{
    Do ..AssertOutcome(403, $$$OK, "forbidden", "PORT.ACCESSDENIED")
    Do ..AssertOutcome(404, $$$OK, "not_found", "PORT.NOTFOUND")
    Do ..AssertOutcome(409, $$$OK, "conflict", "PORT.CONFLICT")
    Do ..AssertOutcome(400, $$$OK, "validation_failed", "PORT.VALIDATION")
    Do ..AssertOutcome(422, $$$OK, "validation_failed", "PORT.VALIDATION")
    Do ..AssertOutcome(404, $$$ERROR($$$AccessDenied), "not_found", "PORT.NOTFOUND")
    Do ..AssertOutcome(500, $$$ERROR($$$LoadObjectNotFound, "Thing", "id"), "not_found", "PORT.NOTFOUND")
    Do ..AssertOutcome(500, $$$ERROR($$$IDKeyNotUnique, "Thing", "IDKEY", "id"), "conflict", "PORT.CONFLICT")
    Do ..AssertOutcome(500, $$$OK, "server_error", "INTERNAL")
}

Method AssertOutcome(pHttp As %Integer, pStatus As %Status, pExpectedSlug As %String, pExpectedCode As %String)
{
    Set tWhat = "HTTP " _ pHttp _ ($Select($$$ISERR(pStatus): " with an error status", 1: " with an OK status"))
    Set tSC = ##class(OcuPilot.Kernel.Fault).Outcome(pHttp, pStatus, .tFault, .tDetail)
    Do $$$AssertStatusOK(tSC, tWhat _ ": Outcome completes")
    Do $$$AssertTrue($IsObject(tFault), tWhat _ ": a fault is built")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.error, pExpectedSlug, tWhat _ ": slug")
    Do $$$AssertEquals(tFault.code, pExpectedCode, tWhat _ ": code")
    Do $$$AssertNotEquals(tFault.reason, "", tWhat _ ": a written reason")
}

/// <p>An unmapped status takes the declared defaults rather than a nearby-looking slug —
/// a failure OcuPilot cannot describe is never dressed as one it can, and never blamed on the
/// caller.</p>
Method TestUnmappedStatusDefaultsToServerErrorAndInternal()
{
    Set tSC = ##class(OcuPilot.Kernel.Fault).Normalize($$$ERROR($$$GeneralError, "something the table has no row for"), .tSlug, .tCode, .tReason, .tDetail)
    Do $$$AssertStatusOK(tSC, "Normalize completes for an unmapped status")
    Do $$$AssertEquals(tSlug, "server_error", "the default slug is the most conservative of the twelve")
    Do $$$AssertEquals(tCode, "INTERNAL", "and the default code is the one RenderInternal renders")
    Do $$$AssertEquals(tReason, "An internal error occurred", "with the same generic reason")
    Do $$$AssertTrue((tReason '[ "something the table has no row for"), "the caller's own text is not echoed back either")
}

/// <p>Normalizing a success is a programming error, refused loudly rather than answered with a
/// plausible-looking <code>server_error</code> that would hide the call site that did it.</p>
Method TestNormalizingAnOkStatusIsRefused()
{
    Set tSC = ##class(OcuPilot.Kernel.Fault).Normalize($$$OK, .tSlug, .tCode, .tReason, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "an OK status is refused")
    Do $$$AssertEquals(tDetail, "", "and nothing is derived from it")
}

/// <p>Every slug the table can produce is one <class>OcuPilot.Api.Error</class> will actually
/// render, and every code passes its format guard — so a normalized fault can never be refused
/// by the one writer it exists to feed.</p>
/// <p>Mutation: change any row's slug to a plausible-but-unlisted value (<code>"notfound"</code>
/// for <code>"not_found"</code>) and this goes red, where a direct string comparison in the
/// mapping test above would still pass.</p>
Method TestEverySlugTheTableProducesIsOneTheWriterAccepts()
{
    Set tStatuses = $ListBuild($$$ERROR($$$AccessDenied), $$$ERROR($$$LoadObjectNotFound, "T", "i"), $$$ERROR($$$IDKeyNotUnique, "T", "K", "i"), $$$ERROR($$$PropertyRequired, "N"), $$$ERROR($$$NotImplemented), $$$ERROR($$$GeneralError, "unmapped"))
    For tI = 1:1:$ListLength(tStatuses) {
        Set tStatus = $List(tStatuses, tI)
        Do ##class(OcuPilot.Kernel.Fault).Normalize(tStatus, .tSlug, .tCode, .tReason, .tDetail)
        ; Render is what actually closes the enum: it refuses an unknown slug outright, and it
        ; is called here with no %response, so a slug it accepted would fail on the Write
        ; instead -- either way a wrong slug cannot pass silently.
        Set tRenderSC = ##class(OcuPilot.Api.Error).Render(500, tSlug, tReason, tCode)
        Do $$$AssertTrue(($System.Status.GetErrorText(tRenderSC) '[ "Unknown error slug"), "row " _ tI _ ": '" _ tSlug _ "' is in the writer's closed enum")
        Do $$$AssertTrue(($System.Status.GetErrorText(tRenderSC) '[ "Malformed error code"), "row " _ tI _ ": '" _ tCode _ "' passes the writer's format guard")
    }
}

}

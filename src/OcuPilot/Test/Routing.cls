/// <p>Behavioral assertions for every routing row in the story's I/O matrix, dispatched
/// through <class>OcuPilot.Test.Dispatch</class> against <class>OcuPilot.Test.RouterFixture</class>:
/// the framework 404 and 405 overrides, each of the three route-ordering invariants,
/// pre-dispatch identity denial, namespace resolution and rejection, and the entity-id
/// single- and double-encoded routing rows.</p>
Class OcuPilot.Test.Routing Extends %UnitTest.TestCase
{

/// <p>Integration AC: dispatch at an unmapped path produces the framework-404 path,
/// which reads from <class>OcuPilot.Api.Error</class> — never IRIS's own HTML error page,
/// never a second body.</p>
/// <p>The bare root is the one path guaranteed to match no route in this fixture,
/// including <code>/:resource</code>: that catch-all's wildcard requires at least one
/// character after the leading slash, which <code>/</code> alone never supplies — every
/// other path, of any segment count, fullmatches it (its capture group is not restricted
/// from spanning an embedded <code>/</code>) and is a 405 (verb mismatch) rather than a
/// 404 (no route at all).</p>
Method TestUnmappedPathReturns404()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch of an unmapped path completes")
    Do $$$AssertEquals(tStatus, 404, "unmapped path returns 404")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "not_found", "the framework 404 renders through Api.Error")
    Do $$$AssertEquals(tObj.code, "ROUTE.NOTFOUND", "the framework 404 carries the ROUTE.NOTFOUND code")
}

/// <p>A mapped route with an unsupported verb renders the framework's automatic
/// <method>Http405</method> override (never the default), naming the supported verbs in
/// the Allow header. Uses DELETE — a verb neither <code>/ping</code> nor the
/// <code>/:resource</code> catch-all declares — so this exercises the genuine
/// "no exact match, but some pattern matched" fallback inside <code>DispatchRequest</code>
/// itself, rather than an explicit guard route. The catch-all's own wildcard also matches
/// <code>/ping</code>'s pattern (see the note above), so the reported Allow set is the
/// union of both routes' verbs — checked by containment, not exact equality, since that
/// union is itself the correct, honest behavior being pinned here.</p>
Method TestMappedRouteWrongVerbReturns405WithAllow()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "DELETE", , .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch of a wrong-verb request completes")
    Do $$$AssertEquals(tStatus, 405, "a wrong verb on a mapped route returns 405")
    Do $$$AssertTrue((tAllow [ "GET"), "the 405 response's Allow header names /ping's own supported verb")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "method_not_allowed", "the 405 renders through Api.Error")
    Do $$$AssertEquals(tObj.code, "ROUTE.METHODNOTALLOWED", "the 405 carries the ROUTE.METHODNOTALLOWED code")
}

/// <p>Ordering invariant 1: the explicit 405 guard at <code>/guarded</code> POST is
/// checked before the <code>/:resource</code> catch-all, so POST is refused rather than
/// silently "creating" a resource named "guarded".</p>
Method TestOrderingGuardBeforeCatchAll()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/guarded", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "GET /guarded completes")
    Do $$$AssertEquals(tStatus, 200, "GET /guarded succeeds")

    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/guarded", "POST", , .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "POST /guarded completes")
    Do $$$AssertEquals(tStatus, 405, "the explicit guard intercepts POST /guarded before the /:resource catch-all")
    Do $$$AssertEquals(tAllow, "GET", "the guard names GET as the only supported verb")
}

/// <p>Ordering invariant 2: the literal sub-resource <code>/items/current</code> is
/// checked before the wildcard <code>/items/:id</code>, so "current" resolves to the
/// sub-resource handler rather than being captured as an id.</p>
Method TestOrderingSubResourceBeforeParam()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/items/current", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "GET /items/current completes")
    Do $$$AssertEquals(tStatus, 200, "GET /items/current succeeds")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tObj.%IsDefined("current"), "the literal sub-resource route wins, not GetItem(id=""current"")")
}

/// <p>Ordering invariant 3: the 3-segment <code>/docs/:id/history</code> is checked
/// before the 2-segment <code>/docs/:id</code>, whose wildcard could otherwise capture
/// the embedded "/history" segment as part of the id.</p>
Method TestOrderingNSegmentBeforeNMinus1()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/docs/42/history", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "GET /docs/42/history completes")
    Do $$$AssertEquals(tStatus, 200, "GET /docs/42/history succeeds")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tObj.%IsDefined("history"), "the 3-segment route wins over the 2-segment /docs/:id wildcard")
    Do $$$AssertEquals(tObj.id, "42", "the 3-segment route's own :id capture is exactly the first segment")
}

/// <p>Pre-dispatch denial: an unauthenticated placeholder identity is rejected before
/// any route runs, through the one error writer, with $NAMESPACE left unchanged.</p>
Method TestPreDispatchDenialRejectsUnknownUser()
{
    Set tNsBefore = $Namespace
    Set tParams = {"_fixtureUser": ("UnknownUser")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 401, "UnknownUser is denied at pre-dispatch")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "unauthorized", "the denial renders through Api.Error")
    Do $$$AssertEquals(tObj.code, "AUTH.ANONYMOUS", "the denial names the AUTH.ANONYMOUS code")
    Do $$$AssertEquals($Namespace, tNsBefore, "$NAMESPACE is unchanged by a pre-dispatch denial")
}

/// <p>Same denial for the other unauthenticated placeholder.</p>
Method TestPreDispatchDenialRejectsPublic()
{
    Set tParams = {"_fixtureUser": ("_PUBLIC")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 401, "_PUBLIC is denied at pre-dispatch")
}

/// <p>An absent <code>?ns=</code> resolves to the namespace already in effect (the
/// install namespace) without ever denying the request.</p>
Method TestNamespaceDefaultsToInstallNamespaceWhenAbsent()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "an absent ?ns= resolves to the install namespace and never denies")
}

/// <p>An unknown namespace is rejected with the NS.UNKNOWN code, and $NAMESPACE is
/// never touched to perform the check.</p>
Method TestNamespaceRejectsUnknownValue()
{
    Set tNsBefore = $Namespace
    Set tParams = {"ns": ("NOSUCHNS12345")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 400, "an unknown namespace is rejected")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "bad_request", "the rejection renders through Api.Error")
    Do $$$AssertEquals(tObj.code, "NS.UNKNOWN", "the rejection names the NS.UNKNOWN code")
    Do $$$AssertEquals($Namespace, tNsBefore, "$NAMESPACE is unchanged by namespace validation")
}

/// <p>An explicit ?ns= naming the namespace already in effect is accepted.</p>
Method TestNamespaceAcceptsCurrentValueExplicitly()
{
    Set tParams = {"ns": ($Namespace)}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "the current namespace named explicitly is accepted")
}

/// <p>Entity id, single segment: every corpus id round-trips through the wire, not just
/// through the codec directly — the fixture's <code>:id</code> route decodes exactly
/// once and the response echoes the original byte-for-byte.</p>
Method TestEntityIdSingleSegmentRoundTripsThroughTheRoute()
{
    Set tCorpus = $ListBuild("_SYSTEM", "a/b", "a b", "100%", "café", "x?y", "#frag")
    For i=1:1:$ListLength(tCorpus) {
        Set tOriginal = $List(tCorpus, i)
        Set tEncoded = ##class(OcuPilot.Kernel.EntityId).Encode(tOriginal)
        Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/items/" _ tEncoded, "GET", , .tBody, .tStatus)
        Do $$$AssertStatusOK(tSC, "dispatch of /items/" _ tEncoded _ " completes")
        Do $$$AssertEquals(tStatus, 200, "encoded id " _ tEncoded _ " routes to GetItem")
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tObj.id, tOriginal, "the handler's single Decode() call recovers " _ tOriginal)
    }
}

/// <p>Entity id, double-encoded: a segment that already reads <code>%2520</code> must
/// decode to the literal string <code>%20</code>, not to a space — a second decode is
/// the specific defect this row exists to catch (mutation: apply
/// <method>OcuPilot.Kernel.EntityId.Decode</method> a second time in the fixture's
/// wrapper and watch this assertion go red).</p>
Method TestDoubleEncodedSegmentIsDecodedExactlyOnce()
{
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/items/%2520", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "GET /items/%2520 succeeds")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.id, "%20", "a single decode of %2520 yields the literal string %20, not a space")
}

}

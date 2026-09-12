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

/// <p><b>DW-33</b> -- the resolved namespace is not dropped on the floor: it is stashed in
/// <class>OcuPilot.Kernel.Scope</class>, where a handler reads it back, and resolving it switches
/// nothing.</p>
/// <p>Mutation: delete the <method>OcuPilot.Kernel.Scope.Set</method> call from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> the stash assertion goes red with the
/// install namespace, which is the value the whole defect hid behind.</p>
Method TestTheResolvedNamespaceIsStashedForHandlersToRead()
{
    Set tNsBefore = $Namespace
    Set tOther = "%SYS"
    Do $$$AssertNotEquals(tOther, tNsBefore, "the requested namespace is not the one in effect")

    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tParams = {"ns": (tOther)}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "a namespace the caller may enter is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Scope).Current(), tOther, "and the request's scope is readable by a handler")
    Do $$$AssertEquals($Namespace, tNsBefore, "while $NAMESPACE is unchanged -- the scope is a value, not a switch")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>An absent <code>?ns=</code> stashes the namespace already in effect, so a handler reads the
/// same answer whether or not the client named one.</p>
Method TestAnAbsentNamespaceStashesTheOneInEffect()
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "an absent ?ns= never denies")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Scope).Current(), $Namespace, "and the install namespace is what a handler reads")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p><b>DW-8</b> -- a namespace that exists and that the caller may not enter is a 403 naming
/// the <code>(resource, permission)</code> pair that failed, and nothing is stashed: a refused
/// request leaves no scope behind for a later one on the same process to read.</p>
/// <p>The refusal is driven through <class>OcuPilot.Test.RouterFixture</class>'s own seam, since
/// <code>%UnitTest</code> holds <code>%All</code> and the real check admits every namespace here.
/// <class>OcuPilot.Test.Wire</class> observes the real refusal over the wire.</p>
/// <p>Mutation: delete the <method>OcuPilot.Api.Router.MayEnterNamespace</method> block from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> this answers 200 and every assertion
/// goes red.</p>
Method TestANamespaceTheCallerCannotEnterIsRefusedWithItsFailedPair()
{
    Set tNsBefore = $Namespace
    Set tOther = "%SYS"
    Do $$$AssertTrue(##class(OcuPilot.Api.Namespaces).GlobalDatabase(tOther, .tResource, .tReadOnly), "the target namespace reports a guarding resource")

    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tParams = {"ns": (tOther), "_fixtureDenyNs": (tOther)}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 403, "a namespace the caller may not enter is refused")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "forbidden", "the refusal renders through Api.Error")
    Do $$$AssertEquals(tObj.code, "NS.DENIED", "with the machine code the shell reads")
    Do $$$AssertEquals(tObj.detail.failedPair, tResource _ ":READ", "and the failed pair in detail")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Scope).Current(), tNsBefore, "a refused request stashes nothing")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>The unknown-namespace refusal stays a 400 and is told apart from the 403 above by its code:
/// one means "no such namespace", the other "not yours", and a client that read one for the other
/// would offer the wrong recovery.</p>
Method TestAnUnknownNamespaceAndADeniedOneCarryDifferentCodes()
{
    Set tUnknown = {"ns": ("NOSUCHNS12345")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tUnknown, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 400, "an unknown namespace is a bad request")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.code, ##class(OcuPilot.Api.Error).#NSUNKNOWN, "carrying the unknown-namespace code")
    Do $$$AssertEquals(''tObj.%IsDefined("detail"), 0, "with no detail -- the caller supplied the value and nothing is added to it")

    Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).#NSUNKNOWN, ##class(OcuPilot.Api.Error).#NSDENIED, "the two refusals are told apart by their codes")
}

/// <p>A percent-encoded <code>?ns=</code> resolves to the namespace it spells: the framework
/// decodes a query parameter once in transit, and the entity-id codec -- which encodes twice
/// because a path segment survives a different trip -- is not involved.</p>
Method TestAPercentEncodedNamespaceResolves()
{
    Set tNsBefore = $Namespace
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    ; What the framework hands OnPreDispatch for "?ns=%25SYS": one decode has already happened.
    Set tParams = {"ns": ("%SYS")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "a namespace whose name carries a percent sign is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Scope).Current(), "%SYS", "and is stashed with its name intact")
    Do $$$AssertEquals($Namespace, tNsBefore, "with $NAMESPACE unchanged")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>One namespace is one scope: <method>%SYS.Namespace.Exists</method> answers yes to
/// <code>user</code>, <code>USER</code> and <code>UsEr</code> alike (probed on this instance), so
/// the gate canonicalises before it stashes. Without that the shell's roster -- which carries the
/// instance's own spelling -- would read a lowercase route as a namespace the caller may not
/// enter, and two reference keys would name one entity (AD-13).</p>
Method TestANamespaceNamedInAnotherCaseResolvesToOneScope()
{
    Set tNsBefore = $Namespace
    Do $$$AssertTrue(##class(%SYS.Namespace).Exists("user"), "the instance answers Exists() for a lowercase spelling")

    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tParams = {"ns": ("user")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/ping", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "a namespace named in another case is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Scope).Current(), "USER", "and is stashed in the instance's own spelling")
    Do $$$AssertEquals($Namespace, tNsBefore, "with $NAMESPACE unchanged")
    Do ##class(OcuPilot.Kernel.Scope).Clear()

    ; An implicit namespace is a directory path, whose case is the file system's, so it is left
    ; exactly as it came.
    Do $$$AssertEquals(##class(OcuPilot.Api.Router).CanonicalNamespace("^^/durable/iris/mgr/"), "^^/durable/iris/mgr/", "an implicit namespace is not uppercased")
}

/// <p>Entity id, single segment: every corpus id reaches the fixture's <code>:id</code>
/// route as one segment, is decoded exactly once, and is echoed back byte for byte.</p>
/// <p><b>The URL carries what the server delivers, not what the client sends</b> (DW-31,
/// settled in Story 1.5). <method>OcuPilot.Kernel.EntityId.Encode</method> encodes twice
/// because the front web server consumes one decoding in transit, and this harness calls
/// <code>DispatchRequest</code> directly, with no web server in front of it -- so the
/// segment built here is passed through <method>OcuPilot.Test.EntityId.ServerDecode</method>
/// first, which is that hop's model. The unmodelled trip is asserted for real, over a live
/// web application, by
/// <method>OcuPilot.Test.Wire.TestEntityIdCorpusSurvivesTheRealWire</method>.</p>
Method TestEntityIdSingleSegmentRoundTripsThroughTheRoute()
{
    Set tCorpus = ##class(OcuPilot.Test.EntityId).Corpus()
    For i=1:1:$ListLength(tCorpus) {
        Set tOriginal = $List(tCorpus, i)
        Set tDelivered = ##class(OcuPilot.Test.EntityId).ServerDecode(##class(OcuPilot.Kernel.EntityId).Encode(tOriginal))
        Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/items/" _ tDelivered, "GET", , .tBody, .tStatus)
        Do $$$AssertStatusOK(tSC, "dispatch of corpus row " _ i _ " completes")
        Do $$$AssertEquals(tStatus, 200, "corpus row " _ i _ " routes to GetItem as one segment")
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tObj.id, tOriginal, "the handler's single Decode() call recovers corpus row " _ i)
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

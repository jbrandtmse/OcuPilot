/// <p>Test-only <class>OcuPilot.Api.Router</class> subclass. The production
/// <code>UrlMap</code> carries only routes the product needs, and none of them collide, so
/// it cannot demonstrate the ordering invariants at all; this fixture supplies route pairs
/// built to collide if the ordering were wrong, which is what lets
/// <class>OcuPilot.Test.Routing</class> and
/// <class>OcuPilot.Test.Envelope</class> exercise the real, inherited
/// <method>OnPreDispatch</method>, <method>ReportHttpStatusCode</method> and
/// <method>Http405</method> behaviourally, and demonstrate each of the three route-ordering
/// invariants.</p>
Class OcuPilot.Test.RouterFixture Extends OcuPilot.Api.Router
{

/// <p>Overrides <class>OcuPilot.Api.Router</class>'s default (<code>$Username</code>) so a
/// test can drive the pre-dispatch identity check with a fixture value, via the
/// <code>_fixtureUser</code> query parameter — <method>OcuPilot.Test.Dispatch.Invoke</method>'s
/// <var>pParams</var>. Falls back to the real <code>$Username</code> when the caller does
/// not set it, so a plain dispatch behaves like production.</p>
ClassMethod ResolvedUsername() As %String
{
    Quit %request.Get("_fixtureUser", $Username)
}

/// <p>Overrides <class>OcuPilot.Api.Router</class>'s namespace entry check so a test can drive
/// its denial branch, via the <code>_fixtureDenyNs</code> query parameter: a request naming that
/// namespace in <code>?ns=</code> is refused with the pair the real check would have named.
/// Falls back to the real check when the caller does not set it, so a plain dispatch behaves
/// like production -- the same fallback shape <method>ResolvedUsername</method> uses.</p>
/// <p>The seam is needed because <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every namespace on the instance.
/// <class>OcuPilot.Test.Wire</class> observes the real refusal over the wire.</p>
ClassMethod MayEnterNamespace(pNamespace As %String, Output pFailedPair As %String) As %Boolean
{
    Set tDenied = %request.Get("_fixtureDenyNs", "")
    If (tDenied '= "") && (tDenied = pNamespace) {
        Set pFailedPair = ""
        If ##class(OcuPilot.Api.Namespaces).GlobalDatabase(pNamespace, .tResource, .tReadOnly) {
            Set pFailedPair = tResource _ ":" _ ##class(OcuPilot.Api.Namespaces).#READPERMISSION
        }
        Quit 0
    }
    Quit ##super(pNamespace, .pFailedPair)
}

/// <p>Ordering invariant 1 (explicit 405 method guard before the catch-all): <code>/guarded</code>
/// POST must be intercepted by <method>Handle405Guarded</method> here, never reaching
/// <code>/:resource</code> POST below — which would otherwise treat "guarded" as a
/// resource name and wrongly "create" it. A plain GET-only route (<code>/ping</code>)
/// covers the 405+Allow behavior on its own for the case with no such hazard.</p>
/// <p>Ordering invariant 2 (sub-resource before single-segment <code>:param</code>):
/// <code>/items/current</code> must be checked before <code>/items/:id</code>, or the
/// wildcard would swallow "current" as an id. <code>/items/:id</code> doubles as the
/// single-segment id route the entity-id corpus test dispatches through.</p>
/// <p>Ordering invariant 3 (N-segment before (N-1)-segment): <code>/docs/:id/history</code>
/// is 3 segments and is listed before the 2-segment <code>/docs/:id</code>, as the convention
/// requires.</p>
/// <p><code>/screens/:screen/read</code> is the production screen-read route's shape, dispatched to
/// <class>OcuPilot.Test.Read.ScreenReadFixture</class> so its matrix rows run over fixture
/// descriptors and a fixture port.</p>
/// <p><code>/:resource</code> is kept deliberately last: every route above must be checked
/// first, or this single-segment catch-all silently swallows it.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/screens/:screen/read" Method="GET" Call="ScreenReadRoute" />
  <Route Url="/guarded" Method="GET" Call="GuardedRoute" />
  <Route Url="/guarded" Method="POST" Call="Handle405Guarded" />
  <Route Url="/ping" Method="GET" Call="PingRoute" />
  <Route Url="/items/current" Method="GET" Call="ItemsCurrent" />
  <Route Url="/items/:id" Method="GET" Call="GetItem" />
  <Route Url="/docs/:id/history" Method="GET" Call="DocHistory" />
  <Route Url="/docs/:id" Method="GET" Call="GetDoc" />
  <Route Url="/success" Method="GET" Call="SuccessRoute" />
  <Route Url="/parse" Method="POST" Call="NestedCatchRoute" />
  <Route Url="/boom" Method="GET" Call="ThrowingRoute" />
  <Route Url="/detailed" Method="GET" Call="DetailedError" />
  <Route Url="/instance-fault" Method="GET" Call="InstanceFaultRoute" />
  <Route Url="/vendor-fault" Method="GET" Call="VendorFaultRoute" />
  <Route Url="/agent-definitions/:id/test" Method="POST" Call="AgentDefinitionTestRoute" />
  <Route Url="/agent-definitions/:id/credential" Method="POST" Call="AgentDefinitionCredentialRoute" />
  <Route Url="/agent-switches-stale" Method="PUT" Call="AgentSwitchesStaleRoute" />
  <Route Url="/:resource" Method="POST" Call="CreateResource" />
</Routes>
}

/// <p>The screen-read route over <class>OcuPilot.Test.Read.ScreenReadFixture</class>.</p>
ClassMethod ScreenReadRoute(pScreen As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Read.ScreenReadFixture).Handle(pScreen)
}

/// <p>Success route for <code>/guarded</code> GET — a plain envelope-free 200.</p>
ClassMethod GuardedRoute() As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSON({"guarded": (1)})
}

/// <p>Explicit method guard: <code>/guarded</code> POST is not supported, and this route
/// exists only to say so before the <code>/:resource</code> catch-all ever gets a chance.</p>
ClassMethod Handle405Guarded() As %Status
{
    Quit ##class(OcuPilot.Api.Error).Render405("GET")
}

/// <p>Plain GET-only success route, also the mapped-route-wrong-verb fixture: POST here
/// hits no explicit guard, so it falls through to <code>%CSP.REST</code>'s own 405 path.</p>
ClassMethod PingRoute() As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSON({"pong": (1)})
}

/// <p>Literal sub-resource that must win over <code>/items/:id</code> below for the
/// literal path "current".</p>
ClassMethod ItemsCurrent() As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSON({"current": (1)})
}

/// <p>The fixture's single-segment <code>:id</code> route. Decodes <var>pId</var> through
/// <class>OcuPilot.Kernel.EntityId</class>'s one shared decode point exactly once and
/// echoes the decoded value — this is what the entity-id corpus test (including its
/// double-encoded row) asserts against.</p>
ClassMethod GetItem(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDecoded = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Do ##class(OcuPilot.Api.Response).JSON({"id": (tDecoded)})
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>3-segment route that must win over the 2-segment <code>/docs/:id</code> below for
/// any id whose "history" sub-path is requested.</p>
ClassMethod DocHistory(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSON({"history": (1), "id": (pId)})
}

/// <p>2-segment fallback, listed after its 3-segment sibling above.</p>
ClassMethod GetDoc(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSON({"id": (pId)})
}

/// <p>Plain success route used for the "handler success" I/O-matrix row.</p>
ClassMethod SuccessRoute() As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSON({"ok": (1)})
}

/// <p>Demonstrates AD-12's nested-<code>Catch</code> rule: the inner <code>Try</code>
/// deliberately fails to parse, and its <code>Catch</code> returns
/// <code>Return $$$OK</code> — never a bare <code>Quit</code> — immediately after rendering
/// the one envelope. A bare <code>Quit</code> there would fall through to the line below
/// and write a second envelope after the first, which is exactly the <code>}{</code> defect
/// class this route exists to guard against.</p>
ClassMethod NestedCatchRoute() As %Status
{
    Set tSC = $$$OK
    Try {
        Try {
            Set tParsed = ##class(%DynamicObject).%FromJSON("not-valid-json")
        } Catch exInner {
            Do ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, "Malformed request body", "REQUEST.BADJSON")
            Return $$$OK
        }
        Do ##class(OcuPilot.Api.Response).JSON({"parsed": (1)})
    } Catch exOuter {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", exOuter)
    }
    Quit tSC
}

/// <p>Demonstrates the "unhandled internal exception" row: an unexpected
/// <code>&lt;UNDEFINED&gt;</code> is caught by this route's own (single-level, non-nested)
/// <code>Try</code>/<code>Catch</code> and rendered as a generic 500 via
/// <method>OcuPilot.Api.Error.RenderInternal</method>, which is what actually splits the
/// logged detail from the client-facing reason. The other, simpler fixture routes below
/// carry no per-route <code>Try</code>/<code>Catch</code> of their own — AD-12's "one
/// envelope" guarantee still holds for them over the wire, but <b>not</b> by the route
/// most readers assume. <code>%CSP.REST.DispatchRequest</code>'s outer
/// <code>Try</code>/<code>Catch</code> (<code>irislib/%CSP/REST.cls:415-419</code>) does
/// <b>not</b> call <method>ReportHttpStatusCode</method> — it is exactly
/// <code>Catch (e) { Set sc = e.AsStatus() }</code> followed by <code>Return sc</code>.
/// The envelope comes one level up, in <code>%CSP.REST.Page()</code>
/// (<code>irislib/%CSP/REST.cls:205-210</code>): <code>If $$$ISERR(tSC) Do ..Http500(...)</code>,
/// and <code>Http500</code> (<code>:493</code>) is
/// <code>..ReportHttpStatusCode(..#HTTP500INTERNALSERVERERROR, pE.AsStatus())</code>,
/// which dispatches to <b>this</b> class's override and takes its
/// <code>$$$ISERR(pSC)</code> branch.</p>
/// <p>The consequence for testing: <class>OcuPilot.Test.Dispatch</class> calls
/// <method>DispatchRequest</method> directly and never runs <code>Page()</code>, so that
/// 500 path is <b>not</b> exercised in-process — an exception escaping a handler under
/// the harness yields an empty body and status 0, not an envelope. Story 1.5, which
/// creates the web applications, is where it first runs for real (ledger DW-25).
/// This route's own explicit <code>Try</code>/<code>Catch</code> is therefore the only
/// in-story evidence for the I/O-matrix row it names.</p>
ClassMethod ThrowingRoute() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tValue = tOcuPilotFixtureNeverAssigned + 1
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The generic single-segment catch-all, kept last in the <code>UrlMap</code> above.
/// Exists only to be a hazard the more specific routes above must out-rank.</p>
ClassMethod CreateResource(pResource As %String) As %Status
{
    Quit ##class(OcuPilot.Api.Response).JSONStatus(201, {"created": (pResource)})
}

/// <p>The one fixture route that supplies a structured <code>detail</code> object, so
/// <class>OcuPilot.Test.Envelope</class> can assert the four-key shape as well as the
/// three-key one.</p>
ClassMethod DetailedError() As %Status
{
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, "Validation failed", "REQUEST.VALIDATION", {"fields": ["name"]})
}

/// <p>DW-120 -- dispatches to <class>OcuPilot.Test.InstanceFixture</class>'s inherited
/// <method>Handle</method> rather than to <class>OcuPilot.Api.Instance</class> directly.
/// The production <code>/instance</code> route in <class>OcuPilot.Api.Router</class> names
/// the real handler class by a hardcoded <code>##class(...)</code> call and cannot be
/// pointed at a fixture, so this route exists to give
/// <method>OcuPilot.Test.InstanceFixture.SetVerificationThrows</method> a dispatch path
/// with real output capture (<class>OcuPilot.Test.Dispatch</class>).</p>
ClassMethod InstanceFaultRoute() As %Status
{
    Quit ##class(OcuPilot.Test.InstanceFixture).Handle()
}

/// <p>DW-360 -- dispatches to <class>OcuPilot.Test.DefinitionsProbe</class>'s inherited
/// <method>OcuPilot.Api.Definitions.HandleTest</method> rather than to
/// <class>OcuPilot.Api.Definitions</class> directly, the same shape
/// <method>InstanceFaultRoute</method> uses for DW-120: the production
/// <code>/agent/definitions/:id/test</code> route names the real handler class by a hardcoded
/// <code>##class(...)</code> call and cannot be pointed at a fixture, so this route gives
/// <class>OcuPilot.Test.AgentConnection</class> a dispatch path with real output capture
/// (<class>OcuPilot.Test.Dispatch</class>) that runs the literal, inherited
/// <method>HandleTest</method> / <method>ConnectionOutcome</method> body -- the gate, the
/// merge, the validation and the write through <code>Api.Response.JSON</code> -- with the
/// probe's port, catalog and secret seams substituted underneath it.</p>
ClassMethod AgentDefinitionTestRoute(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Test.DefinitionsProbe).HandleTest(pId)
}

/// <p>The credential store, through the same fixture dispatch and for the same reason: the
/// shipped <code>/agent/definitions/:id/credential</code> route names the real handler by a
/// hardcoded <code>##class(...)</code> call, and two of that handler's branches -- the key
/// stored and the definition gone, and the re-read after the clear answering nothing -- are
/// reachable only with the probe's credential and open seams substituted underneath the
/// literal, inherited <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> body.</p>
ClassMethod AgentDefinitionCredentialRoute(pId As %String) As %Status
{
    Quit ##class(OcuPilot.Test.DefinitionsProbe).HandleStoreCredential(pId)
}

/// <p>The switches update with a second writer inside it
/// (<class>OcuPilot.Test.SwitchesStaleProbe</class>), which is the only way to observe the
/// conditional write's 409 through a dispatch: the window it closes opens and closes inside one
/// request, and no version token crosses the wire for a second request to carry.</p>
/// <p>The handler body, the version read, the validation, the conditional save and the envelope are
/// the literal, inherited ones.</p>
ClassMethod AgentSwitchesStaleRoute() As %Status
{
    Quit ##class(OcuPilot.Test.SwitchesStaleProbe).HandleUpdate()
}

/// <p>The AD-39 normalization row, end to end: a vendor-shaped <class>%Status</class> carrying
/// an internal class name and a message id crosses
/// <method>OcuPilot.Kernel.Fault.Normalize</method>, the result is rendered through the one
/// error writer, and the raw text is handed to the log through
/// <class>OcuPilot.Test.FaultProbe</class>.</p>
/// <p>A route rather than a direct call because the claim is about <b>the rendered
/// envelope</b>: asserting on <method>Normalize</method>'s own outputs would prove the mapping
/// and leave "no vendor text reaches the wire" unexercised, which is the half that matters.
/// The vendor status is minted here rather than taken from a live
/// <code>%Api.Admin.*</code> failure so the test is deterministic and asks the instance for
/// nothing (AD-27's dependency stays inside the port).</p>
/// <p>The <code>_fixtureFaultText</code> query parameter supplies the internal detail the
/// status carries, so the assertion can search the body for a value the test itself chose
/// rather than for a substring of vendor English that a release could reword.</p>
ClassMethod VendorFaultRoute() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDetail = %request.Get("_fixtureFaultText", "%Vendor.Internal.Endpoints.Session")
        Set tVendor = $$$ERROR($$$ClassDoesNotExist, tDetail)
        Set tSC = ##class(OcuPilot.Test.FaultProbe).Normalize(tVendor, .tSlug, .tCode, .tReason, .tFaultDetail)
        If $$$ISERR(tSC) Quit
        ; The raw text goes to the log, and only to the log -- the point of the split.
        Do ##class(OcuPilot.Test.FaultProbe).LogRaw("port", "vendor call failed", tVendor, tCode)
        Set tSC = ##class(OcuPilot.Api.Error).Render(500, tSlug, tReason, tCode)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}

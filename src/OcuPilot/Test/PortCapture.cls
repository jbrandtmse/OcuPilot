/// <p>An <class>OcuPilot.Port.AdminPort</class> call cannot open its capture inside one that is
/// already holding output (AD-2 step 6). The opposite direction -- MgmntPort as the inner port --
/// is <class>OcuPilot.Test.MgmntPort</class>'s own nesting leg. The vendor's
/// <code>BeginCapture</code> refuses only once the outer capture <b>holds output</b>
/// (<file>irislib/%SYS/Capture.int</file>), so an <class>OcuPilot.Port.AdminPort</class> call made
/// from inside <class>OcuPilot.Port.MgmntPort</class>'s capture window is an internal fault and no
/// vendor endpoint runs -- while the outer port's own collected output survives to reach its log
/// line.</p>
/// <p>Why it matters: a vendor endpoint that ran outside a capture would write its device output
/// into whatever response the outer call is composing, which is the corruption AD-12's envelope
/// invariant exists to prevent.</p>
/// <p>Runs through <class>OcuPilot.Test.MgmntPortFixture</class> over
/// <class>OcuPilot.Test.MgmntImplFixture</class>'s <code>admincall</code> mode and
/// <class>OcuPilot.Test.PortFixture</class> over <class>OcuPilot.Test.EndpointFixture</class>. The
/// only vendor code that runs is the capture routine, the verification probe and the dictionary
/// lookups; nothing is queued and nothing on the instance changes.</p>
Class OcuPilot.Test.PortCapture Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.MgmntImplFixture).Clear()
    Do ##class(OcuPilot.Test.MgmntPortFixture).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.ProbeFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>An admin-port call issued from inside the management port's capture window is refused: the
/// inner <code>BeginCaptureOutput</code> answers the vendor's "Capture Already Active", the call
/// becomes the generic internal fault, and <code>Run()</code> never executes -- while the outer
/// port's own captured line still reaches its log line, which is only possible if the inner call
/// left the outer buffer alone.</p>
/// <p>Mutation (Rule 19): remove the <code>If $$$ISERR(tSC) Quit</code> after
/// <method>OcuPilot.Port.AdminPort.Sequence</method>'s <code>BeginCaptureOutput</code> -- the inner
/// call succeeds, <code>Run()</code> executes outside any capture of its own, and the first two
/// assertions go red.</p>
Method TestAnAdminCallInsideTheMgmntCaptureIsRefused()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("device")
    ; A non-2xx from the outer vendor call, so the outer port's own failure path is what logs the
    ; text it captured -- the one observable that says its buffer survived the nested call.
    Do ##class(OcuPilot.Test.MgmntImplFixture).Arm("GetWebRESTApps", "500 Internal Server Error", "", "admincall")

    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tSC = ##class(OcuPilot.Test.MgmntPortFixture).Invoke("Applications", "LIST", .tQuery, "", .tRows, .tHttp, .tFault, .tDocument)

    Do $$$AssertEquals(##class(OcuPilot.Test.MgmntImplFixture).InnerCall(), "0|500|" _ ##class(OcuPilot.Api.Error).#INTERNAL, "the nested admin call is an internal fault, not a served call")
    ; The whole trace, not a "Run" substring test: ShouldRunAsync carries those three letters. That
    ; it reaches ShouldRunAsync also says the endpoint was constructed and gated, so the refusal is
    ; the capture's and not a missing class.
    Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("trace"), "ResourcesOR,SaveQueryParams,ValidateQueryParams,ValidateRequest,ValidateSemantics,ShouldRunAsync", "the inner sequence stopped at the capture, so no vendor endpoint ran")

    Do $$$AssertStatusNotOK(tSC, "the outer call reports the vendor's own 500")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL), "as one generic internal fault: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ ##class(OcuPilot.Test.MgmntImplFixture).#VENDORTEXT, "and the outer port's captured line reached its log line, so its buffer outlived the nested call: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
}

}

/// <p>AC7 -- the Integration AC (Rule 1): <class>OcuPilot.Api.Router</class> produces an
/// observable 503 envelope at its own boundary when the install gate is not
/// <code>installed</code>, dispatched through <class>OcuPilot.Test.Dispatch.Invoke</class>
/// against <class>OcuPilot.Test.GateFixture</class> -- no HTTP, no web application, and
/// no dependency on this instance's own, real version row (the phase is forced through
/// <code>_fixturePhase</code>).</p>
/// <p>Installs nothing and calls neither <code>Install</code> nor <code>Uninstall</code>
/// -- this class's whole point is that the gate is testable without a real install
/// having run at all (this story's Design Notes, "The 1.4/1.5 seam").</p>
Class OcuPilot.Test.Gate Extends %UnitTest.TestCase
{

/// <p>Shared assertion for the three refusal phases: exactly one 503 envelope, the
/// matching <code>INSTALL.*</code> code, and the fixture route's own body never
/// reached.</p>
Method AssertRefused(pPhase As %String, pExpectedCode As %String)
{
    Set tParams = {"_fixturePhase": (pPhase)}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.GateFixture", "/ping", "GET", tParams, .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch succeeds (as a transport matter) for phase '" _ pPhase _ "'")
    Do $$$AssertEquals(tStatus, 503, "phase '" _ pPhase _ "' refuses with HTTP 503")
    Do $$$AssertTrue((tBody [ "}{") = 0, "exactly one envelope reaches the wire")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, pExpectedCode, "the envelope's code names phase '" _ pPhase _ "'")
    Do $$$AssertEquals(tParsed.error, "unavailable", "the envelope's slug is the closed-enum 'unavailable' value")
    Do $$$AssertTrue((tBody [ "pong") = 0, "the fixture route's own body ('pong') never reached the wire -- no handler ran")
}

/// <p>AC7 -- phase <code>installing</code> refuses with <code>INSTALL.INSTALLING</code>.</p>
Method TestInstallingPhaseRefusesThroughTheRouter()
{
    Do ..AssertRefused("installing", "INSTALL.INSTALLING")
}

/// <p>AC7 -- phase <code>failed</code> refuses with <code>INSTALL.FAILED</code>.</p>
Method TestFailedPhaseRefusesThroughTheRouter()
{
    Do ..AssertRefused("failed", "INSTALL.FAILED")
}

/// <p>AC7 -- phase <code>upgraderequired</code> refuses with
/// <code>INSTALL.UPGRADEREQUIRED</code>.</p>
Method TestUpgradeRequiredPhaseRefusesThroughTheRouter()
{
    Do ..AssertRefused("upgraderequired", "INSTALL.UPGRADEREQUIRED")
}

/// <p>DW-96 -- phase <code>unreadable</code> refuses with <code>INSTALL.UNREADABLE</code>, and
/// its reason names no schema, role or table.</p>
/// <p>Mutation (Rule 19): delete the Router's <code>unreadable</code> arm, and the gate falls to
/// <code>INSTALL.INSTALLING</code> -- red.</p>
Method TestUnreadablePhaseRefusesThroughTheRouter()
{
    Do ..AssertRefused("unreadable", "INSTALL.UNREADABLE")
    Set tParams = {"_fixturePhase": ("unreadable"), "_fixtureUser": ("_PUBLIC")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.GateFixture", "/ping", "GET", tParams, .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch succeeds for an anonymous caller")
    Do $$$AssertEquals(tStatus, 503, "an anonymous caller gets the same 503")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, "INSTALL.UNREADABLE", "with INSTALL.UNREADABLE, not AUTH.ANONYMOUS")
    Set tReason = $ZConvert(tParsed.reason, "L")
    Do $$$AssertTrue(tReason [ "waiting will not help", "the reason says waiting will not help: " _ tParsed.reason)
    For tWord = "ocupilot_kernel_state", "%db_", "schema", "role", "table", "grant" {
        Do $$$AssertTrue('(tReason [ tWord), "the reason names no " _ tWord)
    }
}

/// <p>AC7, review finding (verification-gap): the install gate must refuse <b>before</b>
/// the caller-identity check, so an anonymous caller learns nothing about the instance
/// while install has not finished (this class's own header, and
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>'s own doc comment). Every other
/// test in this class drives the gate alone, with the caller resolving to the real,
/// authenticated unit-test identity -- so a regression that reordered the two checks
/// (each still individually correct on its own) would pass every one of them. This test
/// forces both the phase <b>and</b> an anonymous caller in the same dispatch and asserts
/// the response is still the install-gate's 503, never the identity check's 401 -- the
/// one combination that actually observes the ordering.</p>
Method TestInstallingPhaseRefusesEvenForAnAnonymousCaller()
{
    Set tParams = {"_fixturePhase": ("installing"), "_fixtureUser": ("_PUBLIC")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.GateFixture", "/ping", "GET", tParams, .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch succeeds")
    Do $$$AssertEquals(tStatus, 503, "an anonymous caller during a non-installed phase still gets the install gate's 503, not the identity check's 401")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, "INSTALL.INSTALLING", "the envelope is the install gate's, not AUTH.ANONYMOUS")
}

/// <p>AC7 -- when the phase is <code>installed</code>, the request dispatches
/// normally: the fixture's own route body reaches the wire, not an envelope.</p>
Method TestInstalledPhaseDispatchesNormally()
{
    Set tParams = {"_fixturePhase": ("installed")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.GateFixture", "/ping", "GET", tParams, .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch succeeds")
    Do $$$AssertEquals(tStatus, 200, "an installed instance dispatches the real route")
    Do $$$AssertTrue(tBody [ "pong", "the fixture route's own body reached the wire")
}

/// <p>Falsifiability (Rule 19), second mutation named for AC7: the code is a stable,
/// dotted, uppercase identifier and never a number.</p>
Method TestGateCodeIsStableAndDotted()
{
    Set tParams = {"_fixturePhase": ("failed")}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.GateFixture", "/ping", "GET", tParams, .tBody, .tStatus, .tAllow)
    Do $$$AssertStatusOK(tSC, "dispatch succeeds")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tParsed.code [ ".", "the code is dotted")
    Do $$$AssertEquals(tParsed.code, $ZConvert(tParsed.code, "U"), "the code is uppercase")
    Do $$$AssertTrue(tParsed.code '? 1.N, "the code is never purely numeric")
}

}

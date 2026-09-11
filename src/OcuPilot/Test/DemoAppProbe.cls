/// <p>Test-only subclass of <class>OcuPilot.Install.Fixture</class> overriding only
/// <parameter>APPPATH</parameter>, to a private, disposable path this test owns
/// outright.</p>
/// <p>Review finding (HIGH): AC9's web-application-create branch is otherwise
/// structurally unreachable in this suite -- <class>OcuPilot.Test.Demo</class>'s own
/// shared, class-level fixture (<method>OcuPilot.Test.Demo.OnBeforeAllTests</method>)
/// pre-creates a collision application at the REAL
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter> ("/csp/myapp") for the
/// whole class's life, specifically to test DW-13 -- so
/// <method>OcuPilot.Install.Fixture.CreateWebApp</method>'s create branch never runs
/// against the real path anywhere in this suite, and no test could assert that the
/// created fixture is disabled and carries no resource.</p>
/// <p><code>..#APPPATH</code>'s self-relative parameter lookup resolves polymorphically
/// through inherited (<code>..</code>) dispatch, so calling
/// <method>OcuPilot.Install.Fixture.Create</method> on THIS class drives
/// <class>OcuPilot.Install.Fixture</class>'s own, completely unmodified
/// <method>CreateWebApp</method> against this private path instead -- the same
/// test-isolation-by-subclass shape <class>OcuPilot.Test.RouterFixture</class>,
/// <class>OcuPilot.Test.GateFixture</class> and <class>OcuPilot.Test.MigrateFault</class>
/// already use elsewhere in this tree, applied here for the first time to
/// <class>OcuPilot.Install.Fixture</class>.</p>
/// <p><b>Correction (build-auto review, 2026-09-10):</b> <code>Create()</code> is not
/// modified, but it is also not narrowed to <code>CreateWebApp</code> alone --
/// <method>OcuPilot.Install.Fixture.Create</method> unconditionally calls all four
/// <code>%SYS</code>-scoped creators (<code>CreateWebApp</code>, <code>CreateSslConfig</code>,
/// <code>CreateX509Credential</code>, <code>CreateTask</code>), so a test driving this
/// class's <code>Create()</code> also re-runs the other three against the SAME shared
/// production-named objects <class>OcuPilot.Test.Demo</class>'s own class-level fixture
/// already created. Harmless after the review's H2 fix (an already-existing object is
/// never adopted or modified), but not "completely unmodified" in the sense of touching
/// only <code>CreateWebApp</code> -- corrected here so the next reader does not rely on
/// that narrower claim.</p>
Class OcuPilot.Test.DemoAppProbe Extends OcuPilot.Install.Fixture
{

/// <p>A path this test owns outright -- never the real
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter>, which Stories 2.5 and 5.8
/// name literally in their own acceptance criteria and which
/// <class>OcuPilot.Test.Demo</class>'s own shared fixture deliberately keeps colliding
/// with for the whole class's life (DW-13).</p>
Parameter APPPATH = "/csp/ocupilottestdemoprobe";

}

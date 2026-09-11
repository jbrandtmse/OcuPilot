/// <p>Test-only subclass of <class>OcuPilot.Install.Fixture</class> overriding only
/// <parameter>APPPATH</parameter>, to a private, disposable path this test owns
/// outright.</p>
/// <p>Review finding (HIGH): without this subclass, nothing in the suite can
/// <b>reliably assert</b> AC9's web-application-create branch (the "absent, so
/// create it disabled with no resource" path) -- <class>OcuPilot.Test.Demo</class>'s
/// own shared, class-level fixture (<method>OcuPilot.Test.Demo.OnBeforeAllTests</method>)
/// drives the unmodified <method>OcuPilot.Install.Fixture.Create</method>, which still
/// touches the REAL <parameter>OcuPilot.Install.Fixture.APPPATH</parameter>
/// ("/csp/myapp") every class run -- but whether that hits the create branch or the
/// already-exists branch depends on ambient instance state, not on anything this
/// suite controls or asserts against. <b>Correction (build-auto step-04 review pass,
/// 2026-09-11):</b> an earlier version of this comment additionally claimed
/// <code>Test.Demo</code> "pre-creates a collision application at the REAL
/// <code>APPPATH</code>... for the whole class's life" -- that out-of-band
/// pre-create/delete block existed when this class was first written (to test DW-13's
/// foreign-collision branch specifically) but was removed from <code>Test.Demo</code>
/// by a later rework pass (see that class's own <method>OnBeforeAllTests</method>
/// header) once it was found to risk destroying a REAL production demo fixture on a
/// demo-enabled instance; <code>Test.Demo</code>'s own DW-13 collision test now uses
/// this class's private path too, exactly like the create-branch test below.</p>
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
/// <code>"probe"</code>-profile objects <class>OcuPilot.Test.Demo</class>'s own
/// class-level fixture already created (<b>corrected, build-auto step-04 review pass,
/// 2026-09-11: "production-named" above was wrong even before this correction --
/// <method>OcuPilot.Install.Fixture.ResolvedPrefix</method> qualifies every one of
/// these names by profile, so the "probe" profile's copies never carry production's
/// own literal names</b>). Harmless after the review's H2 fix (an already-existing
/// object is never adopted or modified), but not "completely unmodified" in the sense
/// of touching only <code>CreateWebApp</code> -- corrected here so the next reader
/// does not rely on that narrower claim.</p>
Class OcuPilot.Test.DemoAppProbe Extends OcuPilot.Install.Fixture
{

/// <p>A path this test owns outright -- never the real
/// <parameter>OcuPilot.Install.Fixture.APPPATH</parameter>, which Stories 2.5 and 5.8
/// name literally in their own acceptance criteria. <b>Corrected (build-auto step-04
/// review pass, 2026-09-11):</b> this used to add "and which
/// <code>OcuPilot.Test.Demo</code>'s own shared fixture deliberately keeps colliding
/// with for the whole class's life (DW-13)" -- true when this class was first
/// written, no longer true since a later rework pass removed that out-of-band
/// collision block from <code>Test.Demo</code> (see this class's own header).</p>
Parameter APPPATH = "/csp/ocupilottestdemoprobe";

}

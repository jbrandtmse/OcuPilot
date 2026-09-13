/// <p>Subclass of <class>OcuPilot.Test.RouterFixture</class> overriding <b>only</b> the
/// phase source (<method>GateStatus</method>), so <class>OcuPilot.Test.Gate</class> can
/// force each of the five gate states through
/// <class>OcuPilot.Test.Dispatch</class>'s <code>_fixturePhase</code> query parameter
/// without weakening the real router or the real installer read. Falls back to the real,
/// installer-driven status when the caller sets no override, so a plain dispatch still
/// behaves like production -- the same fallback shape
/// <class>OcuPilot.Test.RouterFixture.ResolvedUsername</class> already uses for
/// <code>_fixtureUser</code>.</p>
Class OcuPilot.Test.GateFixture Extends OcuPilot.Test.RouterFixture
{

/// <p>Reads <code>_fixturePhase</code> (one of <code>installing</code>,
/// <code>failed</code>, <code>upgraderequired</code>, <code>unreadable</code>, <code>installed</code>) and, when
/// set, returns it verbatim instead of asking
/// <class>OcuPilot.Install.Installer</class>. Never overridden in production.</p>
ClassMethod GateStatus() As %String
{
    Set tForced = %request.Get("_fixturePhase", "")
    If tForced '= "" Quit tForced
    Quit ##super()
}

}

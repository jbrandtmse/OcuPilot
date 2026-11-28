/// <p>Test-only fixture for Story 24.14's run suites: <class>OcuPilot.Test.PmmlTestIdle</class> with a two-second bound and a one-second grace, whose child ignores its bound and is not released, so the
/// supervisor ends it at the bound plus the grace, three seconds in all, and the run ends <code>stopped</code>.</p>
Class OcuPilot.Test.PmmlTestHung Extends OcuPilot.Test.PmmlTestIdle
{

Parameter GRACESECONDS As %Integer = 1;

/// <p>The seconds a run is bounded to.</p>
Parameter HUNGSECONDS = 2;

ClassMethod BoundSeconds() As %Numeric
{
    Quit ..#HUNGSECONDS
}

}

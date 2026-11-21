/// <p>Test-only fixture for Story 24.14's run suites: <class>OcuPilot.Test.PmmlTestIdle</class> with a three-second bound and a one-second grace, whose supervisor's end of its child does nothing, so the
/// child outlives the supervisor's first wait for it after a cancel, as a child that is slow to leave would. The child ends when a test releases it.</p>
Class OcuPilot.Test.PmmlTestStubborn Extends OcuPilot.Test.PmmlTestIdle
{

Parameter GRACESECONDS As %Integer = 1;

/// <p>The seconds a run is bounded to.</p>
Parameter STUBBORNSECONDS = 3;

ClassMethod BoundSeconds() As %Numeric
{
    Quit ..#STUBBORNSECONDS
}

ClassMethod EndChild(pChild As %Integer) As %Integer [ Private ]
{
    Quit 1
}

}

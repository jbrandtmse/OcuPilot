/// <p><class>OcuPilot.Test.AnalyticsMdxFixture</class> with a bound under one second, so a test pins that the last fraction of a run's bound is
/// still enforced: an alarm of zero seconds never fires. Everything else is the fixture's.</p>
Class OcuPilot.Test.AnalyticsMdxQuick Extends OcuPilot.Test.AnalyticsMdxFixture
{

/// <p>The seconds the fixture's run is bounded to.</p>
Parameter BOUNDSECONDS = 0.5;

}

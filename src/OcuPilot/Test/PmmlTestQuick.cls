/// <p>Test-only fixture for Story 24.14 Batch 2's run suites: <class>OcuPilot.Area.Analytics.PmmlTest</class> with a two-second bound, so that a test of a model over a slow source is stopped at the bound in two
/// seconds rather than the two minutes the product allows. It changes nothing else: the job it spawns is handed this class's name, so the shorter bound applies in it.</p>
Class OcuPilot.Test.PmmlTestQuick Extends OcuPilot.Area.Analytics.PmmlTest
{

/// <p>The seconds a run is bounded to.</p>
Parameter QUICKSECONDS = 2;

ClassMethod BoundSeconds() As %Numeric
{
    Quit ..#QUICKSECONDS
}

}

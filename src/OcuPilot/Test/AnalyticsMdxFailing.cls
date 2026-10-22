/// <p><class>OcuPilot.Test.AnalyticsMdxFixture</class> whose job fails inside its own work: the pivot variables raise, so the job reaches
/// its failure handler holding a statement it must not log. Everything else is the fixture's.</p>
Class OcuPilot.Test.AnalyticsMdxFailing Extends OcuPilot.Test.AnalyticsMdxFixture
{

ClassMethod Variables(Output pVariables)
{
    Kill pVariables
    Throw ##class(%Exception.General).%New("OcuPilotTestAnalyticsMdxFailing")
}

}

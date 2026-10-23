/// <p><class>OcuPilot.Test.AnalyticsMdxFixture</class>, with its two-second bound, that runs its statements through
/// <class>OcuPilot.Test.AnalyticsPortHang</class>, so the run's alarm alone ends a DRILLTHROUGH's wait. Everything else is the fixture's.</p>
Class OcuPilot.Test.AnalyticsMdxHang Extends OcuPilot.Test.AnalyticsMdxFixture
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.AnalyticsPortHang"
}

}

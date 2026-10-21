/// <p><class>OcuPilot.Area.Analytics.MdxQuery</class>, with the production bound, that runs its statements through
/// <class>OcuPilot.Test.AnalyticsPortHang</class>: a DRILLTHROUGH over the grid cube runs no statement while it starts, and its listing's
/// read then waits for ever, so only the job's own read of its owner's cancel ends that run within the bound. Everything else is the
/// production class's.</p>
Class OcuPilot.Test.AnalyticsMdxPaused Extends OcuPilot.Area.Analytics.MdxQuery
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.AnalyticsPortHang"
}

}

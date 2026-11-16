/// <p>A class that is not a harvested handler: <class>OcuPilot.Test.Harvest</class> drives it
/// through the port to show the port refuses a public class method of a class outside
/// <class>OcuPilot.Port.Harvest.Handler</class>. <method>Run</method> counts into the counter
/// <method>OcuPilot.Test.HarvestFixture.Runs</method> reads.</p>
Class OcuPilot.Test.HarvestOutsider Extends %RegisteredObject
{

/// <p>Count one run.</p>
ClassMethod Run() As %Status
{
    Set tRuns = $Increment(^||OcuPilotHarvestFixture)
    Quit $$$OK
}

}

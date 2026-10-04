/// <p><class>OcuPilot.Area.Explorer.SqlBackground</class> with the short-bound port
/// (<class>OcuPilot.Test.SqlPortFixture</class>) and an instance cap of one run, so a test stops a
/// probe query in seconds and reaches the instance cap with one other run. Everything else -- the
/// store, the spawn, the job's checks -- is the production class's, and the job applies these seams
/// because the spawn hands it this class's name.</p>
Class OcuPilot.Test.SqlBackgroundFixture Extends OcuPilot.Area.Explorer.SqlBackground
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.SqlPortFixture"
}

ClassMethod MaxRunning() As %Integer
{
    Quit 1
}

}

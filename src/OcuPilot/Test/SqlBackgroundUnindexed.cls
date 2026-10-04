/// <p><class>OcuPilot.Test.SqlBackgroundFixture</class> whose job runs its statement through
/// <class>OcuPilot.Test.SqlPortUnindexed</class>, which refuses every statement as an internal
/// failure, so a test drives the job's own failure path and reads the line it logs.</p>
Class OcuPilot.Test.SqlBackgroundUnindexed Extends OcuPilot.Test.SqlBackgroundFixture
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.SqlPortUnindexed"
}

}

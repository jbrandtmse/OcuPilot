/// <p><class>OcuPilot.Test.SqlBackgroundFixture</class> whose spawn is never accepted, so a test drives
/// the start's answer for a job that did not start. Everything else is the fixture's.</p>
Class OcuPilot.Test.SqlBackgroundUnspawned Extends OcuPilot.Test.SqlBackgroundFixture
{

ClassMethod Spawn(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, Output pChild As %Integer) As %Boolean
{
    Set pChild = ""
    Quit 0
}

}

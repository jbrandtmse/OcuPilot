/// <p>Test-only <class>OcuPilot.Screen.Read</class> subclass whose port is
/// <class>OcuPilot.Test.PortFixture</class>, so a read's rows can be armed through
/// <class>OcuPilot.Test.EndpointFixture</class>, and whose monitor port is
/// <class>OcuPilot.Test.MonitorPortFixture</class>, so a <code>monitor</code> part's sensor text and
/// gate can be armed; unarmed, both answer as production does.</p>
Class OcuPilot.Test.Read.ReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.PortFixture"
}

ClassMethod MonitorPortClass() As %String
{
    Quit "OcuPilot.Test.MonitorPortFixture"
}

}

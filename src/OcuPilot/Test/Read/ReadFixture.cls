/// <p>Test-only <class>OcuPilot.Screen.Read</class> subclass whose port is
/// <class>OcuPilot.Test.PortFixture</class>, so a read's rows can be armed through
/// <class>OcuPilot.Test.EndpointFixture</class>.</p>
Class OcuPilot.Test.Read.ReadFixture Extends OcuPilot.Screen.Read
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.PortFixture"
}

}

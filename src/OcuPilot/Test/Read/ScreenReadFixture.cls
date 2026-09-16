/// <p>Test-only <class>OcuPilot.Api.ScreenRead</class> subclass: descriptors from
/// <class>OcuPilot.Test.Read.Registry</class>, privileges from
/// <class>OcuPilot.Test.ScreenGate</class>'s declared set, and rows through
/// <class>OcuPilot.Test.Read.ReadFixture</class>. Reached through
/// <class>OcuPilot.Test.RouterFixture</class>'s screen-read route.</p>
Class OcuPilot.Test.Read.ScreenReadFixture Extends OcuPilot.Api.ScreenRead
{

ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Test.Read.Registry"
}

ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

ClassMethod ReadClass() As %String
{
    Quit "OcuPilot.Test.Read.ReadFixture"
}

}

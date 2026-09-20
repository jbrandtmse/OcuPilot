/// <p>Fixture: a screen registry whose descriptor package holds no class, so
/// <class>OcuPilot.Test.AsTheUserProbe.Registry</class> derives no read tool of its own.</p>
Class OcuPilot.Test.AsTheUserProbe.Screens Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.AsTheUserProbe.NoScreen."
}

}

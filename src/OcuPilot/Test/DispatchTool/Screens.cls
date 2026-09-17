/// <p>Fixture: a screen registry whose descriptor package holds no class, so
/// <class>OcuPilot.Test.DispatchTool.Registry</class> derives no read tool.</p>
Class OcuPilot.Test.DispatchTool.Screens Extends OcuPilot.Screen.Registry
{

ClassMethod DescriptorPackage() As %String
{
    Quit "OcuPilot.Test.DispatchTool.NoScreen."
}

}

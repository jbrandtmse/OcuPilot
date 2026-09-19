/// <p>Fixture: a tool registry holding exactly the two colliding tools in this package
/// (<class>OcuPilot.Test.ClashTool.First</class>, <class>OcuPilot.Test.ClashTool.Second</class>)
/// and no descriptor-derived read tool.</p>
Class OcuPilot.Test.ClashTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.ClashTool."
}

ClassMethod ExcludedPackage() As %String
{
    Quit ""
}

ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Test.DispatchTool.Screens"
}

}

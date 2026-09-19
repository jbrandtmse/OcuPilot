/// <p>Fixture: a tool registry holding exactly the counting tools in this package and no
/// descriptor-derived read tool.</p>
Class OcuPilot.Test.DispatchTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.DispatchTool."
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

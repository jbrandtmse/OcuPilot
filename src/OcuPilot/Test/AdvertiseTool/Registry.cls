/// <p>Fixture: a tool registry holding exactly <class>OcuPilot.Test.AdvertiseTool.Tool</class> and no
/// descriptor-derived read tool.</p>
Class OcuPilot.Test.AdvertiseTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.AdvertiseTool."
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

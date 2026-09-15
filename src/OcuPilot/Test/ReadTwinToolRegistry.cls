/// <p>Test-only <class>OcuPilot.Screen.Tool.Registry</class> subclass whose read tools come from
/// <class>OcuPilot.Test.ReadTwinRegistry</class>'s two descriptors, which claim one tool name. Its
/// tool package holds no tool class.</p>
Class OcuPilot.Test.ReadTwinToolRegistry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.ReadTwin."
}

ClassMethod ExcludedPackage() As %String
{
    Quit ""
}

ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Test.ReadTwinRegistry"
}

}

/// <p>Test-only <class>OcuPilot.Screen.Tool.Registry</class> subclass: tool classes from the
/// fixture tool package, read tools from <class>OcuPilot.Test.Read.Registry</class>'s descriptors,
/// answered by <class>OcuPilot.Test.Read.ToolFixture</class>.</p>
Class OcuPilot.Test.Read.ToolRegistry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.Read.Tool."
}

ClassMethod ExcludedPackage() As %String
{
    Quit ""
}

ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Test.Read.Registry"
}

ClassMethod ReadToolClass() As %String
{
    Quit "OcuPilot.Test.Read.ToolFixture"
}

}

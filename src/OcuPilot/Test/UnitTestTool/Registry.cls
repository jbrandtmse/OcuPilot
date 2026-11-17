/// <p>Fixture: a tool registry holding <class>OcuPilot.Test.UnitTestTool.Run</class> alone, so
/// <class>OcuPilot.Test.UnitTestActionFixture</class> resolves the shipped tool's name to the one whose port records. Its screen
/// registry points at a package with no descriptor in it, so no read tool is derived beside the one write tool.</p>
Class OcuPilot.Test.UnitTestTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.UnitTestTool."
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

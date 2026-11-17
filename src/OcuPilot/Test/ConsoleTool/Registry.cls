/// <p>Fixture: a tool registry holding <class>OcuPilot.Test.ConsoleTool.RunCommand</class> and
/// <class>OcuPilot.Test.ConsoleTool.RunClassMethod</class> alone, so <class>OcuPilot.Test.ConsoleActionFixture</class> resolves the
/// shipped tools' names to the ones whose port records. Its screen registry points at a package with no descriptor in it, so no
/// read tool is derived beside the two write tools.</p>
Class OcuPilot.Test.ConsoleTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.ConsoleTool."
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

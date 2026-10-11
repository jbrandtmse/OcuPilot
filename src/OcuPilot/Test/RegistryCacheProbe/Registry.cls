/// <p>Fixture: a tool registry holding only the tools compiled into
/// <code>OcuPilot.Test.RegistryCacheProbe.</code>, none of which ships. The one tool is
/// <code>OcuPilot.Test.RegistryCacheProbe.Late</code>, which <class>OcuPilot.Test.RegistryCache</class>
/// compiles and deletes at run time, and no descriptor-derived read tool, so the listing's cache is
/// exercised on a roster the test controls.</p>
Class OcuPilot.Test.RegistryCacheProbe.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.RegistryCacheProbe."
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

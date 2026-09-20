/// <p>Fixture: a tool registry holding exactly <class>OcuPilot.Test.AsTheUserProbe.Tool</class>
/// and no descriptor-derived read tool.</p>
Class OcuPilot.Test.AsTheUserProbe.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.AsTheUserProbe."
}

ClassMethod ExcludedPackage() As %String
{
    Quit ""
}

ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Test.AsTheUserProbe.Screens"
}

}

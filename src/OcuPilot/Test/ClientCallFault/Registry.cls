/// <p>Fixture: a tool registry holding <class>OcuPilot.Test.ClientCallFault.Probe</class> alone, so
/// the failing-<code>Directive</code> branch can be driven in isolation and no other registry's tool
/// count changes.</p>
Class OcuPilot.Test.ClientCallFault.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.ClientCallFault."
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

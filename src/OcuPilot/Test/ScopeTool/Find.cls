/// <p>Fixture: <code>shell.tools.find</code> searching <class>OcuPilot.Test.ScopeTool.Registry</class>
/// instead of the production listing.</p>
Class OcuPilot.Test.ScopeTool.Find Extends OcuPilot.Screen.Tool.ToolsFind
{

ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Test.ScopeTool.Registry"
}

}

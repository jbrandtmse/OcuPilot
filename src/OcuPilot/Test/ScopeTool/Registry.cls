/// <p>Fixture: a tool registry holding exactly the scoped-turn tools in this package -- the discovery
/// tool, a tool found by search, a shell tool, a tool that sorts after both and a tool that is not
/// advertised -- and no descriptor-derived read tool.</p>
Class OcuPilot.Test.ScopeTool.Registry Extends OcuPilot.Test.DispatchTool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.ScopeTool."
}

}

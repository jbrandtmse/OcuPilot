/// <p>Fixture: a tool registry holding exactly one tool
/// (<class>OcuPilot.Test.BadFulfilment.Tool</class>) and no descriptor-derived read tool, so
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method> exercises
/// <method>OcuPilot.Screen.Tool.Registry.FulfilmentProblem</method> in isolation (Story 4.7,
/// AC9).</p>
Class OcuPilot.Test.BadFulfilment.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.BadFulfilment."
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

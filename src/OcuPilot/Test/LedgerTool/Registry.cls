/// <p>Fixture: a tool registry holding <class>OcuPilot.Test.LedgerTool.Probe</class> alone --
/// <class>OcuPilot.Test.LedgerTool.Silent</class> is excluded by name -- so the declaring tool's own
/// advertisement can be shown to succeed beside <class>OcuPilot.Test.LedgerTool.All</class>'s
/// refusal.</p>
Class OcuPilot.Test.LedgerTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.LedgerTool."
}

ClassMethod ExcludedPackage() As %String
{
    Quit "OcuPilot.Test.LedgerTool.Silent"
}

ClassMethod ScreenRegistryClass() As %String
{
    Quit "OcuPilot.Test.DispatchTool.Screens"
}

}

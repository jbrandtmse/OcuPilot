/// <p>Fixture: a tool registry holding <class>OcuPilot.Test.LedgerClientTool.Probe</class> alone,
/// so the client-fulfilled path can be driven in isolation from every other ledger tool fixture --
/// adding it here changes no other registry's tool count.</p>
Class OcuPilot.Test.LedgerClientTool.Registry Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.LedgerClientTool."
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

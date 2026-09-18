/// <p>Fixture: the same package as <class>OcuPilot.Test.LedgerTool.Registry</class> with nothing
/// excluded, so <class>OcuPilot.Test.LedgerTool.Silent</class> is in the list and the advertisement
/// refuses, naming it.</p>
Class OcuPilot.Test.LedgerTool.All Extends OcuPilot.Screen.Tool.Registry
{

ClassMethod ToolPackage() As %String
{
    Quit "OcuPilot.Test.LedgerTool."
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

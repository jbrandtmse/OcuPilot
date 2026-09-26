/// <p>Test-only <class>OcuPilot.Screen.Context</class> subclass whose tool registry is itself, and
/// whose <method>ListTools</method> always fails, so the shipped
/// <method>OcuPilot.Screen.Context.ScreenTools</method> runs against a registry that cannot list.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenToolsFault Extends OcuPilot.Screen.Context
{

ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Test.ScreenToolsFault"
}

/// <p>A tool list that cannot be built.</p>
ClassMethod ListTools(Output pList As %DynamicArray) As %Status
{
    Set pList = []
    Quit $$$ERROR($$$GeneralError, "ScreenToolsFault: the tool list cannot be built")
}

}

/// <p>Test-only <class>OcuPilot.Test.EcpActionFixture</class> subclass whose <method>ToolFor</method> runs the SQL settings screen's Set value through
/// <class>OcuPilot.Test.SeamSqlSettingSet</class>, so the row action's fresh read and write go through <class>OcuPilot.Test.ConfigGateSeam</class>.
/// The pairs and everything else are the shipped route's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSqlActionFixture Extends OcuPilot.Test.EcpActionFixture
{

ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.SqlSettingSet" Set pToolClass = "OcuPilot.Test.SeamSqlSettingSet"
    Quit tSC
}

}

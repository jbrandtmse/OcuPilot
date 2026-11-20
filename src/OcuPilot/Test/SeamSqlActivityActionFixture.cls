/// <p>Test-only <class>OcuPilot.Test.EcpActionFixture</class> subclass whose <method>ToolFor</method> runs the SQL activity
/// screen's Cancel query through <class>OcuPilot.Test.SeamSqlActivityCancel</class>, so the row action's fresh read and write go
/// through <class>OcuPilot.Test.SqlActivitySeam</class>. The pairs and everything else are the shipped route's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSqlActivityActionFixture Extends OcuPilot.Test.EcpActionFixture
{

ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.SqlActivityCancel" Set pToolClass = "OcuPilot.Test.SeamSqlActivityCancel"
    Quit tSC
}

}

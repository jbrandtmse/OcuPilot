/// <p>Test-only <class>OcuPilot.Test.DatabaseActionFixture</class> subclass for the Remote databases
/// list (Story 18.16): its port seam answers <class>OcuPilot.Test.RemoteDatabaseListingPort</class>
/// when a test names none, and <method>ToolFor</method> runs the remote delete through
/// <class>OcuPilot.Test.SeamRemoteDatabaseDelete</class>, so the row action's fresh read and write are
/// recorded there.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RemoteDatabaseActionFixture Extends OcuPilot.Test.DatabaseActionFixture
{

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.RemoteDatabaseListingPort")
}

/// <p>The shipped resolution, with the remote delete's class replaced by
/// <class>OcuPilot.Test.SeamRemoteDatabaseDelete</class>.</p>
ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $Get(pToolClass) = "OcuPilot.Screen.Tool.RemoteDatabaseDelete" Set pToolClass = "OcuPilot.Test.SeamRemoteDatabaseDelete"
    Quit tSC
}

}

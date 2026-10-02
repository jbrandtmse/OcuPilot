/// <p>Test-only <class>OcuPilot.Screen.Tool.NamespaceEnableInterop</class> subclass declaring the
/// base's default port, so a screen action run through a fixture resolves its port through that
/// fixture's seam (<class>OcuPilot.Test.MappingActionFixture</class>,
/// <class>OcuPilot.Test.NamespaceStartedAction</class>), and answering the port a test names in
/// <code>^||OcuPilotNamespaceWritePort</code> where one is named, so the agent's mint of it reads
/// through that port too. Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamNamespaceEnableInterop Extends OcuPilot.Screen.Tool.NamespaceEnableInterop
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotNamespaceWritePort, ..#PORTCLASS)
}

}

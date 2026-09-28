/// <p>Test-only <class>OcuPilot.Area.OsMgmt.NamespaceSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers the port a test names in
/// <code>^||OcuPilotNamespaceWritePort</code>, and <class>OcuPilot.Test.AcceptPort</class>, which
/// writes nothing, when none is named. The name look-up, the database list and the prohibited set's
/// target read are not this seam and read through the tools' own port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.NamespaceSaveFixture Extends OcuPilot.Area.OsMgmt.NamespaceSave
{

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotNamespaceWritePort, "OcuPilot.Test.AcceptPort")
}

}

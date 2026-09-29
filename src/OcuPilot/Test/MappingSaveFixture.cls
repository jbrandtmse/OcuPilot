/// <p>Test-only <class>OcuPilot.Area.OsMgmt.MappingSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers the port a test names in
/// <code>^||OcuPilotNamespaceWritePort</code>, and <class>OcuPilot.Test.MappingAcceptPort</class>,
/// which writes nothing, when none is named. The name look-up, the namespace and database reads and
/// the prohibited set's target read are not this seam and read through the tools' own port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingSaveFixture Extends OcuPilot.Area.OsMgmt.MappingSave
{

ClassMethod PortClass() As %String
{
    Quit $Get(^||OcuPilotNamespaceWritePort, "OcuPilot.Test.MappingAcceptPort")
}

}

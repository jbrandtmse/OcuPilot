/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose one further seam is the
/// port a namespace tool declares: <method>PortClassOf</method> answers the port a test names in
/// <code>^||OcuPilotNamespaceWritePort</code>, and <class>OcuPilot.Test.AcceptPort</class>, which
/// writes nothing, when none is named. Everything else is the shipped confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.NamespaceConfirm Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit $Get(^||OcuPilotNamespaceWritePort, "OcuPilot.Test.AcceptPort")
}

}

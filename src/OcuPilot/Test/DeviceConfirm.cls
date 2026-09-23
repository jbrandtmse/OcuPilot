/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose one further seam is the
/// port a device tool declares: <method>PortClassOf</method> answers
/// <class>OcuPilot.Test.DeviceRecordPort</class>, so the confirm's re-read and write reach the
/// instance through the shipped admin port with the body recorded. Everything else is the shipped
/// confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DeviceConfirm Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.DeviceRecordPort"
}

}

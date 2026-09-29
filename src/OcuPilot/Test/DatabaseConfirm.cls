/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose one further seam is the port
/// a database tool declares: <method>PortClassOf</method> answers the port a test names in
/// <code>^||OcuPilotDatabaseWritePort</code>, and <class>OcuPilot.Test.DatabaseAcceptPort</class>, which
/// writes nothing, when none is named. Everything else is the shipped confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseConfirm Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.DatabaseAcceptPort")
}

}

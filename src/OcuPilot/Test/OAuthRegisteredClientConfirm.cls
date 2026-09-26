/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose one further seam is the port
/// a server client tool declares: <method>PortClassOf</method> answers
/// <class>OcuPilot.Test.OAuthRegisteredClientRecordPort</class>, so the confirm's re-read and write
/// reach the instance through the shipped port with what was sent recorded.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthRegisteredClientConfirm Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.OAuthRegisteredClientRecordPort"
}

}

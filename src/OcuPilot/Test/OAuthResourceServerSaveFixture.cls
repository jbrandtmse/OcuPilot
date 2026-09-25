/// <p>Test-only <class>OcuPilot.Area.Security.OAuthResourceServerSave</class> subclass with one
/// replaced seam: <method>PortClass</method> answers
/// <class>OcuPilot.Test.OAuthResourceServerRecordPort</class>, so the Save runs for real against the
/// instance and what it sends is recorded.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthResourceServerSaveFixture Extends OcuPilot.Area.Security.OAuthResourceServerSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.OAuthResourceServerRecordPort"
}

}

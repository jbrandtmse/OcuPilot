/// <p>Test-only <class>OcuPilot.Area.Security.OAuthServerSave</class> subclass with one replaced
/// seam: <method>PortClass</method> answers <class>OcuPilot.Test.OAuthServerRecordPort</class>, so the
/// Save runs for real against the instance and what it sends is recorded. The rules' look-ups and the
/// prohibited set's target read go through the tools' own port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthServerSaveFixture Extends OcuPilot.Area.Security.OAuthServerSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.OAuthServerRecordPort"
}

}

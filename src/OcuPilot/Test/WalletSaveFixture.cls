/// <p>Test-only <class>OcuPilot.Area.Security.WalletSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.WalletRecordPort</class>, so
/// <method>Create</method> and <method>Update</method> run for real against the instance and the body
/// they send is recorded. The name look-up, the collection check and the prohibited set's target read
/// are not this seam and read through the tools' own port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WalletSaveFixture Extends OcuPilot.Area.Security.WalletSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.WalletRecordPort"
}

}

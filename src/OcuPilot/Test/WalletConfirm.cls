/// <p>Test-only <class>OcuPilot.Test.ConfirmFixture</class> subclass whose one further seam is the
/// port a wallet secret tool declares: <method>PortClassOf</method> answers
/// <class>OcuPilot.Test.WalletRecordPort</class>, so the confirm's re-read and write go through the
/// shipped wallet port with the body recorded. Everything else is the shipped confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WalletConfirm Extends OcuPilot.Test.ConfirmFixture
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.WalletRecordPort"
}

}

/// <p>Test-only <class>OcuPilot.Screen.Tool.JournalSwitchDirectory</class> whose declared port is
/// <class>OcuPilot.Test.JournalIntegrityPort</class>, which records each call before sending it on.
/// Everything else is the shipped tool.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamJournalSwitchDirectory Extends OcuPilot.Screen.Tool.JournalSwitchDirectory
{

Parameter PORTCLASS = "OcuPilot.Test.JournalIntegrityPort";

}

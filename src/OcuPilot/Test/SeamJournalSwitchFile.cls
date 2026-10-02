/// <p>Test-only <class>OcuPilot.Screen.Tool.JournalSwitchFile</class> whose declared port is
/// <class>OcuPilot.Test.JournalIntegrityPort</class>, which records each call before sending it on.
/// Everything else is the shipped tool.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamJournalSwitchFile Extends OcuPilot.Screen.Tool.JournalSwitchFile
{

Parameter PORTCLASS = "OcuPilot.Test.JournalIntegrityPort";

}

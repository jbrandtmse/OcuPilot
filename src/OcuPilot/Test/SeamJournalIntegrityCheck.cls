/// <p>Test-only <class>OcuPilot.Screen.Tool.JournalIntegrityCheck</class> whose declared port is
/// <class>OcuPilot.Test.JournalIntegrityPort</class>, so a screen action reaching it is answered by the
/// test's armed check. Everything else is the shipped tool.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamJournalIntegrityCheck Extends OcuPilot.Screen.Tool.JournalIntegrityCheck
{

Parameter PORTCLASS = "OcuPilot.Test.JournalIntegrityPort";

}

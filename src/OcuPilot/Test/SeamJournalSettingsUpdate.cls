/// <p>Test-only <class>OcuPilot.Screen.Tool.JournalSettingsUpdate</class> whose declared port is
/// <class>OcuPilot.Test.JournalSettingsPort</class>, which records each call and each settings
/// <code>PUT</code>'s body before sending it on. Everything else is the shipped tool.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamJournalSettingsUpdate Extends OcuPilot.Screen.Tool.JournalSettingsUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.JournalSettingsPort";

}

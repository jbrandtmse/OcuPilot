/// <p><class>OcuPilot.Screen.Tool.LocaleImport</class> reaching its file through <class>OcuPilot.Test.LocaleGateSeam</class>, so the mint's read
/// refuses what the port refuses and no import is made. It lives in the test package, which the tool registry never lists. <b>Not a
/// <class>%UnitTest.TestCase</class></b>.</p>
Class OcuPilot.Test.LocaleImportSeam Extends OcuPilot.Screen.Tool.LocaleImport
{

Parameter PORTCLASS = "OcuPilot.Test.LocaleGateSeam";

}

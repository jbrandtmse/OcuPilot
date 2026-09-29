/// <p>Test-only <class>OcuPilot.Screen.Tool.DatabaseDefragment</class> subclass declaring the write base's default
/// port, so a screen action run through <class>OcuPilot.Test.DatabaseActionFixture</class> reaches the
/// port that fixture's seam names, always a <class>OcuPilot.Port.DatabasePort</class> subclass (Story
/// 18.4). Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamDatabaseDefragment Extends OcuPilot.Screen.Tool.DatabaseDefragment
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

}

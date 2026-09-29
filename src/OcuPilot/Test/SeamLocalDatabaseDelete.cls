/// <p>Test-only <class>OcuPilot.Screen.Tool.LocalDatabaseDelete</class> subclass declaring the base's
/// default port, so a screen action run through <class>OcuPilot.Test.DatabaseActionFixture</class>
/// resolves its port through that fixture's seam, which is always a
/// <class>OcuPilot.Port.DatabasePort</class> subclass. Outside the tool package, so the registry never
/// lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamLocalDatabaseDelete Extends OcuPilot.Screen.Tool.LocalDatabaseDelete
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

}

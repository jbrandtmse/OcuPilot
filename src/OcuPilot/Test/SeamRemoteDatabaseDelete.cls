/// <p>Test-only <class>OcuPilot.Screen.Tool.RemoteDatabaseDelete</class> subclass declaring the base's
/// default port, so a screen action run through <class>OcuPilot.Test.RemoteDatabaseActionFixture</class>
/// resolves its port through that fixture's seam. Outside the tool package, so the registry never
/// lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamRemoteDatabaseDelete Extends OcuPilot.Screen.Tool.RemoteDatabaseDelete
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

}

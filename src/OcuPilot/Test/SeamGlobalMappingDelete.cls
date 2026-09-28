/// <p>Test-only <class>OcuPilot.Screen.Tool.GlobalMappingDelete</class> subclass declaring the base's
/// default port, so a screen action run through <class>OcuPilot.Test.MappingActionFixture</class>
/// resolves its port through that fixture's seam. Outside the tool package, so the registry never
/// lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamGlobalMappingDelete Extends OcuPilot.Screen.Tool.GlobalMappingDelete
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

}

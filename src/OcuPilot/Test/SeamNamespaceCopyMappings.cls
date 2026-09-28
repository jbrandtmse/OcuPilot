/// <p>Test-only <class>OcuPilot.Screen.Tool.NamespaceCopyMappings</class> subclass declaring the
/// base's default port, so a screen action run through a fixture resolves its port through that
/// fixture's seam (<class>OcuPilot.Test.MappingActionFixture</class>,
/// <class>OcuPilot.Test.NamespaceStartedAction</class>). Outside the tool package, so the registry
/// never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamNamespaceCopyMappings Extends OcuPilot.Screen.Tool.NamespaceCopyMappings
{

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

}

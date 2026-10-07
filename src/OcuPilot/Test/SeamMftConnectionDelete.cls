/// <p>Test-only <class>OcuPilot.Screen.Tool.MftConnectionDelete</class> subclass declaring
/// <class>OcuPilot.Test.MftSeamPort</class> as its port, so a delete's fresh read and write are recorded.
/// Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamMftConnectionDelete Extends OcuPilot.Screen.Tool.MftConnectionDelete
{

Parameter PORTCLASS = "OcuPilot.Test.MftSeamPort";

}

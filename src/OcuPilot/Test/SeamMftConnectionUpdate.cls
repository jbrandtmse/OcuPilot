/// <p>Test-only <class>OcuPilot.Screen.Tool.MftConnectionUpdate</class> subclass declaring
/// <class>OcuPilot.Test.MftSeamPort</class> as its port. Outside the tool package, so the registry never lists
/// it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamMftConnectionUpdate Extends OcuPilot.Screen.Tool.MftConnectionUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.MftSeamPort";

}

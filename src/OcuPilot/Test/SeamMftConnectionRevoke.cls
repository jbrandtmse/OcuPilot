/// <p>Test-only <class>OcuPilot.Screen.Tool.MftConnectionRevoke</class> subclass declaring
/// <class>OcuPilot.Test.MftSeamPort</class> as its port, so a mint reads a connection as authorized when the seam
/// is armed so and its confirm's write is recorded. Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamMftConnectionRevoke Extends OcuPilot.Screen.Tool.MftConnectionRevoke
{

Parameter PORTCLASS = "OcuPilot.Test.MftSeamPort";

}

/// <p>Test-only <class>OcuPilot.Screen.Tool.AuthOptionsUpdate</class> subclass declaring
/// <class>OcuPilot.Test.AuthOptionsSeamPort</class> as its port, so a mint reaches the seam and its
/// confirm's write is answered without a vendor call. Outside the tool package, so the registry never lists
/// it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamAuthOptionsUpdate Extends OcuPilot.Screen.Tool.AuthOptionsUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.AuthOptionsSeamPort";

}

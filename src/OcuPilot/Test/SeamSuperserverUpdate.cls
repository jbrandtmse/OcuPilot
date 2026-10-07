/// <p>Test-only <class>OcuPilot.Screen.Tool.SuperserverUpdate</class> subclass declaring
/// <class>OcuPilot.Test.SuperserverSeamPort</class> as its port, so a mint reaches the seam and its confirm's
/// write is answered by the seam's guard. Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSuperserverUpdate Extends OcuPilot.Screen.Tool.SuperserverUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.SuperserverSeamPort";

Parameter RULES = "OcuPilot.Test.SuperserverRulesSeam";

}

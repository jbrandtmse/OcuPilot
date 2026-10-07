/// <p>Test-only <class>OcuPilot.Screen.Tool.SuperserverDelete</class> subclass declaring
/// <class>OcuPilot.Test.SuperserverSeamPort</class> as its port (<class>OcuPilot.Test.SeamSuperserverUpdate</class>
/// is its twin). Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSuperserverDelete Extends OcuPilot.Screen.Tool.SuperserverDelete
{

Parameter PORTCLASS = "OcuPilot.Test.SuperserverSeamPort";

}

/// <p>Test-only <class>OcuPilot.Screen.Tool.SuperserverCreate</class> subclass declaring
/// <class>OcuPilot.Test.SuperserverSeamPort</class> as its port (<class>OcuPilot.Test.SeamSuperserverUpdate</class>
/// is its twin). Outside the tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamSuperserverCreate Extends OcuPilot.Screen.Tool.SuperserverCreate
{

Parameter PORTCLASS = "OcuPilot.Test.SuperserverSeamPort";

Parameter RULES = "OcuPilot.Test.SuperserverRulesSeam";

}

/// <p>Test-only <class>OcuPilot.Screen.Tool.EncryptionStartupUpdate</class> subclass declaring
/// <class>OcuPilot.Test.EncryptionSeamPort</class> as its port, so a mint reaches the seam. Outside the tool
/// package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamEncryptionStartupUpdate Extends OcuPilot.Screen.Tool.EncryptionStartupUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.EncryptionSeamPort";

}

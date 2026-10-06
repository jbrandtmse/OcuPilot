/// <p>Test-only <class>OcuPilot.Screen.Tool.DatabaseKeyDeactivate</class> subclass declaring
/// <class>OcuPilot.Test.EncryptionSeamPort</class> as its port, so a mint and a screen action run through
/// <class>OcuPilot.Test.EncryptionActionFixture</class> reach the seam. Outside the tool package, so the
/// registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamDatabaseKeyDeactivate Extends OcuPilot.Screen.Tool.DatabaseKeyDeactivate
{

Parameter PORTCLASS = "OcuPilot.Test.EncryptionSeamPort";

}

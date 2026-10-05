/// <p>Test-only <class>OcuPilot.Screen.Tool.EncryptionKeyFileAddKey</class> subclass declaring
/// <class>OcuPilot.Test.EncryptionSeamPort</class> as its port, so a screen action run through
/// <class>OcuPilot.Test.EncryptionActionFixture</class> reaches the seam. Outside the tool package, so the
/// registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamEncryptionKeyFileAddKey Extends OcuPilot.Screen.Tool.EncryptionKeyFileAddKey
{

Parameter PORTCLASS = "OcuPilot.Test.EncryptionSeamPort";

}

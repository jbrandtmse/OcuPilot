/// <p>Test-only <class>OcuPilot.Screen.Tool.EcpSslConnectionDelete</class> subclass declaring
/// <class>OcuPilot.Test.EcpSeamPort</class> as its port, so a screen action run through
/// <class>OcuPilot.Test.EcpActionFixture</class> records its fresh read and its write. Outside the tool
/// package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamEcpSslConnectionDelete Extends OcuPilot.Screen.Tool.EcpSslConnectionDelete
{

Parameter PORTCLASS = "OcuPilot.Test.EcpSeamPort";

}

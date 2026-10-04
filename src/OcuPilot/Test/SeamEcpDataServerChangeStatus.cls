/// <p>Test-only <class>OcuPilot.Screen.Tool.EcpDataServerChangeStatus</class> subclass declaring
/// <class>OcuPilot.Test.EcpSeamPort</class> as its port, so a screen action run through
/// <class>OcuPilot.Test.EcpActionFixture</class> records its fresh read and its write, and a mint made
/// with this class asks the seam's license. Outside the tool package, so the registry never lists
/// it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamEcpDataServerChangeStatus Extends OcuPilot.Screen.Tool.EcpDataServerChangeStatus
{

Parameter PORTCLASS = "OcuPilot.Test.EcpSeamPort";

}

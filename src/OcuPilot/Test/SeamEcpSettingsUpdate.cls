/// <p>Test-only <class>OcuPilot.Screen.Tool.EcpSettingsUpdate</class> subclass declaring
/// <class>OcuPilot.Test.EcpSeamPort</class> as its port, so a confirm or a Save run through it records
/// its fresh read and its write, and, armed, never sends the settings PUT to the vendor. Outside the
/// tool package, so the registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamEcpSettingsUpdate Extends OcuPilot.Screen.Tool.EcpSettingsUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.EcpSeamPort";

}

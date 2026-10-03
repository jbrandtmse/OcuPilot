/// <p>Test-only <class>OcuPilot.Screen.Tool.LicenseKeyActivate</class> subclass declaring
/// <class>OcuPilot.Test.LicenseSeamPort</class> as its port, so a screen action run through
/// <class>OcuPilot.Test.LicenseActionFixture</class> reaches the seam. Outside the tool package, so the
/// registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SeamLicenseKeyActivate Extends OcuPilot.Screen.Tool.LicenseKeyActivate
{

Parameter PORTCLASS = "OcuPilot.Test.LicenseSeamPort";

}
